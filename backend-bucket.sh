#!/bin/bash

# terraform state file

echo

# 1. Create the S3 Bucket
aws s3 mb s3://shopnaija-bucket-terraform-state --region eu-west-1

# 2. Block all public access to the bucket (security)
aws s3api put-public-access-block \
  --bucket shopnaija-bucket-terraform-state \
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --region eu-west-1

# Enable bucket versioning to allow rolling back state changes
aws s3api put-bucket-versioning \
  --bucket shopnaija-bucket-terraform-state \
  --versioning-configuration Status=Enabled \
  --region eu-west-1