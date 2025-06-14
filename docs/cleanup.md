# Terraform State Backend Cleanup Guide

This guide provides detailed instructions for properly cleaning up Terraform projects and their associated state files from the centralized backend infrastructure.

## Destroying Projects and Clearing State from the Backend

When you want to completely remove a project and clean up its state from the backend, follow these steps:

### Step 1: Destroy the Project Infrastructure

1. **Destroy all project resources**:
```bash
# Navigate to your project directory
cd /path/to/your-terraform-project
terraform destroy
```

2. **Verify destruction completed successfully**:
```bash
# Check that no resources remain
terraform show
# The state file is empty. No resources are represented.
```

### Step 2: Clean Up State Files from S3 Backend

After destroying your project, the state file still exists in the S3 bucket. Here's how to remove it:

1. **Identify your state file location**:
```bash
# Check your backend configuration in versions.tf or main.tf
# Look for the "key" parameter, e.g., "my-project/terraform.tfstate"
```

2. **Remove the state file from S3**:
```bash
# Remove the entire project folder (recommended)
aws s3 rm s3://your-state-bucket-name/my-project/ --recursive
```

3. **Verify state file removal**:
```bash
# Check that the state file is gone
aws s3 ls s3://your-state-bucket-name/my-project
# Should return no results
```

### Step 3: Clear Any Remaining DynamoDB Locks

Although locks should be automatically released after `terraform destroy` completes, sometimes they can get stuck:

1. **Check for remaining locks**:
```bash
# Scan the DynamoDB table for your project's locks
aws dynamodb scan --table-name terraform-locks \
  --filter-expression "contains(LockID, :project_key)" \
  --expression-attribute-values '{":project_key":{"S":"my-project/terraform.tfstate"}}'
```

2. **Remove stuck locks** (if any exist):
```bash
# Replace LOCK_ID with the actual LockID from the scan results
aws dynamodb delete-item --table-name terraform-locks \
  --key '{"LockID":{"S":"ACTUAL_LOCK_ID_HERE"}}'
```

### 📝 Note: Persistent MD5 Entries

**You may notice persistent entries with `-md5` suffix in your DynamoDB table** (e.g., `bucket-name/project/terraform.tfstate-md5`). These are **NOT Terraform locks** and are normal behavior when S3 bucket encryption is enabled.

**What they are:**
- **Checksum/integrity records** created by S3 encryption processes
- **Not actual Terraform locks** - they don't interfere with Terraform operations
- **Created by AWS services** monitoring encrypted objects (not by Terraform)

**Key differences from real locks:**
- **Real Terraform locks**: Use exact S3 key path (e.g., `bucket/project/terraform.tfstate`)
- **MD5 entries**: Have `-md5` suffix and contain `Digest` values
- **Real locks**: Created and removed during Terraform operations
- **MD5 entries**: Persist permanently as encryption metadata

**Should you remove them?**
- ⚠️ **Generally no** - they're harmless and may be needed for encryption integrity
- ✅ **Only remove** if you're certain they're causing issues
- 🔍 **To remove** (if needed): Use the same `aws dynamodb delete-item` command with the full LockID including `-md5` suffix

**Why this happens:**
This behavior is related to S3 server-side encryption with `bucket_key_enabled = true` in your backend configuration, which may trigger additional integrity verification mechanisms.

## Verifying Complete Backend Cleanup

After cleanup, verify everything is properly removed:

1. **Check S3 bucket contents**:
```bash
aws s3 ls s3://your-state-bucket-name --recursive
```

2. **Check DynamoDB table for active locks**:
```bash
aws dynamodb scan --table-name terraform-locks
```

## Automated Cleanup Script

**Prerequisites:**
- AWS CLI installed and configured with appropriate permissions
- Access to the S3 bucket and DynamoDB table
- Bash shell (works on Linux, macOS, and WSL)

For convenience, you can use the provided cleanup script to automate the entire process:

```bash
# Make the script executable (first time only)
chmod +x scripts/cleanup-project-state.sh

# Run the cleanup script
./scripts/cleanup-project-state.sh <bucket-name> <dynamodb-table> <project-key>
```

**Examples:**
```bash
# Clean up a simple project
./scripts/cleanup-project-state.sh my-terraform-state terraform-locks "my-project/terraform.tfstate"

# Clean up a multi-account project
./scripts/cleanup-project-state.sh company-tf-state terraform-locks "accounts/prod-123456789/web-app/terraform.tfstate"

# Clean up with custom key structure
./scripts/cleanup-project-state.sh tf-backend-bucket tf-locks "environments/staging/services/user-api/terraform.tfstate"
``` 