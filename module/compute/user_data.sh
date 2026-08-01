#!/bin/bash
set -euo pipefail

# ------------------------------------------------------------------
# Bootstrap script - runs once on instance launch via Launch Template.
# NOTE: This does NOT deploy application code - that's the app team's job.
# This just prepares the OS, agents, and environment so the deployment
# pipeline (GitHub Actions -> SSM Run Command / CodeDeploy) can push code onto it.
# ------------------------------------------------------------------

dnf update -y

# Install SSM agent (usually pre-installed on AL2023 AMIs, ensuring it's running)
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Install CloudWatch agent for custom metrics (disk space, memory - not available by default)
dnf install -y amazon-cloudwatch-agent

cat <<'CWCONFIG' > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "metrics": {
    "namespace": "${project_name}/EC2",
    "metrics_collected": {
      "disk": {
        "measurement": ["used_percent"],
        "resources": ["/"]
      },
      "mem": {
        "measurement": ["mem_used_percent"]
      }
    }
  }
}
CWCONFIG

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Fetch DB credentials from Secrets Manager at boot (never baked into the AMI)
# The app reads these from environment or a runtime config fetch - example only:
echo "export DB_SECRET_ARN=${db_secret_arn}" >> /etc/environment
echo "export S3_BUCKET=${s3_bucket_name}" >> /etc/environment

# Placeholder health endpoint so the ALB target group has something to check
# against before the real app is deployed onto this instance.
mkdir -p /var/www/health
echo "OK" > /var/www/health/index.html
python3 -m http.server 8080 --directory /var/www/health &
