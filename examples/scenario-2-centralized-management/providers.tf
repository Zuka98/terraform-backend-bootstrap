# Management account provider (for state backend)
provider "aws" {
  alias  = "management"
  region = var.aws_region
}

# Target account provider (for resource deployment)
provider "aws" {
  alias  = "target"
  region = var.aws_region

  assume_role {
    role_arn     = var.deployment_role_arn
    session_name = "terraform-deployment"
    external_id  = var.external_id
  }
}
