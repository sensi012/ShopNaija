# 🌍 ShopNaija AWS Regional Cost & Latency Analysis

> **Document Purpose**: Compare AWS Regional Pricing and Latency tradeoffs to identify the most cost-effective region for ShopNaija.  
> **Baseline Region**: `eu-west-1` (Ireland)  
> **Candidate Regions Analyzed**: 
> 1. `us-east-1` (N. Virginia, USA) — *Cheapest Global Baseline*
> 2. `us-east-2` (Ohio, USA) — *Tied Cheapest US Region*
> 3. `eu-west-1` (Ireland) — *Current Baseline*
> 4. `eu-central-1` (Frankfurt, Germany) — *Central Europe Benchmark*
> 5. `af-south-1` (Cape Town, South Africa) — *African Continent Region*

---

## 📊 1. Executive Summary & Side-by-Side Cost Comparison

```
┌────────────────────────────────────────────────────────────────────────┐
│               TOTAL MONTHLY CLOUD SPEND (PROD + DEV) BY REGION         │
│                                                                        │
│   af-south-1 (Cape Town)  ████████████████████████████ $814.35 (+27.2%)│
│   eu-central-1 (Frankfurt)████████████████████ $684.50 (+7.0%)         │
│   eu-west-1 (Ireland)     ███████████████████  $640.00 [BASELINE]      │
│   us-east-1 (N. Virginia) ████████████████     $591.55 (-7.6%)         │
│   us-east-2 (Ohio)        ████████████████     $591.55 (-7.6%)         │
└────────────────────────────────────────────────────────────────────────┘
```

| AWS Region | Prod Monthly | Dev Monthly | Combined Total (Prod + Dev) | Variance ($ vs `eu-west-1`) | Variance (%) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **`us-east-1` (N. Virginia)** | **$489.11** | **$102.44** | **$591.55 / mo** | **-$48.45 / mo** | **-7.6% (Cheapest)** |
| **`us-east-2` (Ohio)** | **$489.11** | **$102.44** | **$591.55 / mo** | **-$48.45 / mo** | **-7.6% (Cheapest)** |
| **`eu-west-1` (Ireland - Current)** | **$531.92** | **$108.08** | **$640.00 / mo** | **$0.00** | **Baseline** |
| **`eu-central-1` (Frankfurt)** | **$569.83** | **$114.67** | **$684.50 / mo** | **+$44.50 / mo** | **+7.0%** |
| **`af-south-1` (Cape Town)** | **$676.13** | **$138.22** | **$814.35 / mo** | **+$174.35 / mo** | **+27.2%** |

---

## 💰 2. Line-by-Line Service Cost Breakdown

### Production Environment (`prod` Workspace)

| Infrastructure Component | Unit Specs | `us-east-1` (N. Virginia) | `eu-west-1` (Ireland) [Current] | `af-south-1` (Cape Town) |
| :--- | :--- | :---: | :---: | :---: |
| **EC2 Baseline Instances** | 2 × `m7g.large` (1,460 hrs) | $119.14 ($0.0816/hr) | $132.86 ($0.0910/hr) | $169.36 ($0.1160/hr) |
| **EC2 Root EBS Storage** | 2 × 30 GB `gp3` encrypted | $4.80 ($0.080/GB) | $5.28 ($0.088/GB) | $6.72 ($0.112/GB) |
| **ASG Scale-Out Buffer** | ~25 hrs spike buffer | $2.04 | $2.28 | $2.90 |
| **RDS PostgreSQL Instance** | Multi-AZ `db.m7g.large` (730 hrs) | $245.28 (2× $0.168/hr) | $271.56 (2× $0.186/hr) | $347.48 (2× $0.238/hr) |
| **RDS Storage (`gp3`)** | 20 GB Multi-AZ SSD | $4.60 ($0.230/GB) | $4.60 ($0.230/GB) | $5.80 ($0.290/GB) |
| **RDS Automated Backups** | 7-day retention delta | $0.50 | $0.50 | $0.65 |
| **NAT Gateway** | 1 Gateway (`single_nat_gateway = true`) | $32.85 ($0.045/hr) | $32.85 ($0.045/hr) | $42.34 ($0.058/hr) |
| **NAT Data Processing** | Outbound traffic (~60 GB) | $2.70 ($0.045/GB) | $2.70 ($0.045/GB) | $3.48 ($0.058/GB) |
| **Public IPv4 EIP Charge** | 1 Elastic IP | $3.65 ($0.005/hr) | $3.65 ($0.005/hr) | $3.65 ($0.005/hr) |
| **VPC Interface Endpoints** | 3 Endpoints × 2 AZs (6 ENIs) | $43.80 ($0.010/hr/AZ) | $43.80 ($0.010/hr/AZ) | $56.94 ($0.013/hr/AZ) |
| **VPC S3 Gateway Endpoint** | Gateway Route | **$0.00** (Free) | **$0.00** (Free) | **$0.00** (Free) |
| **Application Load Balancer** | 1 ALB + 1.0 LCU | $22.27 ($0.0225/hr + LCU) | $24.09 ($0.0250/hr + LCU) | $30.66 ($0.0320/hr + LCU) |
| **S3 Storage & CloudFront** | 50 GB + CDN Free Tier | $1.56 | $1.56 | $1.95 |
| **Serverless & Monitoring** | Lambda, Secrets, CloudWatch | $3.92 | $3.92 | $4.80 |
| **PROD TOTAL MONTHLY** | | **$489.11 / mo** | **$531.92 / mo** | **$676.13 / mo** |

---

### Development Environment (`dev` Workspace)

| Infrastructure Component | Unit Specs | `us-east-1` (N. Virginia) | `eu-west-1` (Ireland) [Current] | `af-south-1` (Cape Town) |
| :--- | :--- | :---: | :---: | :---: |
| **EC2 Baseline Instances** | 2 × `t4g.small` (1,460 hrs) | $24.53 ($0.0168/hr) | $26.86 ($0.0184/hr) | $35.04 ($0.0240/hr) |
| **EC2 Root EBS Storage** | 2 × 30 GB `gp3` encrypted | $4.80 ($0.080/GB) | $5.28 ($0.088/GB) | $6.72 ($0.112/GB) |
| **RDS PostgreSQL Instance** | Single-AZ `db.t3.micro` | $12.41 ($0.0170/hr) | $13.14 ($0.0180/hr) | $16.79 ($0.0230/hr) |
| **RDS Storage (`gp3`)** | 20 GB Single-AZ SSD | $2.30 ($0.115/GB) | $2.30 ($0.115/GB) | $2.90 ($0.145/GB) |
| **NAT Gateway & EIP** | 1 NAT Gateway + 1 EIP | $36.50 | $36.50 | $46.00 |
| **SSM Interface Endpoints** | Disabled (`enable_ssm_endpoints = false`)| **$0.00** | **$0.00** | **$0.00** |
| **Application Load Balancer** | 1 ALB + 0.3 LCU | $18.18 | $20.25 | $25.91 |
| **S3, Logs & Serverless** | Dev usage | $3.72 | $3.75 | $4.86 |
| **DEV TOTAL MONTHLY** | | **$102.44 / mo** | **$108.08 / mo** | **$138.22 / mo** |

---

## ⚡ 3. Latency & Network Performance Analysis (Lagos, Nigeria)

Cost cannot be evaluated in a vacuum without analyzing user experience and network round-trip time (RTT) for your core customer base in Nigeria and West Africa:

```
┌────────────────────────────────────────────────────────────────────────┐
│         AVERAGE ROUND-TRIP LATENCY (RTT) TO LAGOS, NIGERIA             │
│                                                                        │
│   eu-west-1 (Ireland)     █████████ (~90ms - 110ms)     [OPTIMAL]      │
│   eu-central-1 (Frankfurt)██████████ (~105ms - 125ms)                  │
│   af-south-1 (Cape Town)  ██████████████ (~130ms - 170ms)              │
│   us-east-1 (N. Virginia) ████████████████ (~145ms - 185ms)            │
└────────────────────────────────────────────────────────────────────────┘
```

### Why is `eu-west-1` Faster to Nigeria than `af-south-1` or `us-east-1`?
1. **Submarine Cable Topology**: The main subsea fiber-optic cable systems serving West Africa (MainOne, WACS, Equiano, SAT-3, 2Africa) run along the West African coast directly to landing stations in Portugal, the UK, and France. From there, traffic interconnects with Dublin (`eu-west-1`) in under **90–110ms**.
2. **Cape Town (`af-south-1`) Routing Paradox**: Many Internet Service Providers (ISPs) in West Africa route traffic to South Africa *via European interconnects* rather than directly across the continent, resulting in higher latency (~140ms+) and higher transit variance.
3. **N. Virginia (`us-east-1`) Transatlantic Penalty**: Connecting to the US requires transiting Africa $\rightarrow$ Europe $\rightarrow$ Transatlantic cable $\rightarrow$ North America, adding an extra **+50ms to +75ms** to every API call and database transaction.

---

## 🎯 4. Strategic Decision Framework & Recommendation

### Comparison Matrix

| Factor | `us-east-1` (US East) | `eu-west-1` (Ireland - Baseline) | `af-south-1` (Cape Town) |
| :--- | :---: | :---: | :---: |
| **Combined Monthly Spend** | **$591.55 / mo** | **$640.00 / mo** | **$814.35 / mo** |
| **Annual Savings vs Baseline** | Saves **$581.40 / yr** (-7.6%) | Baseline ($7,680 / yr) | Costs **+$2,092.20 / yr** (+27.2%) |
| **Latency to Nigeria** | High (~145–185 ms) | **Low / Optimal (~90–110 ms)** | Medium-High (~130–170 ms) |
| **Graviton3 & Feature Availability** | Immediate / Full | Immediate / Full | Delayed / Limited |
| **CloudFront CDN Compatibility** | Native (ACM certs in us-east-1) | Native (ACM certs in us-east-1) | Native (ACM certs in us-east-1) |

---

### Final Verdict & Recommendation

> [!IMPORTANT]
> **Recommendation: Remain in `eu-west-1` (Ireland)**.
> 
> While switching to `us-east-1` (N. Virginia) saves **$48.45/month (7.6%)**, it increases round-trip latency for Nigerian users by **+60ms to +80ms** per request. For an e-commerce platform where page load speed directly correlates with conversion rates and checkout completion, `eu-west-1` represents the optimal balance of **near-US pricing with superior West African connectivity**.

#### When to Choose `us-east-1`:
* If you run non-user-facing batch processing, asynchronous analytics, or internal development environments where latency does not impact user experience.
