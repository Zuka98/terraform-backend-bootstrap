# Prerequisites

## Required Tools

### Terraform
- **Version**: >= 1.0
- **Installation**: [Official Download & Installation Guide](https://www.terraform.io/downloads)
- **Verification**: Run `terraform version`

> **Quick Install** (most common platforms):

**macOS using Homebrew:**
```bash
brew install terraform
```

**Windows using Chocolatey:**
```bash
choco install terraform
```

### AWS CLI
- **Version**: >= 2.0 (recommended)
- **Installation**: [Official AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **Verification**: Run `aws --version`

> **Quick Install** (most common platforms):

**macOS using Homebrew:**
```bash
brew install awscli
```

**Linux/macOS using pip:**
```bash
pip3 install awscli --upgrade --user
```

## Pre-Deployment Checklist

You need **AWS credentials with permissions to create S3 buckets and DynamoDB tables** configured through AWS CLI or environment variables.

> Need help with AWS CLI setup? See the [AWS CLI Configuration Guide](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)

Before running `terraform apply`, verify:

- [ ] **Terraform installed** and version >= 1.0
- [ ] **AWS CLI installed** and configured
- [ ] **AWS credentials** have administrative access
- [ ] **AWS account** is the intended management account
- [ ] **Bucket name** chosen is globally unique
- [ ] **Region** selected is your preferred operational region
- [ ] **No existing** S3 bucket with the same name
- [ ] **No existing** DynamoDB table with the same name

### Verification Commands

```bash
# Check Terraform version
terraform version

# Check AWS CLI version  
aws --version

# Verify AWS authentication and account
aws sts get-caller-identity
```


