# ShopNaija — Production AWS Infrastructure

Infrastructure-as-code for migrating ShopNaija from a single VPS to a scalable,
secure, monitored AWS environment. This repo provisions infrastructure only —
application code deployment is a separate concern layered on top.

## Architecture Overview

```
Internet
   │
CloudFront (bonus - not yet wired in, see Next Steps)
   │
Application Load Balancer (public subnets, 2 AZs)
   │
EC2 Auto Scaling Group (private app subnets, 2 AZs)
   │
RDS PostgreSQL, Multi-AZ (private db subnets, no internet route)

Supporting services (not sequential, wrap around the above):
S3 (uploads/product images) → Lambda (resize on upload) → SNS (admin notify)
API Gateway (exposes Lambda as REST endpoint)
CloudWatch (alarms) + SNS (alerts) → email
IAM (least-privilege roles per service, no shared credentials)
Secrets Manager (DB credentials, auto-generated, never in code)
```

**Traffic flow:** Internet → ALB (only public-facing resource) → EC2 in private
subnets → RDS in private subnets with zero internet route. Each tier's security
group only accepts traffic from the tier directly in front of it.

## Repository Structure

```
.
├── main.tf                  # root module - wires everything together
├── variables.tf              # root input variables
├── outputs.tf                # root outputs (ALB DNS, API URL, etc.)
├── terraform.tfvars.example  # copy to terraform.tfvars, do not commit real one
├── modules/
│   ├── vpc/                  # networking: subnets, IGW, NAT, route tables
│   ├── security/              # security groups (ALB -> EC2 -> RDS chain)
│   ├── iam/                   # least-privilege roles: EC2, Lambda, CI/CD
│   ├── storage/                # S3 bucket, versioning, lifecycle, policy
│   ├── database/                # RDS, Secrets Manager credentials
│   ├── compute/                 # Launch Template, ASG, ALB, listeners
│   ├── lambda/                   # image processing function
│   ├── api_gateway/               # REST API in front of Lambda
│   └── monitoring/                 # CloudWatch alarms, SNS topic
└── .github/workflows/terraform.yml # CI/CD pipeline
```

## Prerequisites

- Terraform >= 1.6.0
- AWS CLI configured with sufficient permissions (or use the CI/CD OIDC role)
- An S3 bucket + DynamoDB table for remote state, created **before** first `init`:

```bash
aws s3api create-bucket --bucket shopnaija-terraform-state --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1
aws s3api put-bucket-versioning --bucket shopnaija-terraform-state \
  --versioning-configuration Status=Enabled

aws dynamodb create-table --table-name shopnaija-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

## Setup Instructions

1. Clone the repo and copy the example vars:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # edit terraform.tfvars with real values
   ```
2. Update `main.tf` backend block region if different from `eu-west-1`.
3. In `modules/iam/main.tf`, replace `ACCOUNT_ID` and
   `YOUR_GITHUB_ORG/shopnaija-infra` in the OIDC trust policy with real values.
   You'll also need to create the GitHub OIDC provider once per AWS account:

   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   ```
4. In GitHub repo settings, add secret `AWS_DEPLOY_ROLE_ARN` with the ARN of
   the `${project_name}-cicd-deploy-role` (available after first apply — you'll
   need to bootstrap this role manually or via local apply the first time).

## Terraform Commands

```bash
terraform init                 # downloads providers, configures backend
terraform fmt -recursive       # auto-format all files
terraform validate             # syntax/type checking
terraform plan -out=tfplan     # preview changes
terraform apply tfplan         # apply the reviewed plan
terraform destroy              # tear down everything (careful — RDS has deletion_protection = true, disable first)
```

## Deployment Guide

1. First deployment must be run **locally** (not via CI/CD) since the CI/CD
   deploy role doesn't exist yet — classic bootstrap problem.
2. `terraform apply` locally to create the base infrastructure including the
   IAM deployment role.
3. Add the deploy role ARN to GitHub Secrets.
4. From then on, every push to `main` runs `validate → plan → apply`
   automatically. PRs get a plan posted as a comment for review before merge.
5. Application code deployment (onto the already-running EC2 fleet) is out of
   scope here — pair this with SSM Run Command, CodeDeploy, or a container
   pipeline once the app team defines their build artifact.

## Security Checklist

- [X] IAM least privilege — scoped policies per role, not `*` wildcards (except the CI/CD role, flagged as a known gap — see Next Steps)
- [X] No hardcoded secrets — DB password is `random_password`-generated and stored in Secrets Manager
- [X] Security groups form a strict chain: internet → ALB only; EC2 accepts only from ALB; RDS accepts only from EC2
- [X] RDS `publicly_accessible = false`, deployed only in private DB subnets with no internet route
- [X] HTTPS enforced at the ALB listener (HTTP redirects to HTTPS); S3 bucket policy denies non-TLS requests
- [X] EBS and RDS storage encrypted at rest
- [X] IMDSv2 enforced on EC2 (`http_tokens = "required"`) — blocks a common SSRF-to-credential-theft path
- [X] No SSH port 22 open anywhere — access via SSM Session Manager only
- [X] S3 public access blocked at the bucket level

## Cost Optimization Notes

| Decision                                               | Reasoning                                                                                                                    |
| ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- |
| `t3.medium` for EC2/RDS                              | Burstable instance family — cheap baseline, bursts under promo traffic without paying for constant peak capacity            |
| Single NAT Gateway (default)                           | Saves ~$35/mo vs. one per AZ; documented availability tradeoff, flip`single_nat_gateway = false` once traffic justifies it |
| S3 lifecycle: Standard → IA (30d) → Glacier IR (90d) | Product images are rarely re-accessed after the first month; no reason to pay Standard rates indefinitely                    |
| ASG target tracking on CPU (60%)                       | Scale before saturation, scale in during quiet hours — avoids paying for idle peak-sized capacity 24/7                      |
| RDS storage autoscaling (max 100GB)                    | Avoids both manual resize firefights and over-provisioning storage upfront                                                   |
| Lambda memory right-sized (256MB)                      | Thumbnailing is not compute-heavy; over-allocating memory just inflates the per-ms cost                                      |
| API Gateway usage plan + throttling                    | Caps cost exposure from abuse or retry storms                                                                                |
| CloudWatch Logs retention (30 days)                    | Logs aren't kept forever by default — unbounded log retention is a classic silent cost leak                                 |

## Disaster Recovery

- **RDS**: automated backups (7-day retention, configurable), Multi-AZ failover, final snapshot on deletion
- **S3**: versioning enabled — accidental delete/overwrite is recoverable
- **Infrastructure**: entirely defined in Terraform — a full environment can be recreated in a new account/region by re-running `terraform apply` against the same state config (excluding data, which restores from RDS snapshot / S3 versions)

## Known Gaps / Next Steps

Being upfront about what's simplified for this deliverable vs. what a longer
production hardening pass would address:

- **CloudFront** not wired in yet (listed as bonus in the brief) — would sit in front of the ALB for edge caching and DDoS absorption via AWS Shield Standard.
- **ACM certificate** in `compute/main.tf` uses a placeholder domain — swap in `var.domain_name` and complete DNS validation once the real domain is live.
- **CI/CD deploy role** currently uses `PowerUserAccess` — fine to get moving, but should be replaced with a custom policy scoped to exactly the resource types this project touches before this goes fully hands-off.
- **API Gateway authorization** is a basic API key — swap for Cognito or a Lambda authorizer if this becomes a customer-facing API rather than an internal trigger.
- **WAF** not included — worth adding in front of CloudFront/ALB for common web exploit protection (SQLi, XSS patterns) given this is e-commerce.
- **GuardDuty / Security Hub** not included — recommend enabling account-wide regardless of this project for baseline threat detection.

## Challenges Encountered (fill in during actual deployment)

Document real issues you hit here as you provision this for real — AZ
capacity issues, IAM policy debugging, RDS parameter group tuning, etc. This
section is meant to be honest and specific once you've run it, not
theoretical.

## Lessons Learned (fill in during actual deployment)

Same — capture what surprised you, what you'd do differently next time
(e.g., NAT Gateway cost, RDS Multi-AZ failover behavior you tested, etc.)
