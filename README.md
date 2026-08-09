# 🛒 ShopNaija — Production AWS Infrastructure & Full-Stack Application

Infrastructure-as-code for migrating ShopNaija from a single VPS to a scalable,
secure, monitored AWS environment. Production-grade, highly available, auto-scaling, and monitored AWS cloud infrastructure for **ShopNaija**, paired with a full-stack Python/FastAPI e-commerce application and automated continuous deployment.

---

## 🏗️ Architecture Overview

```
                                  USER BROWSER / CLIENT
                                            │
                                1. HTTPS / HTTP Requests
                                            ▼
                                ┌───────────────────────┐
                                │    CloudFront CDN     │ (Global Edge Caching, DDoS Protection)
                                └───────────┬───────────┘
                                            │
               ┌────────────────────────────┴────────────────────────────┐
               │ Dynamic Traffic (Default /*)                            │ Static Media (/uploads/*, /processed/*)
               ▼                                                         ▼
┌──────────────────────────────┐                              ┌─────────────────────┐
│  Application Load Balancer   │ (Public Subnets, 2 AZs)      │ Private S3 Bucket   │
│  (Port 80 -> 443 Redirect)   │                              │ (OAC Secured)       │
└──────────────┬───────────────┘                              └─────────────────────┘
               │
               │ 2. Health Checked Traffic (Port 8080)
               ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│ PRIVATE APPLICATION TIER (Multi-AZ EC2 Auto Scaling Group)                         │
│                                                                                   │
│   FastAPI Web App (Uvicorn)  ──>  SQLAlchemy  ──>  boto3 AWS SDK                 │
│   (Sourced env from /etc/environment)                                             │
└──────────────┬─────────────────────────┬──────────────────────────┬───────────────┘
               │                         │                          │
               │ 3. Fetch Secret         │ 4. Read/Write DB         │ 5. S3 Gateway VPCE
               ▼                         ▼                          ▼
┌──────────────────────────────┐ ┌──────────────────────┐ ┌─────────────────────────┐
│     AWS Secrets Manager      │ │  RDS PostgreSQL DB   │ │   S3 Bucket / Lambda    │
│ (Auto-Generated Credentials) │ │ (Isolated DB Subnet) │ │ (Event-Driven Resizing) │
└──────────────────────────────┘ └──────────────────────┘ └────────────┬────────────┘
                                                                       │
                                                                       │ 6. Thumbnail Event
                                                                       ▼
                                                          ┌─────────────────────────┐
                                                          │   AWS SNS & CloudWatch  │
                                                          │  (Alerts & Monitoring)  │
                                                          └─────────────────────────┘
```

**Traffic flow:** Internet → CloudFront → ALB (Public Subnets) → EC2 Auto Scaling Group (Private App Subnets) → RDS PostgreSQL Multi-AZ (Private DB Subnets with zero internet route).

---

## 📁 Repository Structure

```
.
├── main.tf                            # Root Terraform module wiring all resources
├── provider.tf                        # AWS Provider & required version pins
├── backend.tf                         # S3 Remote State backend configuration
├── variable.tf                        # Root input variables
├── output.tf                          # Root deployment outputs (ALB DNS, API URL, S3 Bucket)
├── terraform.tfvars.example           # Example variable input file
├── backend-bucket.sh                  # Bootstrap script for Terraform S3 state bucket
├── remove-backend-bucket.sh           # Cleanup script for S3 state bucket
├── deploy.py                          # Automated Python deployment script (SSM + S3)
│
├── app/                               # Full-Stack FastAPI Web Application
│   ├── main.py                        # FastAPI entry point & template setup
│   ├── config.py                      # Dynamic AWS Secrets Manager & settings loader
│   ├── database.py                    # SQLAlchemy ORM database session binding
│   ├── models.py                      # Database models (User, Product, Category, Order, Cart)
│   ├── security.py                    # Password hashing (bcrypt) & auth logic
│   ├── seed.py                        # Database seeder (products, categories, admin user)
│   ├── start.sh                       # EC2 startup script (sources /etc/environment, starts Uvicorn)
│   ├── requirements.txt               # Application Python dependencies
│   ├── routers/                       # Application API & HTML route handlers
│   └── templates/                     # Jinja2 HTML storefront & admin templates
│
├── module/                            # Modularized Infrastructure Components
│   ├── vpc/                           # VPC, 6 Subnets across 3 Tiers (Public/App/DB), IGW, NAT, VPCE
│   ├── security/                      # Strict Security Group chain (ALB -> EC2 -> RDS)
│   ├── iam/                           # Least-privilege IAM roles (EC2, Lambda, CI/CD)
│   ├── storage/                       # S3 uploads bucket, encryption, versioning, lifecycle rules
│   ├── database/                      # RDS PostgreSQL Multi-AZ & AWS Secrets Manager credentials
│   ├── compute/                       # Launch Template, EC2 Auto Scaling Group, ALB, Health Checks
│   ├── cdn/                           # CloudFront Distribution with Dual-Origin & OAC Security
│   ├── lambda/                        # Pillow image processing function & S3 event trigger
│   ├── api_gateway/                   # REST API Gateway in front of Lambda
│   └── monitoring/                    # CloudWatch Metric Alarms (CPU, Memory, Disk) & SNS Topic
│
└── .github/workflows/
    └── ci.yml                         # GitHub Actions CI/CD Pipeline (Lint, Validate, Apply, Deploy)
```

---

## 🛠️ Prerequisites

- **Terraform** >= 1.15.0
- **AWS CLI** configured with administrator or deploy permissions
- **Python** 3.12+ (for running `deploy.py` locally or in CI/CD)
- An S3 bucket for Terraform remote state created before running `terraform init`:

```bash
# Run the provided bootstrap script, or create it manually:
aws s3api create-bucket --bucket shopnaija-bucket-terraform-state --region eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1
aws s3api put-bucket-versioning --bucket shopnaija-bucket-terraform-state --versioning-configuration Status=Enabled
```

---

## 🚀 Quick Start & Deployment Guide

### 1. Configure Input Variables
Copy the example variables file and update it with your configuration:

```bash
cp terraform.tfvars.example terraform.tfvars
```

### 2. Initialize & Deploy Infrastructure
```bash
terraform init                 # Initialize providers and configure remote S3 state backend
terraform fmt -recursive       # Format code files
terraform validate             # Validate Terraform syntax
terraform plan -out=tfplan     # Preview planned infrastructure resources
terraform apply tfplan         # Provision infrastructure on AWS
```

### 3. Deploy Application Code onto EC2 Fleet
Deploy the FastAPI application code to running EC2 instances via AWS Systems Manager (SSM):

```bash
python deploy.py
```

This script:
1. Automatically discovers active EC2 instances in `shopnaija-asg`.
2. Packages the `app/` folder into a release tarball and uploads it to S3.
3. Uses SSM Run Command to install dependencies, run `seed.py`, and start Uvicorn securely without opening SSH Port 22.

---

## 🔒 Security Architecture Highlights

- **Zero Open SSH Ports**: EC2 instances reside in private subnets with no public IPs. Management is performed via AWS Systems Manager (SSM) Session Manager and Run Command.
- **Strict Security Group Chaining**: 
  - `ALB SG` accepts 80/443 from `0.0.0.0/0`.
  - `EC2 SG` accepts 8080 **only** from `ALB SG`.
  - `RDS SG` accepts 5432 **only** from `EC2 SG`.
- **Dynamic Secret Management**: Database credentials are randomly generated via `random_password` and stored in **AWS Secrets Manager**. EC2 fetches secrets dynamically at startup via IAM roles.
- **Private S3 Media Storage**: The S3 uploads bucket is 100% private (`block_public_access`). Public media requests must pass through **CloudFront CDN** via **Origin Access Control (OAC)** with SigV4 signing.
- **IMDSv2 Enforced**: EC2 instances require Instance Metadata Service Version 2 (`http_tokens = "required"`), mitigating SSRF risks.
- **Enforced Encryption**: Storage is encrypted at rest (EBS, RDS, S3) and in transit (HTTPS, TLS 1.2/1.3, S3 `aws:SecureTransport` policy).

---

## 📊 Monitoring & Alerts

Amazon CloudWatch monitors system metrics and publishes alarms to an **Amazon SNS** topic (`shopnaija-alerts`), sending instant email notifications for:
- **EC2 Fleet High CPU**: CPU average > 80% for 10 mins.
- **Unhealthy Instances**: Healthy host count drops below 2.
- **Low Disk Space**: Instance disk usage > 85%.
- **RDS Database CPU**: PostgreSQL CPU > 75% for 10 mins.
- **RDS Storage Low**: Free database storage < 2 GB.

---

## 💡 Cost Optimization Features

- **Single NAT Gateway**: Configurable via `single_nat_gateway = true` for cost savings in development/staging.
- **S3 Automated Lifecycle Rules**:
  - `0–30 Days`: S3 Standard.
  - `30 Days`: Transitions to `STANDARD_IA` (~40% cost reduction).
  - `90 Days`: Transitions to `GLACIER_IR` (~68% cost reduction).
- **Target Tracking Auto Scaling**: Scales EC2 instances dynamically based on CPU demand (Min 2, Max 6), scaling in during off-peak hours.
- **Lambda Memory Optimization**: Right-sized at 256MB for thumbnail generation to eliminate over-provisioned execution costs.

---

## 🔄 Teardown

To destroy all provisioned resources cleanly:

```bash
# 1. Destroy AWS resources via Terraform:
terraform destroy -auto-approve

# 2. Clean up remote state bucket (optional):
bash remove-backend-bucket.sh
```


---

## 💡 What Surprised Me & Lessons Learned

### **1. Surprises During Implementation**
- **SSM Environment Variable Isolation**: `user_data` wrote `DB_SECRET_ARN` and `DB_ENDPOINT` to `/etc/environment` at boot, but SSM Run Command executed `deploy.py` in a non-interactive shell that did **not** source `/etc/environment` by default. This caused Uvicorn to fall back to `localhost:5432` (`Connection refused`), throwing `502 Bad Gateway` on the ALB until explicit sourcing was added to `start.sh`.
- **Directory Redirects vs ALB Health Checks**: Using Python's `python3 -m http.server 8080 --directory /var/www/health` caused `GET /health` to return `301 Moved Permanently` (redirecting to `/health/`). Because ALB expected `200 OK`, new instances were flagged `UNHEALTHY` and recycled continuously. Replacing it with a custom Python HTTP 200 handler fixed the replacement loop permanently.
- **Zero-SSH Operability via SSM**: Managing, deploying, and debugging private EC2 instances without open Port 22 SSH keys or public IPs proved simpler, safer, and cleaner using AWS Systems Manager (SSM) and VPC Interface Endpoints.
- **CloudFront OAC Security**: An S3 bucket can remain 100% private (`block_public_access = true`) while CloudFront serves assets globally using Origin Access Control (OAC) with SigV4 signatures.

---

### **2. What I Would Do Differently Next Time**
- **Pre-Bake AMIs (Packer / EC2 Image Builder)**: Instead of running `dnf install` and `pip install` inside `user_data.sh.tpl` on every instance launch (taking 2–3 minutes), pre-bake a custom AMI with Python 3.12 and dependencies pre-installed. Instance boot time drops to under 20 seconds.
- **Explicit Environment Sourcing in System Scripts**: Always add `[ -f /etc/environment ] && set -a && source /etc/environment && set +a` at the top of every startup script (`start.sh`) from day one.
- **Dedicated Application Health Check Endpoint**: Implement a lightweight `@router.get("/health")` endpoint in FastAPI that returns `{"status": "ok"}` without database queries, ensuring instant health checks.
- **GitHub OIDC from Day One**: Use AWS OIDC Web Identity Federation (`role-to-assume`) for CI/CD from project initialization, completely eliminating static IAM access keys (`AWS_ACCESS_KEY_ID`).
- **Cost vs. Fault Tolerance Toggles**: Use `single_nat_gateway = true` during dev/testing to save ~$35/mo per AZ, but switch to `single_nat_gateway = false` in production so a single AZ outage does not interrupt outbound traffic.
