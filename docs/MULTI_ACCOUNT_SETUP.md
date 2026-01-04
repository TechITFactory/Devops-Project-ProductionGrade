# Multi-Account Environment Configuration

## Overview

In production, dev and prod environments run in **separate AWS accounts** for isolation and security. This document explains how to configure Terraform for multi-account deployments.

---

## AWS Organization Structure

```
AWS Organization (Management Account)
│
├── Development Account (111111111111)
│   └── All dev infrastructure
│
├── Production Account (222222222222)
│   └── All prod infrastructure
│
└── Shared Services Account (Optional)
    └── CI/CD, artifact storage
```

---

## Multi-Account Provider Configuration

### Option 1: SSO Profiles (Recommended for Local Dev)

**~/.aws/config:**
```ini
[profile techitfactory-dev]
sso_start_url = https://d-xxxxxxxxxx.awsapps.com/start
sso_region = ap-south-1
sso_account_id = 111111111111
sso_role_name = AdministratorAccess
region = ap-south-1

[profile techitfactory-prod]
sso_start_url = https://d-xxxxxxxxxx.awsapps.com/start
sso_region = ap-south-1
sso_account_id = 222222222222
sso_role_name = AdministratorAccess
region = ap-south-1
```

**environments/dev/main.tf:**
```hcl
provider "aws" {
  region  = "ap-south-1"
  profile = "techitfactory-dev"
}
```

**environments/prod/main.tf:**
```hcl
provider "aws" {
  region  = "ap-south-1"
  profile = "techitfactory-prod"
}
```

---

### Option 2: Assume Role (For CI/CD)

**environments/dev/main.tf:**
```hcl
provider "aws" {
  region = "ap-south-1"
  
  assume_role {
    role_arn     = "arn:aws:iam::111111111111:role/TerraformDeployRole"
    session_name = "terraform-dev"
  }
}
```

**environments/prod/main.tf:**
```hcl
provider "aws" {
  region = "ap-south-1"
  
  assume_role {
    role_arn     = "arn:aws:iam::222222222222:role/TerraformDeployRole"
    session_name = "terraform-prod"
  }
}
```

---

## Separate State Buckets Per Account

Each AWS account needs its own state bucket:

**Dev Account (111111111111):**
```hcl
backend "s3" {
  bucket         = "techitfactory-dev-tfstate-abc123"
  key            = "environments/dev/terraform.tfstate"
  region         = "ap-south-1"
  dynamodb_table = "techitfactory-dev-tflock"
}
```

**Prod Account (222222222222):**
```hcl
backend "s3" {
  bucket         = "techitfactory-prod-tfstate-xyz789"
  key            = "environments/prod/terraform.tfstate"
  region         = "ap-south-1"
  dynamodb_table = "techitfactory-prod-tflock"
}
```

---

## GitHub Actions OIDC Per Account

Each account needs its own OIDC trust relationship:

**Dev Account IAM Role Trust Policy:**
```json
{
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": [
        "repo:TechITFactory/techitfactory-infra:ref:refs/heads/main",
        "repo:TechITFactory/techitfactory-infra:environment:dev"
      ]
    }
  }
}
```

**Prod Account IAM Role Trust Policy:**
```json
{
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": [
        "repo:TechITFactory/techitfactory-infra:environment:prod"
      ]
    }
  }
}
```

---

## GitHub Actions Workflow for Multi-Account

```yaml
name: Terraform Deploy

on:
  push:
    branches: [main]

jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    environment: dev
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN_DEV }}
          aws-region: ap-south-1
      - run: |
          cd environments/dev
          terraform init
          terraform apply -auto-approve

  deploy-prod:
    runs-on: ubuntu-latest
    environment: prod  # Requires manual approval
    needs: deploy-dev
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN_PROD }}
          aws-region: ap-south-1
      - run: |
          cd environments/prod
          terraform init
          terraform apply -auto-approve
```

---

## Cost Isolation

With separate accounts:
- **Dev costs** → billed to dev account
- **Prod costs** → billed to prod account
- Use AWS Cost Explorer to track by account
- Set budget alerts per account

---

## Security Benefits

| Benefit | Description |
|---------|-------------|
| Blast radius | Dev issues can't affect prod |
| IAM separation | Dev permissions don't grant prod access |
| Network isolation | VPCs are completely separate |
| Audit clarity | CloudTrail shows account-specific activity |

---

## For This Course

We use **single account simulation** where environments are separated by:
- Different state file keys
- Different resource naming (dev/prod prefix)
- Same VPC CIDRs work since they're in different accounts

In production, implement the multi-account setup described above.
