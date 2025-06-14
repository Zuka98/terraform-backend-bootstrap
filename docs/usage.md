# Usage Guide

## Main Scenarios

This backend setup supports two primary usage scenarios, each suited for different organizational needs and deployment patterns:


| Scenario | Description | Best For |
|----------|-------------|----------|
| **1. Single Account Setup** | Terraform runs in the same AWS account as the state backend | Small teams, simple setups, single account environments |
| **2. Centralized Management** | Terraform runs from a management account and assumes roles into target accounts | Large organizations, multi-account environments, centralized DevOps |

---

## Scenario 1: Single Account Setup

### Overview
In this scenario, Terraform runs in the same AWS account where the S3 bucket and DynamoDB table are hosted. All resources are deployed within this single account.

### When to Use
- ✅ Small teams or individual developers **in dedicated workload accounts**
- ✅ Simple infrastructure setups **for learning and experimentation only**
- ✅ Single AWS account environments **that are NOT management accounts**
- ✅ Temporary or proof-of-concept deployments

### Limitations
- ⚠️ Not suitable for multi-account environments
- ⚠️ Limited scalability for large organizations
- ⚠️ No account-level resource isolation
- ⚠️ **Security risk if deployed in management accounts**
- ⚠️ **Violates AWS best practices for account separation**

### Recommendation
This scenario is **NOT recommended** if your account serves as a **management account** in an AWS Organizations setup, as management accounts should be kept minimal and not used for workload deployments. Even for simple setups in dedicated workload accounts, consider implementing **Scenario 2** from the start - it provides better security through role-based isolation, cleaner separation of concerns, follows AWS best practices, and offers an easier migration path as your infrastructure grows.

### Example Implementation
For a complete working example of this scenario, see the [scenario-1-single-account example](../examples/scenario-1-single-account/) which demonstrates deploying an API Gateway in the same account as the Terraform backend.

### Setup Instructions

Once the terraform-backend is set up (see main README), follow these steps:

**Prerequisites**: Configure your AWS CLI with credentials for the **same account** where the terraform backend infrastructure is deployed (the account containing the S3 bucket and DynamoDB table).

```bash
# Verify you're using the correct account
aws sts get-caller-identity
```

1. **Create your terraform.tfvars file with your actual values**:

**terraform.tfvars**:
```hcl
# Example configuration - customize for your environment
aws_region = "us-east-1"

# Project information  
project_name = "my-project-scenario-1"
environment  = "dev"
```

2. **Get the backend configuration values from your deployed terraform-backend infrastructure**:

Run these commands in the directory where you deployed the terraform-backend (see main README):

```bash
terraform output state_bucket_name
terraform output lock_table_name
terraform output aws_region
```

3. **Configure your Terraform project**:

**versions.tf**:
```hcl
terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "your-state-bucket-name"        # From state_bucket_name output
    key            = "my-project/terraform.tfstate"  # Customize your project path
    region         = "us-east-1"                     # From aws_region output
    dynamodb_table = "terraform-locks"               # From lock_table_name output
    encrypt        = true
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**providers.tf**:
```hcl
provider "aws" {
  region = var.aws_region
}
```

**main.tf**:
```hcl
resource "aws_api_gateway_rest_api" "example" {
  name        = "${var.project_name}-example-scenario-1-api"
  description = "Example API Gateway for ${var.environment} environment"

  tags = {
    Name        = "${var.project_name}-example-api"
    Environment = var.environment
    Project     = var.project_name
  }
}
```

4. **Initialize and deploy**:
```bash
terraform init
terraform plan
terraform apply
```
📋 **Cleanup**: When you're ready to remove this project, see the [Complete Cleanup Guide](cleanup.md) for proper cleanup procedures.

---

## Scenario 2: Centralized Management (Recommended)

### Overview
Terraform runs from a **management account** that stores state in the central backend and **assumes roles into target accounts** to deploy resources. This is the recommended approach for organizations and enterprise use cases, but also for individual users. While it requires slightly more overhead, it provides clearer advantages.

### When to Use
- ✅ Any user seeking better security through role-based isolation
- ✅ Projects requiring separation between state management and resource deployment
- ✅ Multi-account environments (personal or organizational)
- ✅ Teams wanting centralized state management with distributed deployments
- ✅ Environments requiring strict access control
- ✅ Users planning to scale from single to multi-account setups

### Advantages
- ✅ Enhanced security through role-based access and account separation
- ✅ Centralized state management with clear governance
- ✅ Consistent deployment patterns across accounts and environments
- ✅ Future-proof architecture that scales with your needs
- ✅ Better compliance posture and audit trails
- ✅ Reduced blast radius through account-level resource isolation

### Example Implementation
For a complete working example of this scenario, see the [scenario-2-centralized-management example](../examples/scenario-2-centralized-management/) which demonstrates deploying an API Gateway from a management account into a target account using role assumption.

### Setup Instructions

Once the terraform-backend is set up in your management account (see [main README](../README.md)), follow these steps:

**Prerequisites**: 
- Configure your AWS CLI with credentials for the **management account** where the terraform backend infrastructure is deployed
- Have access to create IAM roles in the target account(s)

```bash
# Verify you're using the management account
aws sts get-caller-identity
```

1. **Create cross-account role in target account**:

You'll need to create an IAM role in your target account that allows the management account to assume it. For detailed instructions on creating cross-account IAM roles, refer to the [AWS documentation on cross-account access](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html).

Key requirements for the role:
- Trust policy allowing your management account to assume the role
- Appropriate permissions for Terraform operations (e.g., PowerUserAccess or custom policies)
- Optional: External ID for additional security

2. **Get the backend configuration values**:
```bash
terraform output state_bucket_name
terraform output lock_table_name
terraform output aws_region
```

3. **Create your terraform.tfvars file with your actual values**:

**terraform.tfvars**:
```hcl
# Example configuration - customize for your environment
aws_region = "us-east-1"

# Project information  
project_name = "my-project-scenario-2"
environment  = "dev"

# Target account configuration
target_account_id = "123456789012"  # Replace with your target AWS account ID
deployment_role_arn = "arn:aws:iam::123456789012:role/TerraformDeploymentRole"  # Replace with your actual deployment role ARN
external_id       = "your-unique-external-id"  # Replace with your unique external ID
```

4. **Configure your Terraform project in the management account**:

**versions.tf**:
```hcl
terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "your-bucket-name"                           # From state_bucket_name output
    key            = "my-project-scenario-2/terraform.tfstate"   # Customize your project path
    region         = "us-east-1"                                  # From aws_region output
    dynamodb_table = "terraform-locks"                           # From lock_table_name output
    encrypt        = true
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

**providers.tf**:
```hcl
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
```

**main.tf**:
```hcl
# Deploy API Gateway in target account
resource "aws_api_gateway_rest_api" "example" {
  provider    = aws.target
  name        = "${var.project_name}-example-scenario-2-api"
  description = "Example API Gateway for ${var.environment} environment deployed via centralized management"

  tags = {
    Name        = "${var.project_name}-example-api"
    Environment = var.environment
    Project     = var.project_name
  }
}
```

5. **Initialize and deploy**:
```bash
terraform init
terraform plan
terraform apply
```

📋 **Cleanup**: When you're ready to remove this project, see the [Complete Cleanup Guide](cleanup.md) for proper cleanup procedures.

## State Key Organization
Use consistent naming patterns for your state files:

```hcl
# Single project
key = "web-app/terraform.tfstate"

# Multi-environment in single account
key = "web-app/production/terraform.tfstate"
key = "web-app/staging/terraform.tfstate"
key = "web-app/development/terraform.tfstate"

# Service-based organization
key = "services/user-api/terraform.tfstate"
key = "services/payment-api/terraform.tfstate"
key = "infrastructure/networking/terraform.tfstate"
```

## Migrating from Remote to Local State

If you need to migrate a project back to local state:

1. **Remove backend configuration** from your Terraform files
2. **Initialize with migration**:
```bash
terraform init -migrate-state
```
3. **Confirm migration** when prompted
4. **Verify local state**:
```bash
ls -la terraform.tfstate
```

## Cleanup and Project Removal

When you need to completely remove a Terraform project and clean up its state from the backend:

### Quick Cleanup Steps

1. **Destroy project resources**:
```bash
terraform destroy
```

2. **Clean up state files**:
```bash
# Remove project state files from S3
aws s3 rm s3://your-state-bucket-name/my-project/ --recursive
```

3. **For detailed cleanup procedures**, including handling stuck locks, MD5 entries, and automated cleanup scripts, see the **[Complete Cleanup Guide](cleanup.md)**.