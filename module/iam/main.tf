# EC2 Policies

# EC2 ROLE - what the app tier is allowed to do
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.project_name}-${var.environment}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

data "aws_iam_policy_document" "ec2_s3_policy" {
  statement {
    sid     = "AppBucketReadWrite"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }
}

# Access to the bucket
resource "aws_iam_role_policy" "ec2_s3" {
  name   = "${var.project_name}-${var.environment}-ec2-s3-policy"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.ec2_s3_policy.json
}

# Secrets Manager access - only the DB secret
data "aws_iam_policy_document" "ec2_secrets_policy" {
  statement {
    sid       = "ReadDbSecretOnly"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "ec2_secrets" {
  name   = "${var.project_name}-${var.environment}-ec2-secrets-policy"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.ec2_secrets_policy.json
}

# AWS role attachment for CloudWatch (metrics/logs from instances)
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Policy for AWS SSM Session Manager (access into EC2 without opening SSH)
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Lambda execution role
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_name}-${var.environment}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_s3_policy" {
  statement {
    sid       = "LambdaS3Access"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${var.s3_bucket_arn}/*"]
  }
  statement {
    sid       = "LambdaSNSPublish"
    actions   = ["sns:Publish"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_s3" {
  name   = "${var.project_name}-${var.environment}-lambda-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_s3_policy.json
}

# ------------------------------------------------------------------
# CI/CD Deployment Role (GitHub OIDC & EC2 Assume)
# ------------------------------------------------------------------

# Fetch the current AWS Account ID dynamically (avoids hardcoding)
data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"
}

locals {
  is_prod = var.environment == "production" || var.environment == "prod"

  oidc_sub_conditions = local.is_prod ? [
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main",
    "repo:${var.github_org}/${var.github_repo}:environment:production",
    "repo:${var.github_org}/${var.github_repo}:environment:prod"
    ] : [
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/dev",
    "repo:${var.github_org}/${var.github_repo}:environment:dev",
    "repo:${var.github_org}/${var.github_repo}:environment:development",
    "repo:${var.github_org}/${var.github_repo}:pull_request"
  ]
}

data "aws_iam_policy_document" "deployment_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Restrict to only the specific environment's branches and GitHub environments
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.oidc_sub_conditions
    }
  }
}

resource "aws_iam_role" "deployment_role" {
  name               = "${var.project_name}-${var.environment}-deployment-role"
  assume_role_policy = data.aws_iam_policy_document.deployment_assume.json
}


# Grant the deployment role enough permissions to run Terraform and deploy the app
data "aws_iam_policy_document" "deployment_policy" {
  statement {
    sid    = "TerraformStateAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = ["arn:aws:s3:::*shopnaija*", "arn:aws:s3:::*shopnaija*/*"]
  }

  statement {
    sid    = "TerraformDynamoLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = ["arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/*shopnaija*"]
  }

  statement {
    sid    = "SSMRunCommand"
    effect = "Allow"
    actions = [
      "ssm:SendCommand",
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3AppUpload"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [var.s3_bucket_arn, "${var.s3_bucket_arn}/*"]
  }

  statement {
    sid    = "EC2DescribeForDeploy"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "autoscaling:DescribeAutoScalingGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deployment_policy" {
  name   = "${var.project_name}-${var.environment}-deployment-policy"
  role   = aws_iam_role.deployment_role.id
  policy = data.aws_iam_policy_document.deployment_policy.json
}

