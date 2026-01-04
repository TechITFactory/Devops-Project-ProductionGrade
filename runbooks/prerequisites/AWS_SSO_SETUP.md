# Prerequisites: AWS Organizations + SSO Setup

## Overview
Set up AWS Organizations and IAM Identity Center (SSO) for secure, keyless authentication.

**Why SSO?**
- No static AWS keys on your laptop
- Short-lived credentials (12 hours)
- Centralized user management
- Required for production-grade security

**Time Required:** ~15 minutes

---

## Part 1: Create AWS Organization

### Step 1.1: Navigate to Organizations
```
1. Login to AWS Console as root/admin
2. Go to: https://console.aws.amazon.com/organizations/
3. Click "Create organization"
4. Choose "All features" (not just billing)
5. Click "Create organization"
```

### Step 1.2: Verify Organization Created
```
You should see:
- Organization ID: o-xxxxxxxxxx
- Your account as "Management account"
```

---

## Part 2: Enable IAM Identity Center

### Step 2.1: Navigate to Identity Center
```
1. Go to: https://console.aws.amazon.com/singlesignon/
2. Click "Enable"
3. Choose region: ap-south-1 (keep same as your infra)
4. Identity source: Keep default (Identity Center directory)
5. Click "Enable"
```

### Step 2.2: Get Your Portal URL
```
After enabling, note your portal URL:
https://d-xxxxxxxxxx.awsapps.com/start

Save this - you'll need it for CLI configuration!
```

---

## Part 3: Create Admin User

### Step 3.1: Add User
```
1. IAM Identity Center → Users → Add user
2. Fill in:
   - Username: admin (or your preferred name)
   - Email: your-email@example.com
   - First name: Your first name
   - Last name: Your last name
3. Click "Next"
4. Skip groups for now → Click "Next"
5. Click "Add user"
6. Check your email for password setup link
```

### Step 3.2: Set Password
```
1. Check email for "Invitation to join AWS IAM Identity Center"
2. Click the link
3. Set your password
4. Set up MFA (recommended)
```

---

## Part 4: Create Permission Set

### Step 4.1: Create Administrator Permission Set
```
1. IAM Identity Center → Permission sets
2. Click "Create permission set"
3. Choose "Predefined permission set"
4. Select "AdministratorAccess"
5. Click "Next"
6. Permission set name: AdministratorAccess (keep default)
7. Session duration: 12 hours
8. Click "Next" → "Create"
```

---

## Part 5: Assign User to AWS Account

### Step 5.1: Assign Access
```
1. IAM Identity Center → AWS accounts
2. Select your AWS account (checkbox)
3. Click "Assign users or groups"
4. Select "Users" tab
5. Check your admin user
6. Click "Next"
7. Select "AdministratorAccess" permission set
8. Click "Next" → "Submit"
```

---

## Part 6: Configure AWS CLI

### Step 6.1: Remove Old Credentials (Optional)
```bash
# Backup and remove old static keys
mv ~/.aws/credentials ~/.aws/credentials.backup
```

### Step 6.2: Configure SSO Profile
```bash
aws configure sso
```

**Enter these values when prompted:**
```
SSO session name: techitfactory
SSO start URL: https://d-xxxxxxxxxx.awsapps.com/start  # Your portal URL
SSO region: ap-south-1
SSO registration scopes: (press Enter for default)

# Browser will open - login with your Identity Center credentials

# After login, continue in terminal:
CLI default client Region: ap-south-1
CLI default output format: json
CLI profile name: techitfactory
```

### Step 6.3: Login with SSO
```bash
# Daily login command (run each day or when session expires)
aws sso login --profile techitfactory

# Set as default profile
export AWS_PROFILE=techitfactory

# Add to ~/.bashrc or ~/.zshrc for persistence
echo 'export AWS_PROFILE=techitfactory' >> ~/.bashrc
source ~/.bashrc
```

### Step 6.4: Verify SSO Works
```bash
aws sts get-caller-identity

# Should show something like:
# {
#     "UserId": "AROAXXXXXXXXX:admin",
#     "Account": "535002890483",
#     "Arn": "arn:aws:sts::535002890483:assumed-role/AWSReservedSSO_AdministratorAccess_.../admin"
# }
```

---

## Part 7: Terraform Provider Configuration

### Step 7.1: Update Provider for SSO
No changes needed! Terraform automatically uses the `AWS_PROFILE` environment variable.

```bash
# With AWS_PROFILE set, just run:
cd techitfactory-infra/bootstrap
terraform init
terraform plan
```

---

## Troubleshooting

### "Token has expired"
```bash
# Re-login
aws sso login --profile techitfactory
```

### "Profile not found"
```bash
# Check available profiles
aws configure list-profiles

# Verify profile config
cat ~/.aws/config
```

### "No credentials"
```bash
# Make sure profile is set
export AWS_PROFILE=techitfactory

# Or use --profile flag
aws s3 ls --profile techitfactory
```

---

## Daily Workflow

```bash
# Start of day
aws sso login --profile techitfactory

# Work with Terraform
cd techitfactory-infra/bootstrap
terraform plan
terraform apply

# Session valid for 12 hours
```

---

## Completion Checklist
- [ ] AWS Organization created
- [ ] IAM Identity Center enabled
- [ ] Admin user created
- [ ] Permission set created (AdministratorAccess)
- [ ] User assigned to AWS account
- [ ] CLI configured with `aws configure sso`
- [ ] `aws sso login` works
- [ ] `aws sts get-caller-identity` shows SSO role
- [ ] Old static keys removed/disabled

---

## Next: Continue with S2.1 (Terraform Bootstrap)
With SSO configured, proceed to run the bootstrap:
```bash
cd ~/Desktop/Devops-Project/techitfactory-infra/bootstrap
terraform init
terraform plan
terraform apply
```
