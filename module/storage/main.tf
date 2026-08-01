resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "app_bucket" {
  # S3 bucket names are globally unique - so random suffix avoids collisions across accounts
  bucket = "${var.project_name}-uploads-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-uploads"
  }
}

resource "aws_s3_bucket_versioning" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id

  rule {
    id     = "transition-and-expire"
    status = "Enabled"

    filter {
      prefix = "" # applies to all objects
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA" # infrequent access - cheaper than Standard, still fast retrieval
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR" # Glacier Instant Retrieval - for rarely accessed old uploads, still millisecond access
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.app_bucket.arn, "${aws_s3_bucket.app_bucket.arn}/*"]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"] # tighten to actual frontend domain in production
    max_age_seconds = 3000
  }
}
