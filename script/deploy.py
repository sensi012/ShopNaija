#!/usr/bin/env python3
"""
ShopNaija — Python Deployment Script
Discovers running EC2 instances in the ASG, packages the app,
uploads to S3, and triggers SSM Run Command to deploy and start the app.
"""
import os
import sys
import tarfile
import time
import tempfile
import boto3

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

REGION = os.environ.get("AWS_REGION", "eu-west-1")
PROJECT = os.environ.get("PROJECT_NAME", "shopnaija")
REMOTE_DIR = "/opt/shopnaija"

ec2 = boto3.client("ec2", region_name=REGION)
ssm = boto3.client("ssm", region_name=REGION)
s3 = boto3.client("s3", region_name=REGION)


def get_target_instances():
    """Discover running instances belonging to the project ASG."""
    if len(sys.argv) > 1 and sys.argv[1].startswith("i-"):
        return [sys.argv[1]]

    # Search by ASG groupName tag
    res = ec2.describe_instances(
        Filters=[
            {"Name": "tag:aws:autoscaling:groupName", "Values": [f"{PROJECT}-asg"]},
            {"Name": "instance-state-name", "Values": ["running"]},
        ]
    )
    instances = []
    for r in res.get("Reservations", []):
        for inst in r.get("Instances", []):
            instances.append(inst["InstanceId"])

    # Fallback to tag:Name wildcard
    if not instances:
        res = ec2.describe_instances(
            Filters=[
                {"Name": "tag:Name", "Values": [f"{PROJECT}*"]},
                {"Name": "instance-state-name", "Values": ["running"]},
            ]
        )
        for r in res.get("Reservations", []):
            for inst in r.get("Instances", []):
                instances.append(inst["InstanceId"])

    return instances


def get_s3_bucket():
    """Find the S3 bucket created for uploads/deployments."""
    try:
        buckets = s3.list_buckets().get("Buckets", [])
        for b in buckets:
            if b["Name"].startswith(f"{PROJECT}-uploads-"):
                return b["Name"]
    except Exception as e:
        print(f"⚠️ Could not list S3 buckets: {e}")
    return None


def package_app():
    """Create a gzipped tarball of the app directory."""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    app_dir = os.path.join(base_dir, "app")
    if not os.path.exists(app_dir):
        app_dir = os.path.join(os.path.dirname(base_dir), "app")
    tar_path = os.path.join(tempfile.gettempdir(), f"shopnaija-app-{int(time.time())}.tar.gz")
    print(f"📦 Packaging app from {app_dir}...")
    with tarfile.open(tar_path, "w:gz") as tar:
        tar.add(app_dir, arcname="app")
    size_mb = os.path.getsize(tar_path) / (1024 * 1024)
    print(f"   Created {tar_path} ({size_mb:.2f} MB)")
    return tar_path


def wait_for_ssm(ssm_client, instance_id, timeout=90):
    print(f"   Waiting for SSM agent on {instance_id} to register...")
    for _ in range(timeout // 5):
        try:
            res = ssm_client.describe_instance_information(
                Filters=[{"Key": "InstanceIds", "Values": [instance_id]}]
            )
            if res.get("InstanceInformationList"):
                print(f"   ✅ SSM agent ready on {instance_id}!")
                return True
        except Exception:
            pass
        time.sleep(5)
    return False


def main():
    print("🔍 Discovering EC2 instances...")
    instances = get_target_instances()
    if not instances:
        print(f"❌ No running EC2 instances found for project '{PROJECT}' in {REGION}")
        sys.exit(1)

    print(f"✅ Target instances: {', '.join(instances)}")

    bucket = get_s3_bucket()
    tar_path = package_app()

    if bucket:
        s3_key = "deployments/shopnaija-app-latest.tar.gz"
        print(f"☁️ Uploading artifact to s3://{bucket}/{s3_key}...")
        s3.upload_file(tar_path, bucket, s3_key)
        download_cmd = f"aws s3 cp s3://{bucket}/{s3_key} /tmp/shopnaija-app.tar.gz --region {REGION}"
    else:
        print("⚠️ S3 bucket not found, using raw transfer")
        import base64
        with open(tar_path, "rb") as f:
            b64_data = base64.b64encode(f.read()).decode("utf-8")
        download_cmd = f"echo '{b64_data}' | base64 -d > /tmp/shopnaija-app.tar.gz"

    commands = [
        "set -euo pipefail",
        "echo '=== Deploying ShopNaija ==='",
        "pkill -f 'http.server' || true",
        "pkill -f 'uvicorn' || true",
        "fuser -k 8080/tcp || true",
        "sleep 2",
        download_cmd,
        f"mkdir -p {REMOTE_DIR}",
        f"tar -xzf /tmp/shopnaija-app.tar.gz -C {REMOTE_DIR} --strip-components=1",
        f"chmod +x {REMOTE_DIR}/start.sh",
        f"cd {REMOTE_DIR}",
        "dnf install -y python3.12 python3.12-pip python3-pip git || true",
        "[ -f /etc/environment ] && export $(cat /etc/environment | xargs) || true",
        "python3.12 -m pip install -q -r requirements.txt || python3 -m pip install -q -r requirements.txt",
        "python3.12 seed.py || python3 seed.py || true",
        "nohup bash start.sh > /var/log/shopnaija.log 2>&1 &",
        "sleep 3",
        "ps aux | grep uvicorn | grep -v grep || true",
        "echo '=== Deployment complete ==='",
    ]

    for instance_id in instances:
        print(f"\n🚀 Deploying to {instance_id}...")
        if not wait_for_ssm(ssm, instance_id):
            print(f"❌ {instance_id} SSM agent did not come online in time. Skipping.")
            continue

        res = ssm.send_command(
            InstanceIds=[instance_id],
            DocumentName="AWS-RunShellScript",
            Parameters={"commands": commands},
            Comment=f"ShopNaija deploy {time.strftime('%Y-%m-%d %H:%M:%S')}",
        )
        cmd_id = res["Command"]["CommandId"]
        print(f"   SSM Command ID: {cmd_id}")
        print("   Waiting for execution...")

        # Wait for command completion
        status = "Pending"
        for _ in range(30):
            time.sleep(4)
            try:
                inv = ssm.get_command_invocation(CommandId=cmd_id, InstanceId=instance_id)
                status = inv.get("Status")
                if status in ["Success", "Failed", "Cancelled", "TimedOut"]:
                    break
            except Exception:
                pass

        print(f"   Status: {status}")
        if status == "Success":
            print(f"   ✅ {instance_id} — Deployed successfully!")
        else:
            try:
                inv = ssm.get_command_invocation(CommandId=cmd_id, InstanceId=instance_id)
                print(f"   Output: {inv.get('StandardOutputContent', '')}")
                print(f"   Errors: {inv.get('StandardErrorContent', '')}")
            except Exception:
                pass

    print("\n🎉 All instances updated!")
    print("   Visit your ALB DNS to view the app.")


if __name__ == "__main__":
    main()
