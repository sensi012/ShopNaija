# 💰 ShopNaija AWS Cost Analysis: Production vs. Development

> **AWS Region**: `eu-west-1` (Ireland)  
> **Production Baseline (`terraform.tfvars`)**: Graviton3 `m7g.large` Compute + Multi-AZ `db.m7g.large` RDS  
> **Development Baseline (`terraform.tfvars.example`)**: Graviton2 `t4g.small` Compute + Multi-AZ `db.t3.micro` RDS  
> **Pricing Standard**: AWS On-Demand Public Rates (`eu-west-1`), based on 730 hours/month.

---

## 📊 Executive Summary & Side-by-Side Comparison

```
┌────────────────────────────────────────────────────────────────────────┐
│                   MONTHLY SPEND COMPARISON (PROD vs DEV)               │
│                                                                        │
│   PROD ($531.92/mo)  ████████████████████████████████████████ (100%)   │
│   DEV  ($167.32/mo)  █████████████ (31.5% of Prod)                     │
│                                                                        │
│   Combined Monthly Cloud Budget (Prod + Dev): $699.24 / month          │
│   Combined Annual Cloud Budget (Prod + Dev):  $8,390.88 / year         │
└────────────────────────────────────────────────────────────────────────┘
```

| Service Tier | Production (`terraform.tfvars`) | Development (`terraform.tfvars.example`) | Variance ($) | Variance (%) |
| :--- | :---: | :---: | :---: | :---: |
| **🗄️ Database (RDS PostgreSQL)** | **$276.66** | **$31.18** | -$245.48 | -88.7% |
| **🖥️ Compute (EC2 ASG + EBS)** | **$142.69** | **$32.42** | -$110.27 | -77.3% |
| **🌐 Networking (NAT, VPCE, ALB)** | **$107.09** | **$101.45** | -$5.64 | -5.3% |
| **📈 Observability (CloudWatch & Logs)** | **$3.42** | **$1.56** | -$1.86 | -54.4% |
| **📦 Storage & CDN (S3 & CloudFront)** | **$1.56** | **$0.29** | -$1.27 | -81.4% |
| **⚡ Serverless & Secrets (Lambda, API GW)** | **$0.50** | **$0.42** | -$0.08 | -16.0% |
| **TOTAL ESTIMATED MONTHLY COST** | **$531.92 / mo** | **$167.32 / mo** | **-$364.60** | **-68.5%** |
| **TOTAL ANNUALIZED COST** | **$6,383.04 / yr** | **$2,007.84 / yr** | **-$4,375.20** | **-68.5%** |

---

## 🏭 1. PRODUCTION ENVIRONMENT BREAKDOWN (`terraform.tfvars`)

### Production Configuration:
* **EC2 Fleet**: 2× `m7g.large` (AWS Graviton3, 2 vCPU, 8 GiB RAM) (`terraform.tfvars:6`)
* **ASG Capacity**: `min = 2`, `desired = 2`, `max = 5` (`terraform.tfvars:7-9`)
* **Database**: Multi-AZ `db.m7g.large` PostgreSQL 15.13 (`terraform.tfvars:11-12`)
* **Networking**: 1× NAT Gateway + 1× EIP + 3× PrivateLink Endpoints (6 ENIs) + ALB (`terraform.tfvars:14`, `module/vpc/main.tf`)

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

## 🛠️ 2. DEVELOPMENT ENVIRONMENT BREAKDOWN (`terraform.tfvars.example`)

### Development Configuration:
* **EC2 Fleet**: 2× `t4g.small` (AWS Graviton2, 2 vCPU, 2 GiB RAM) (`terraform.tfvars.example:9`)
* **ASG Capacity**: `min = 2`, `desired = 2`, `max = 4` (`terraform.tfvars.example:10-12`)
* **Database**: Multi-AZ `db.t3.micro` PostgreSQL 15.13 (`terraform.tfvars.example:14-15`)
* **Networking**: 1× NAT Gateway + 1× EIP + 3× PrivateLink Endpoints (6 ENIs) + ALB (`terraform.tfvars.example:17`)

```
┌────────────────────────────────────────────────────────────────────────┐
│                   DEV MONTHLY COST DISTRIBUTION                        │
│                                                                        │
│   Networking & Endpoints (NAT, VPCE, ALB) ██████████████  60.6% ($101.45)│
│   EC2 Compute Fleet (2× t4g.small + EBS)  ████            19.4% ($32.42) │
│   RDS PostgreSQL (Multi-AZ db.t3.micro)   ████            18.6% ($31.18) │
│   CloudWatch Monitoring & Logs            ▌                0.9% ($1.56)  │
│   Secrets Manager & Serverless            ▏                0.3% ($0.42)  │
│   S3 Storage & Backend State              ▏                0.2% ($0.29)  │
└────────────────────────────────────────────────────────────────────────┘
```

> ⚠️ **Key Takeaway for Dev**: In Development, **Networking ($101.45)** constitutes **60.6%** of the entire bill. Because NAT Gateway, VPC Endpoints, and ALB charge fixed hourly fees regardless of instance size, instance downsizing alone cannot reduce this cost without architectural adjustments.

| Line Item | Specifications & Quantity | Unit Rate (`eu-west-1`) | Monthly Cost |
| :--- | :--- | :--- | :---: |
| **EC2 Baseline Instances** | 2 × `t4g.small` (730 hrs each = 1,460 hrs) | $0.0184 / hr | **$26.86** |
| **EC2 EBS Root Storage** | 2 × 30 GB `gp3` encrypted volumes (60 GB total) | $0.0880 / GB-month | **$5.28** |
| **ASG Scale-Out Buffer** | Occasional test scale to 3-4 instances (~15 hrs) | $0.0184 / hr | **$0.28** |
| **RDS Instance (Multi-AZ)** | 1 × `db.t3.micro` Multi-AZ (Primary + Standby in 2nd AZ) | $0.0360 / hr (2 × $0.0180) | **$26.28** |
| **RDS Storage (`gp3`)** | 20 GB Multi-AZ provisioned SSD | $0.2300 / GB-month | **$4.60** |
| **RDS Automated Backups** | 7-day retention (20 GB base included free; minimal test delta) | $0.0950 / GB-month | **$0.30** |
| **AWS NAT Gateway** | 1 NAT Gateway (`single_nat_gateway = true`) | $0.0450 / hr × 730 hrs | **$32.85** |
| **NAT Data Processing** | Outbound traffic (light dev usage, ~20 GB) | $0.0450 / GB | **$0.90** |
| **Public IPv4 EIP Charge** | 1 Elastic IP assigned to NAT Gateway | $0.0050 / hr × 730 hrs | **$3.65** |
| **VPC Interface Endpoints** | 3 Endpoints (`ssm`, `ssmmessages`, `ec2messages`) × 2 AZs (6 ENIs) | $0.0100 / hr / AZ | **$43.80** |
| **VPC Gateway Endpoint (S3)** | Route table gateway endpoint | **Free** ($0.00) | **$0.00** |
| **Application Load Balancer** | 1 ALB in 2 Public Subnets | $0.0250 / hr × 730 hrs | **$18.25** |
| **ALB Capacity Units (LCUs)** | ~0.3 LCU average for dev/testing workloads | $0.0080 / LCU-hr | **$2.00** |
| **S3 Storage & Requests** | ~10 GB dev test uploads + state bucket | $0.0230 / GB-month | **$0.29** |
| **CloudFront CDN** | `PriceClass_100` (within 1 TB Free Tier) | Free Tier | **$0.00** |
| **Serverless & Secrets** | Lambda + API Gateway + 1 Secret in Secrets Manager | Usage-based | **$0.42** |
| **Observability & Logs** | 5 CloudWatch Alarms + ~2 GB dev log ingestion + SNS | $0.50/GB logs + $0.10/alarm | **$1.56** |
| **DEV TOTAL MONTHLY** | | | **$167.32 / mo** |

---

## 🎯 Strategic Cost Optimization Playbook

### 1. Optimize Dev Environment Networking (Save $56.94 / month on Dev)
Because Dev does not need high-redundancy networking:
* **Remove SSM Interface Endpoints in Dev**: Dev EC2 instances can reach SSM through the NAT Gateway.  
  *(Saves **$43.80 / mo**)*
* **Disable Multi-AZ for Dev Database (`db_multi_az = false`)**: Cuts the dev database cost in half.  
  *(Saves **$13.14 / mo**)*
* **Optimized Dev Monthly Spend**: **`~$110.38 / month`** (down from $167.32/mo).

### 2. Optimize Prod with 1-Year Savings Plans (Save $146.52 / month on Prod)
* **Compute Savings Plans (1-Yr, No Upfront)**: 34% discount on `m7g.large` instances → saves **$45.18/mo**.
* **RDS PostgreSQL Reserved Instances (1-Yr, No Upfront)**: 33% discount on Multi-AZ `db.m7g.large` → saves **$89.61/mo**.
* **Remove SSM VPC Interface Endpoints**: Route SSM over the existing NAT Gateway → saves **$43.80/mo**.
* **Optimized Prod Monthly Spend**: **`~$353.33 / month`** (down from $531.92/mo).

---

## 📚 Official AWS Pricing References
* [Amazon EC2 On-Demand Pricing (Ireland)](https://aws.amazon.com/ec2/pricing/on-demand/)
* [Amazon RDS for PostgreSQL Multi-AZ Pricing](https://aws.amazon.com/rds/postgresql/pricing/)
* [AWS PrivateLink / VPC Interface Endpoint Pricing](https://aws.amazon.com/privatelink/pricing/)
* [Amazon VPC NAT Gateway & Public IPv4 Pricing](https://aws.amazon.com/vpc/pricing/)
* [Amazon CloudFront Global Pricing](https://aws.amazon.com/cloudfront/pricing/)
