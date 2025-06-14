# Terraform Backend Bootstrap

This repository sets up a **Terraform backend** using **S3** for state storage and **DynamoDB** for state locking. It enables secure and efficient management of Terraform state files across your organization.

## Features

- **Centralized state storage** using S3
- **State locking and consistency** with DynamoDB
- **Built-in encryption and versioning** for secure and auditable state files
- **Scales seamlessly** from solo projects to large organizations
- **Solves the bootstrapping problem** by provisioning its own backend
- **Production-ready setup** following AWS security best practices


## Overview

This solution is suitable for projects ranging from individual prototypes to enterprise-scale multi-account infrastructures. For detailed guidance on when and how to use this backend setup, see the **[Usage Guide](docs/usage.md)** and **[Concepts & Background](docs/concepts.md)**.

> **Note:**  
> This repository is typically deployed **once** in a central **management AWS account**, following AWS best practices. All Terraform projects in your organization can then use this shared backend by referencing the same **S3 bucket and DynamoDB table**.
>
> If your organization requires **fully isolated backends** (e.g., for compliance or stricter separation of environments), you can deploy this setup **per AWS account**. While supported, this is generally less common.


## Getting Started

> **Prerequisites**: Ensure you have Terraform (≥1.0) and AWS CLI configured. If not, see the [Prerequisites Guide](docs/prerequisites.md) for installation instructions.

### 1. Clone the Repository

```bash
git clone https://github.com/Zuka98/terraform-backend-bootstrap.git
cd terraform-backend-bootstrap
```

### 2. Configure Variables

Copy and customize the variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

> **Note:** Only `bucket_name` is required. Other variables have sensible defaults and can be omitted unless you want to override them.

Edit `terraform.tfvars`:

```hcl
# Required: Must be globally unique
bucket_name = "example-org-terraform-state"

# Optional: Defaults to us-east-1
aws_region = "us-east-1"

# Optional: Defaults to terraform-locks
dynamodb_table_name = "terraform-locks"
```

### 3. Initialize Terraform

⚠️ **Important**: Do not define a `backend "s3"` block in your Terraform configuration yet — this refers to the `terraform { backend "s3" { ... } }` section. Terraform needs to create the backend infrastructure (S3 bucket and DynamoDB table) before it can use it.

```bash
terraform init
```

### 4. Plan and Apply

Review and deploy the infrastructure:

```bash
terraform validate
terraform plan
terraform apply
```

### 5. Migrate to S3 Backend (Optional)

Once the S3 bucket and DynamoDB table are created, you can migrate this Terraform configuration to use its own backend for state storage.

Add the backend configuration to your `versions.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "example-org-terraform-state"  # Use your actual bucket name
    key            = "terraform-state-backend/terraform.tfstate"
    region         = "us-east-1"                    # Use your actual region
    dynamodb_table = "terraform-locks"              # Use your actual table name
    encrypt        = true
  }
}
```

Then migrate the state:

```bash
terraform init -migrate-state
```

**What this does**: This moves your local `terraform.tfstate` file to the S3 bucket, so the backend infrastructure now stores its own state in the remote backend it created. Ideally, this backend configuration should remain unchanged after setup, as it manages the state files and locking for all other Terraform projects in your organization.

## What This Setup Creates

After running `terraform apply`, you'll have a complete, production-ready Terraform backend with the following AWS resources:

### S3 Bucket for State Storage
- **Secure storage** for all your Terraform state files
- **Versioning enabled** – keeps history of state changes for rollback capability
- **AES-256 encryption** – all state files encrypted at rest
- **Public access blocked** – prevents accidental exposure
- **Lifecycle management** – automatically cleans up old state versions after 90 days
- **Prevent destroy** protection – guards against accidental deletion

### DynamoDB Table for State Locking
- **Consistent locking** prevents concurrent Terraform operations
- **Pay-per-request billing** – cost-effective for any usage pattern
- **Point-in-time recovery** enabled for data protection
- **Server-side encryption** for secure lock management
- **Prevent destroy** protection – ensures lock table integrity


## Documentation

For comprehensive deployment guides, usage patterns, and best practices, explore the detailed documentation:

| Guide | Description |
|-------|-------------|
| [Documentation Hub](docs/README.md) | Complete documentation index and navigation guide |
| [Prerequisites](docs/prerequisites.md) | Required software and permissions |
| [Concepts & Background](docs/concepts.md) | Deep dive into state management, costs, and alternatives |
| [Usage Guide](docs/usage.md) | Configure your projects to use the backend |
| [Cleanup Guide](docs/cleanup.md) | Complete project removal and state cleanup procedures |