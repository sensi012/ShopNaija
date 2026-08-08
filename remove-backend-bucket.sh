# Remove state lock
aws s3 rb s3://shopnaija-bucket-terraform-state/production/terraform.tfstate.tflock --region eu-west-1

# Remove Backend bucket object
aws s3 rb s3://shopnaija-bucket-terraform-state/production/terraform.tfstate --region eu-west-1

# Remove Backend bucket
aws s3 rb s3://shopnaija-bucket-terraform-state 

aws s3api delete-objects --bucket shopnaija-bucket-terraform-state \
  --delete "$(aws s3api list-object-versions --bucket shopnaija-bucket-terraform-state --output=json --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"   
# --region eu-west-1


