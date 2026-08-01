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


data "aws_iam_policy_document" "combined_bucket_policy" {
  source_policy_documents = [module.storage.bucket_policy_json]

  statement {
    sid       = "AllowCloudFrontServicePrincipalReadOnly"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${module.storage.bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cdn.distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "app_bucket" {
  bucket = module.storage.bucket_id
  policy = data.aws_iam_policy_document.combined_bucket_policy.json
}
