terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "your-terraform-state-bucket"             # From state_bucket_name output
    key            = "my-project-scenario-2/terraform.tfstate" # Customize your project path
    region         = "us-east-1"                               # From aws_region output
    dynamodb_table = "terraform-locks"                         # From lock_table_name output
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
