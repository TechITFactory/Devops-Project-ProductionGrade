# 🚀 TechITFactory Production-Grade DevOps - Complete Implementation Guide

> **Total Time:** ~4-6 hours for full deployment  
> **Prerequisites:** AWS Account, GitHub Account, Domain (optional)  
> **Cost:** ~$5-10/day (EKS + NAT Gateway)

---

## 📋 Table of Contents

1. [Phase 1: Prerequisites & Setup](#phase-1-prerequisites--setup)
2. [Phase 2: Bootstrap Infrastructure](#phase-2-bootstrap-infrastructure)
3. [Phase 3: Deploy VPC & EKS](#phase-3-deploy-vpc--eks)
4. [Phase 4: Configure EKS Access](#phase-4-configure-eks-access)
5. [Phase 5: Install Kubernetes Add-ons](#phase-5-install-kubernetes-add-ons)
6. [Phase 6: Setup GitOps with ArgoCD](#phase-6-setup-gitops-with-argocd)
7. [Phase 7: Deploy Observability Stack](#phase-7-deploy-observability-stack)
8. [Phase 8: Build & Deploy Applications](#phase-8-build--deploy-applications)
9. [Phase 9: Configure CI/CD Pipelines](#phase-9-configure-cicd-pipelines)
10. [Phase 10: End-to-End Verification](#phase-10-end-to-end-verification)
11. [Phase 11: Cleanup](#phase-11-cleanup)

---

## Phase 1: Prerequisites & Setup

### 1.1 Install Required Tools

```bash
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
aws --version

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
terraform version

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
argocd version --client

# Docker
sudo apt-get install -y docker.io
sudo usermod -aG docker $USER
# Log out and back in for group changes

# eksctl (for SSO/access management)
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
```

### 1.2 Configure AWS CLI

```bash
# Option A: Access Keys (for learning)
aws configure
# Enter: Access Key ID, Secret Key, Region (ap-south-1), Output (json)

# Option B: SSO (recommended for production)
aws configure sso
# Follow prompts to set up SSO

# Verify identity
aws sts get-caller-identity
```

### 1.3 Clone Repositories

```bash
mkdir -p ~/techitfactory && cd ~/techitfactory

git clone https://github.com/YOUR_ORG/techitfactory-infra.git
git clone https://github.com/YOUR_ORG/techitfactory-app.git
git clone https://github.com/YOUR_ORG/techitfactory-gitops.git
```

---

## Phase 2: Bootstrap Infrastructure

### 2.1 Create Terraform Remote State

```bash
cd ~/techitfactory/techitfactory-infra/bootstrap

# Initialize
terraform init

# Review what will be created
terraform plan

# Apply (creates S3 bucket, DynamoDB, KMS)
terraform apply

# Note the outputs
terraform output
```

**Created Resources:**
- S3 Bucket: `techitfactory-terraform-state-<ACCOUNT_ID>`
- DynamoDB Table: `techitfactory-terraform-locks`
- KMS Key: For state encryption
- GitHub OIDC Provider: For keyless CI/CD

### 2.2 Note Important Values

```bash
# Save these for later
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export GITHUB_ROLE_ARN=$(terraform output -raw github_actions_role_arn)

echo "AWS Account: $AWS_ACCOUNT_ID"
echo "GitHub Role: $GITHUB_ROLE_ARN"
```

---

## Phase 3: Deploy VPC & EKS

### 3.1 Configure Backend

```bash
cd ~/techitfactory/techitfactory-infra/environments/dev

# The backend is already configured, just update with your bucket name if needed
cat backend.tf
```

### 3.2 Deploy Infrastructure

```bash
# Initialize with backend
terraform init

# Review the plan (~40 resources)
terraform plan

# Deploy infrastructure (15-20 minutes)
terraform apply

# Watch for errors, common issues:
# - Insufficient IAM permissions
# - Service quotas (NAT Gateway, EIPs)
```

**What Gets Created:**
| Resource | Details |
|----------|---------|
| VPC | 10.0.0.0/16, 2 AZs |
| Public Subnets | 2x for ALB, NAT |
| Private Subnets | 2x for EKS nodes |
| NAT Gateway | 1x (cost optimized) |
| EKS Cluster | v1.28+, managed control plane |
| Node Group | 2x t3.medium (min 2, max 5) |
| ECR Repos | 6 repositories |
| IAM Roles | EKS, node, ALB controller, autoscaler |

---

## Phase 4: Configure EKS Access

### 4.1 Update kubeconfig

```bash
# Get cluster credentials
aws eks update-kubeconfig \
  --name techitfactory-dev \
  --region ap-south-1 \
  --alias techitfactory-dev

# Verify connection
kubectl get nodes
kubectl cluster-info
```

### 4.2 Configure Access Entry (EKS Access API)

> **Note:** EKS v1.23+ uses Access Entries instead of aws-auth ConfigMap

```bash
# Check current access
aws eks list-access-entries --cluster-name techitfactory-dev

# If using SSO, add your SSO role
aws eks create-access-entry \
  --cluster-name techitfactory-dev \
  --principal-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/AWSReservedSSO_AdministratorAccess_xxxxx \
  --type STANDARD

# Associate policy for cluster admin
aws eks associate-access-policy \
  --cluster-name techitfactory-dev \
  --principal-arn arn:aws:iam::${AWS_ACCOUNT_ID}:role/AWSReservedSSO_AdministratorAccess_xxxxx \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

### 4.3 (Alternative) Configure aws-auth ConfigMap

```bash
# If not using Access Entries, edit aws-auth
kubectl edit configmap aws-auth -n kube-system

# Add your IAM user/role under mapUsers or mapRoles:
# mapUsers: |
#   - userarn: arn:aws:iam::ACCOUNT:user/your-user
#     username: your-user
#     groups:
#       - system:masters
```

### 4.4 Verify Access

```bash
# Test kubectl access
kubectl auth can-i '*' '*' --all-namespaces
# Should return: yes

# Get cluster info
kubectl get ns
kubectl get nodes -o wide
```

---

## Phase 5: Install Kubernetes Add-ons

### 5.1 AWS Load Balancer Controller

```bash
# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get VPC ID and ALB role ARN from Terraform
VPC_ID=$(terraform -chdir=~/techitfactory/techitfactory-infra/environments/dev output -raw vpc_id)
ALB_ROLE_ARN=$(terraform -chdir=~/techitfactory/techitfactory-infra/environments/dev output -raw alb_controller_role_arn)

echo "VPC: $VPC_ID"
echo "ALB Role: $ALB_ROLE_ARN"

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=techitfactory-dev \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$ALB_ROLE_ARN \
  --set region=ap-south-1 \
  --set vpcId=$VPC_ID

# Verify
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### 5.2 Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait and verify
kubectl wait --for=condition=Ready pods -l k8s-app=metrics-server -n kube-system --timeout=120s
kubectl top nodes
```

### 5.3 Cluster Autoscaler

```bash
# Get autoscaler role ARN
AUTOSCALER_ROLE_ARN=$(terraform -chdir=~/techitfactory/techitfactory-infra/environments/dev output -raw cluster_autoscaler_role_arn)

helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  -n kube-system \
  --set autoDiscovery.clusterName=techitfactory-dev \
  --set awsRegion=ap-south-1 \
  --set rbac.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$AUTOSCALER_ROLE_ARN

# Verify
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-cluster-autoscaler
```

### 5.4 Create Application Namespaces

```bash
kubectl create namespace techitfactory
kubectl create namespace techitfactory-prod
kubectl create namespace monitoring
kubectl create namespace argocd

# Add labels for monitoring
kubectl label namespace techitfactory monitoring=enabled
```

---

## Phase 6: Setup GitOps with ArgoCD

### 6.1 Install ArgoCD

```bash
# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get initial admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD Admin Password: $ARGOCD_PASSWORD"
```

### 6.2 Access ArgoCD UI

```bash
# Option A: Port forward (for local access)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Open: https://localhost:8080
# Username: admin
# Password: <from above>

# Option B: Expose via LoadBalancer (for remote access)
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
kubectl get svc argocd-server -n argocd
```

### 6.3 Configure ArgoCD CLI

```bash
# Login (with port-forward active)
argocd login localhost:8080 \
  --username admin \
  --password $ARGOCD_PASSWORD \
  --insecure

# Change password (optional but recommended)
argocd account update-password
```

### 6.4 Connect GitOps Repository

```bash
# Option A: HTTPS with token
argocd repo add https://github.com/YOUR_ORG/techitfactory-gitops.git \
  --username YOUR_GITHUB_USERNAME \
  --password YOUR_GITHUB_TOKEN

# Option B: SSH (recommended)
argocd repo add git@github.com:YOUR_ORG/techitfactory-gitops.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# Verify
argocd repo list
```

### 6.5 Deploy Root Application (App-of-Apps)

```bash
# Apply root application
kubectl apply -f ~/techitfactory/techitfactory-gitops/apps/root-app.yaml

# Check in ArgoCD
argocd app list
argocd app get root-app
```

---

## Phase 7: Deploy Observability Stack

### 7.1 Install Prometheus Stack

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install with custom values
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f ~/techitfactory/techitfactory-gitops/monitoring/prometheus-values.yaml \
  --wait --timeout=10m

# Verify
kubectl get pods -n monitoring
```

### 7.2 Install Loki Stack

```bash
helm install loki grafana/loki-stack \
  -n monitoring \
  -f ~/techitfactory/techitfactory-gitops/monitoring/loki-values.yaml

# Verify
kubectl get pods -n monitoring -l app=loki
```

### 7.3 Access Grafana

```bash
# Port forward
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80 &

# Open: http://localhost:3000
# Username: admin
# Password: TechITFactory123!  (from values file)
```

### 7.4 Import Dashboards

In Grafana UI:
1. Go to **Dashboards → Import**
2. Import these community dashboards:
   - `15757` - Kubernetes Cluster Overview
   - `13639` - Loki Logs
   - `7249` - Kubernetes Pods

---

## Phase 8: Build & Deploy Applications

### 8.1 Login to ECR

```bash
# Get ECR login
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com

echo "Logged into ECR"
```

### 8.2 Build and Push All Services

```bash
cd ~/techitfactory/techitfactory-app

# Set registry
REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com/techitfactory"

# Build and push each service
declare -A SERVICES=(
  ["api-gateway"]="services/api-gateway"
  ["product-service"]="services/product"
  ["order-service"]="services/order"
  ["cart-service"]="services/cart"
  ["user-service"]="services/user-service"
  ["frontend"]="services/frontend"
)

for service in "${!SERVICES[@]}"; do
  path="${SERVICES[$service]}"
  echo "🔨 Building $service from $path..."
  docker build -t $REGISTRY/$service:latest $path
  docker push $REGISTRY/$service:latest
  echo "✅ $service pushed"
done
```

### 8.3 Update GitOps with Account ID

```bash
cd ~/techitfactory/techitfactory-gitops

# Replace placeholder with actual account ID
find environments -name "kustomization.yaml" -exec \
  sed -i "s/<AWS_ACCOUNT>/${AWS_ACCOUNT_ID}/g" {} \;

# Commit and push
git add .
git commit -m "chore: Update ECR registry with account ID"
git push
```

### 8.4 Sync Applications in ArgoCD

```bash
# Sync all apps
argocd app sync root-app --prune

# Or sync individually
argocd app sync frontend
argocd app sync api-gateway
argocd app sync product-service
argocd app sync order-service
argocd app sync cart-service
argocd app sync user-service

# Check status
argocd app list
kubectl get pods -n techitfactory
```

---

## Phase 9: Configure CI/CD Pipelines

### 9.1 Workflow Summary

| Repository | Workflow | Purpose |
|------------|----------|---------|
| techitfactory-infra | `terraform-ci.yml` | Infrastructure CI/CD |
| techitfactory-app | `ci.yml` | Unified app CI |
| techitfactory-app | `release.yml` | Production releases |
| techitfactory-gitops | `validate.yml` | Manifest validation |

### 9.2 Configure Secrets (techitfactory-app)

Go to GitHub → techitfactory-app → Settings → Secrets → Actions:

| Secret | Value | How to Get |
|--------|-------|------------|
| `AWS_ROLE_ARN` | `arn:aws:iam::ACCOUNT:role/techitfactory-github-terraform` | From bootstrap output |
| `GITOPS_TOKEN` | `ghp_xxxx...` | Create PAT below |

### 9.3 Create GitHub Personal Access Token

1. Go to GitHub → Settings → Developer settings
2. Personal access tokens → Tokens (classic) → Generate new token
3. Select scopes: `repo` (full control)
4. Generate and copy token
5. Add as `GITOPS_TOKEN` secret in techitfactory-app

### 9.4 Test CI Pipeline

```bash
cd ~/techitfactory/techitfactory-app

# Make a small change
echo "# Test CI" >> services/api-gateway/README.md

# Commit and push
git add .
git commit -m "test: trigger CI"
git push

# Watch GitHub Actions
# Only api-gateway should build (not all services!)
```

---

## Phase 10: End-to-End Verification

### 10.1 Check All Components

```bash
# Nodes
kubectl get nodes

# Pods in techitfactory namespace
kubectl get pods -n techitfactory

# Services
kubectl get svc -n techitfactory

# ArgoCD apps
argocd app list

# Monitoring
kubectl get pods -n monitoring | head -10
```

### 10.2 Test Application Endpoints

```bash
# Port forward API Gateway
kubectl port-forward svc/api-gateway -n techitfactory 3001:80 &

# Test endpoints
curl http://localhost:3001/health
curl http://localhost:3001/api/products
curl http://localhost:3001/api/orders

# Test frontend
kubectl port-forward svc/frontend -n techitfactory 8080:80 &
# Open: http://localhost:8080
```

### 10.3 Verify Monitoring

```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090 &
# Open: http://localhost:9090/targets

# Query metrics
# PromQL: up{namespace="techitfactory"}

# Check logs in Grafana
# Open: http://localhost:3000
# Explore → Loki → {namespace="techitfactory"}
```

### 10.4 Test Auto-Scaling (Optional)

```bash
# Generate load
kubectl run load-test --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://api-gateway.techitfactory/health; done"

# Watch HPA
kubectl get hpa -n techitfactory -w

# Clean up
kubectl delete pod load-test
```

---

## Phase 11: Cleanup

### 11.1 Quick Destroy (Make)

```bash
cd ~/techitfactory
make down
```

### 11.2 Manual Destroy

```bash
# Step 1: Delete Kubernetes resources
kubectl delete namespace techitfactory
kubectl delete namespace techitfactory-prod
kubectl delete namespace monitoring
kubectl delete namespace argocd

# Step 2: Wait for Load Balancers to be deleted
echo "Waiting for LBs to be deleted..."
sleep 60

# Step 3: Destroy Terraform
cd ~/techitfactory/techitfactory-infra/environments/dev
terraform destroy

# Step 4: (Optional) Destroy bootstrap
cd ~/techitfactory/techitfactory-infra/bootstrap
terraform destroy
```

### 11.3 Verify Cleanup

```bash
# Check for remaining resources
aws eks list-clusters --region ap-south-1
aws ec2 describe-nat-gateways --region ap-south-1 --filter "Name=state,Values=available"
aws elbv2 describe-load-balancers --region ap-south-1
```

---

## 📊 Quick Reference

### Commands Cheat Sheet

```bash
# EKS Access
aws eks update-kubeconfig --name techitfactory-dev --region ap-south-1

# ArgoCD
argocd login localhost:8080 --username admin --insecure
argocd app list
argocd app sync <app-name>

# Monitoring
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090

# ECR Login
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com

# Logs
kubectl logs -f deployment/<name> -n techitfactory
stern -n techitfactory .  # Multi-pod logs
```

### Estimated Costs (Daily)

| Resource | Cost/Day |
|----------|----------|
| EKS Control Plane | ~$2.40 |
| 2x t3.medium nodes | ~$1.60 |
| NAT Gateway | ~$1.10 |
| ALB | ~$0.60 |
| EBS/Storage | ~$0.30 |
| **Total** | **~$6/day** |

---

## ✅ Final Checklist

- [ ] AWS CLI configured
- [ ] All tools installed
- [ ] Bootstrap applied (S3, DynamoDB, KMS)
- [ ] VPC + EKS deployed
- [ ] kubectl access configured
- [ ] ALB Controller installed
- [ ] Metrics Server + Autoscaler installed
- [ ] ArgoCD installed and configured
- [ ] GitOps repo connected
- [ ] Prometheus + Loki deployed
- [ ] All 6 services built and pushed
- [ ] Applications synced in ArgoCD
- [ ] CI/CD secrets configured
- [ ] End-to-end test passed

---

## 🎉 Congratulations!

You have deployed a **production-grade Kubernetes platform** with:

- ✅ **Infrastructure as Code** (Terraform)
- ✅ **GitOps** (ArgoCD + Kustomize)
- ✅ **Observability** (Prometheus, Grafana, Loki)
- ✅ **CI/CD** (GitHub Actions with OIDC)
- ✅ **Microservices** (6 services)
- ✅ **Security** (IRSA, non-root containers, OIDC)
- ✅ **Cost Optimization** (Single NAT, right-sized nodes)
