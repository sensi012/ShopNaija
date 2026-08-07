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
  name               = "${var.project_name}-ec2-role"
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
  name   = "${var.project_name}-ec2-s3-policy"
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
  name   = "${var.project_name}-ec2-secrets-policy"
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
  name = "${var.project_name}-ec2-instance-profile"
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
  name               = "${var.project_name}-lambda-role"
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
  name   = "${var.project_name}-lambda-policy"
  role   = aws_iam_role.lambda_role.id
  policy = data.aws_iam_policy_document.lambda_s3_policy.json
}

# Deployment role
data "aws_iam_policy_document" "deployment_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "deployment_role" {
  name               = "${var.project_name}-deployment-role"
  assume_role_policy = data.aws_iam_policy_document.deployment_assume.json
}
