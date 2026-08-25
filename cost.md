# 💰 ShopNaija AWS Cost Analysis: Production vs. Development

> **AWS Region**: `eu-west-1` (Ireland)  
> **Production Baseline (`terraform.tfvars` / Workspace `prod`)**: Graviton3 `m7g.large` Compute + Multi-AZ `db.m7g.large` RDS + SSM VPC Endpoints  
> **Development Baseline (`dev.tfvars` / Workspace `dev`)**: Graviton2 `t4g.small` Compute + Single-AZ `db.t3.micro` RDS + NAT SSM Routing (`enable_ssm_endpoints = false`)  
> **Pricing Standard**: AWS On-Demand Public Rates (`eu-west-1`), based on 730 hours/month.

---

## 📊 Executive Summary & Side-by-Side Comparison

```
┌────────────────────────────────────────────────────────────────────────┐
│                   MONTHLY SPEND COMPARISON (PROD vs DEV)               │
│                                                                        │
│   PROD ($531.92/mo)  ████████████████████████████████████████ (100%)   │
│   DEV  ($108.08/mo)  ████████ (20.3% of Prod)                          │
│                                                                        │
│   Combined Monthly Cloud Budget (Prod + Dev): $640.00 / month          │
│   Combined Annual Cloud Budget (Prod + Dev):  $7,680.00 / year         │
└────────────────────────────────────────────────────────────────────────┘
```

| Service Tier | Production (`terraform.tfvars`) | Development (`dev.tfvars`) | Variance ($) | Variance (%) |
| :--- | :---: | :---: | :---: | :---: |
| **🗄️ Database (RDS PostgreSQL)** | **$276.66** | **$15.74** | -$260.92 | -94.3% |
| **🖥️ Compute (EC2 ASG + EBS)** | **$142.69** | **$32.42** | -$110.27 | -77.3% |
| **🌐 Networking (NAT, VPCE, ALB)** | **$107.09** | **$57.65** | -$49.44 | -46.2% |
| **📈 Observability (CloudWatch & Logs)** | **$3.42** | **$1.56** | -$1.86 | -54.4% |
| **📦 Storage & CDN (S3 & CloudFront)** | **$1.56** | **$0.29** | -$1.27 | -81.4% |
| **⚡ Serverless & Secrets (Lambda, API GW)** | **$0.50** | **$0.42** | -$0.08 | -16.0% |
| **TOTAL ESTIMATED MONTHLY COST** | **$531.92 / mo** | **$108.08 / mo** | **-$423.84** | **-79.7%** |
| **TOTAL ANNUALIZED COST** | **$6,383.04 / yr** | **$1,296.96 / yr** | **-$5,086.08** | **-79.7%** |

---

## 🏭 1. PRODUCTION ENVIRONMENT BREAKDOWN (`terraform.tfvars`)

### Production Configuration:
* **Workspace**: `prod`
* **EC2 Fleet**: 2× `m7g.large` (AWS Graviton3, 2 vCPU, 8 GiB RAM) (`terraform.tfvars:6`)
* **ASG Capacity**: `min = 2`, `desired = 2`, `max = 5` (`terraform.tfvars:7-9`)
* **Database**: Multi-AZ `db.m7g.large` PostgreSQL 15.13 (`terraform.tfvars:11-12`)
* **Networking**: 1× NAT Gateway + 1× EIP + 3× PrivateLink Endpoints (6 ENIs) + ALB (`terraform.tfvars:14-15`, `module/vpc/main.tf`)

```
┌────────────────────────────────────────────────────────────────────────┐
│                   PROD MONTHLY COST DISTRIBUTION                       │
│                                                                        │
│   RDS PostgreSQL (Multi-AZ db.m7g.large)  ██████████████  52.0% ($276.66)│
│   EC2 Compute Fleet (2× m7g.large + EBS)  ███████        26.8% ($142.69)│
│   Networking & Endpoints (NAT, VPCE, ALB) █████          20.1% ($107.09)│
│   CloudWatch Monitoring & Logs            ▌               0.6% ($3.42)  │
│   S3 Storage & Backend State              ▌               0.3% ($1.56)  │
│   Secrets Manager & Serverless            ▏               0.1% ($0.50)  │
└────────────────────────────────────────────────────────────────────────┘
```

| Line Item | Specifications & Quantity | Unit Rate (`eu-west-1`) | Monthly Cost |
| :--- | :--- | :--- | :---: |
| **EC2 Baseline Instances** | 2 × `m7g.large` (730 hrs each = 1,460 hrs) | $0.0910 / hr | **$132.86** |
| **EC2 EBS Root Storage** | 2 × 30 GB `gp3` encrypted volumes (60 GB total) | $0.0880 / GB-month | **$5.28** |
| **ASG Scale-Out Buffer** | Occasional scale to 4-5 instances during peak traffic (~25 hrs) | $0.0910 / hr | **$4.55** |
| **RDS Instance (Multi-AZ)** | 1 × `db.m7g.large` Multi-AZ (Primary + Standby in 2nd AZ) | $0.3720 / hr (2 × $0.1860) | **$271.56** |
| **RDS Storage (`gp3`)** | 20 GB Multi-AZ provisioned SSD | $0.2300 / GB-month | **$4.60** |
| **RDS Automated Backups** | 7-day retention (20 GB base included free; delta storage) | $0.0950 / GB-month | **$0.50** |
| **AWS NAT Gateway** | 1 NAT Gateway (`single_nat_gateway = true`) | $0.0450 / hr × 730 hrs | **$32.85** |
| **NAT Data Processing** | Outbound traffic (OS packages, pip, external APIs) ~60 GB | $0.0450 / GB | **$2.70** |
| **Public IPv4 EIP Charge** | 1 Elastic IP assigned to NAT Gateway | $0.0050 / hr × 730 hrs | **$3.65** |
| **VPC Interface Endpoints** | 3 Endpoints (`ssm`, `ssmmessages`, `ec2messages`) × 2 AZs (6 ENIs) | $0.0100 / hr / AZ | **$43.80** |
| **VPC Gateway Endpoint (S3)** | Route table gateway endpoint | **Free** ($0.00) | **$0.00** |
| **Application Load Balancer** | 1 ALB in 2 Public Subnets | $0.0250 / hr × 730 hrs | **$18.25** |
| **ALB Capacity Units (LCUs)** | ~1.0 LCU average for live e-commerce production traffic | $0.0080 / LCU-hr | **$5.84** |
| **S3 Storage & Requests** | ~50 GB Standard Storage + State Bucket + Requests | $0.0230 / GB-month | **$1.56** |
| **CloudFront CDN** | `PriceClass_100` (First 1 TB egress + 10M HTTPS requests free) | Free Tier | **$0.00** |
| **Serverless & Secrets** | Lambda 256MB + API Gateway + 1 Secret in Secrets Manager | Usage-based | **$0.50** |
| **Observability & Logs** | 5 CloudWatch Alarms + 5.5 GB Ingested Logs + SNS Alerts | $0.50/GB logs + $0.10/alarm | **$3.42** |
| **PROD TOTAL MONTHLY** | | | **$531.92 / mo** |

---

## 🛠️ 2. DEVELOPMENT ENVIRONMENT BREAKDOWN (`dev.tfvars`)

### Development Configuration:
* **Workspace**: `dev`
* **EC2 Fleet**: 2× `t4g.small` (AWS Graviton2, 2 vCPU, 2 GiB RAM) (`dev.tfvars:6`)
* **ASG Capacity**: `desired = 2`, `max = 4` (`dev.tfvars:7-8`)
* **Database**: Single-AZ `db.t3.micro` PostgreSQL 15.13 (`dev.tfvars:10-11`)
* **Networking**: 1× NAT Gateway + 1× EIP + ALB (SSM endpoints disabled via `enable_ssm_endpoints = false`) (`dev.tfvars:13-14`)

```
┌────────────────────────────────────────────────────────────────────────┐
│                   DEV MONTHLY COST DISTRIBUTION                        │
│                                                                        │
│   Networking (NAT Gateway + EIP + ALB)    ████████████    53.3% ($57.65) │
│   EC2 Compute Fleet (2× t4g.small + EBS)  ███████         30.0% ($32.42) │
│   RDS PostgreSQL (Single-AZ db.t3.micro)  ███             14.6% ($15.74) │
│   CloudWatch Monitoring & Logs            ▌                1.4% ($1.56)  │
│   Secrets Manager & Serverless            ▏                0.4% ($0.42)  │
│   S3 Storage & Backend State              ▏                0.3% ($0.29)  │
└────────────────────────────────────────────────────────────────────────┘
```

| Line Item | Specifications & Quantity | Unit Rate (`eu-west-1`) | Monthly Cost |
| :--- | :--- | :--- | :---: |
| **EC2 Baseline Instances** | 2 × `t4g.small` (730 hrs each = 1,460 hrs) | $0.0184 / hr | **$26.86** |
| **EC2 EBS Root Storage** | 2 × 30 GB `gp3` encrypted volumes (60 GB total) | $0.0880 / GB-month | **$5.28** |
| **ASG Scale-Out Buffer** | Occasional test scale to 3-4 instances (~15 hrs) | $0.0184 / hr | **$0.28** |
| **RDS Instance (Single-AZ)** | 1 × `db.t3.micro` Single-AZ (`db_multi_az = false`) | $0.0180 / hr × 730 hrs | **$13.14** |
| **RDS Storage (`gp3`)** | 20 GB Single-AZ provisioned SSD | $0.1150 / GB-month | **$2.30** |
| **RDS Automated Backups** | 7-day retention (20 GB base included free; minimal test delta) | $0.0950 / GB-month | **$0.30** |
| **AWS NAT Gateway** | 1 NAT Gateway (`single_nat_gateway = true`) | $0.0450 / hr × 730 hrs | **$32.85** |
| **NAT Data Processing** | Outbound traffic (light dev usage, ~20 GB) | $0.0450 / GB | **$0.90** |
| **Public IPv4 EIP Charge** | 1 Elastic IP assigned to NAT Gateway | $0.0050 / hr × 730 hrs | **$3.65** |
| **VPC Interface Endpoints** | Disabled in Dev (`enable_ssm_endpoints = false`) | Routed via NAT | **$0.00** |
| **VPC Gateway Endpoint (S3)** | Route table gateway endpoint | **Free** ($0.00) | **$0.00** |
| **Application Load Balancer** | 1 ALB in 2 Public Subnets | $0.0250 / hr × 730 hrs | **$18.25** |
| **ALB Capacity Units (LCUs)** | ~0.3 LCU average for dev/testing workloads | $0.0080 / LCU-hr | **$2.00** |
| **S3 Storage & Requests** | ~10 GB dev test uploads + state bucket | $0.0230 / GB-month | **$0.29** |
| **CloudFront CDN** | `PriceClass_100` (within 1 TB Free Tier) | Free Tier | **$0.00** |
| **Serverless & Secrets** | Lambda + API Gateway + 1 Secret in Secrets Manager | Usage-based | **$0.42** |
| **Observability & Logs** | 5 CloudWatch Alarms + ~2 GB dev log ingestion + SNS | $0.50/GB logs + $0.10/alarm | **$1.56** |
| **DEV TOTAL MONTHLY** | | | **$108.08 / mo** |

---

## 🎯 Strategic Cost Optimization Playbook

### 1. Dev Environment Status: Fully Optimized ($108.08 / month)
Both primary Dev cost optimizations are now implemented:
* ✅ **Single-AZ RDS Database (`db_multi_az = false`)**: Saved **$15.44/mo** (Instance + Storage).
* ✅ **SSM Routing via NAT (`enable_ssm_endpoints = false`)**: Saved **$43.80/mo** on VPC PrivateLink ENIs.
* Total Dev savings: **~$59.24 / month** (35% reduction from unoptimized baseline).

### 2. Optimize Prod with 1-Year Savings Plans (Save $146.52 / month on Prod)
* **Compute Savings Plans (1-Yr, No Upfront)**: 34% discount on `m7g.large` instances → saves **$45.18/mo**.
* **RDS PostgreSQL Reserved Instances (1-Yr, No Upfront)**: 33% discount on Multi-AZ `db.m7g.large` → saves **$89.61/mo**.
* **Remove SSM VPC Interface Endpoints (Optional)**: Route SSM over the existing NAT Gateway → saves **$43.80/mo**.
* **Optimized Prod Monthly Spend**: **`~$353.33 / month`** (down from $531.92/mo).


---

## 🚀 Workspace Deployment Reference

| Environment | Terraform Workspace | Var File | Plan / Apply Command |
| :--- | :--- | :--- | :--- |
| **Development** | `dev` | [dev.tfvars](file:///c:/Users/hp/M4ACE/ShopNaija/dev.tfvars) | `terraform apply -var-file="dev.tfvars"` |
| **Production** | `prod` | [terraform.tfvars](file:///c:/Users/hp/M4ACE/ShopNaija/terraform.tfvars) | `terraform apply -var-file="terraform.tfvars"` |

---

## 📚 Official AWS Pricing References
* [Amazon EC2 On-Demand Pricing (Ireland)](https://aws.amazon.com/ec2/pricing/on-demand/)
* [Amazon RDS for PostgreSQL Pricing](https://aws.amazon.com/rds/postgresql/pricing/)
* [AWS PrivateLink / VPC Interface Endpoint Pricing](https://aws.amazon.com/privatelink/pricing/)
* [Amazon VPC NAT Gateway & Public IPv4 Pricing](https://aws.amazon.com/vpc/pricing/)
* [Amazon CloudFront Global Pricing](https://aws.amazon.com/cloudfront/pricing/)

