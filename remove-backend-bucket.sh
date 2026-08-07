# Remove state lock
aws s3 rm s3://shopnaija-bucket-terraform-state/production/terraform.tfstate.tflock --region eu-west-1

# Remove Backend bucket object
aws s3 rm s3://shopnaija-bucket-terraform-state/production/terraform.tfstate --region eu-west-1

# Remove Backend bucket
aws s3 rm s3://shopnaija-bucket-terraform-state 

# --region eu-west-1


