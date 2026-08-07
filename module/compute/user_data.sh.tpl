#!/bin/bash
set -euo pipefail

# ------------------------------------------------------------------
# Bootstrap script - runs once on instance launch via Launch Template.
# NOTE: This does NOT deploy application code - that's the app team's job.
# This just prepares the OS, agents, and environment so the deployment
# pipeline (GitHub Actions -> SSM Run Command / CodeDeploy) can push code onto it.
# ------------------------------------------------------------------

# Install and start SSM agent immediately so instance connects to AWS Systems Manager right away
dnf install -y amazon-ssm-agent
systemctl enable --now amazon-ssm-agent || true

dnf update -y || true

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
echo "export DB_SECRET_ARN=${db_secret_arn}" >> /etc/environment
echo "export DB_ENDPOINT=${db_endpoint}" >> /etc/environment
echo "export S3_BUCKET=${s3_bucket_name}" >> /etc/environment
echo "export AWS_DEFAULT_REGION=eu-west-1" >> /etc/environment

# ── Install Python 3.12 + pip ─────────────────────────────────
dnf install -y python3.12 python3.12-pip git 2>/dev/null || \
  dnf install -y python3 python3-pip git

python3.12 -m pip install --upgrade pip -q || true

# ── Deploy ShopNaija app ──────────────────────────────────────
APP_DIR="/opt/shopnaija"
mkdir -p "$APP_DIR"

# App code will be deployed here via deploy.sh / SSM / CodeDeploy
# On first boot: run a placeholder health endpoint until code is deployed
if [ ! -f "$APP_DIR/main.py" ]; then
  cat <<'PYSERVER' > /tmp/placeholder_server.py
from http.server import HTTPServer, BaseHTTPRequestHandler
class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'OK')
    def log_message(self, format, *args):
        pass
HTTPServer(('0.0.0.0', 8080), HealthHandler).serve_forever()
PYSERVER
  nohup python3 /tmp/placeholder_server.py > /var/log/shopnaija-placeholder.log 2>&1 &
  echo "Placeholder health server started (PID: $!)"
else
  # Source env and start the real app
  source /etc/environment
  cd "$APP_DIR"
  nohup bash start.sh > /var/log/shopnaija.log 2>&1 &
  echo "ShopNaija app started (PID: $!)"
fi
