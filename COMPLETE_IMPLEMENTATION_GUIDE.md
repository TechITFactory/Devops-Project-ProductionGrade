# 🚀 TechITFactory Production-Grade DevOps - Complete Implementation Guide

> **Total Time:** ~4-6 hours for full deployment  
> **Prerequisites:** AWS Account, GitHub Account, Domain (optional)  
> **Cost:** ~$5-10/day (EKS + NAT Gateway)

---

## 📋 Table of Contents

1. [Phase 1: Prerequisites & Setup](#phase-1-prerequisites--setup)
2. [Phase 2: Bootstrap Infrastructure](#phase-2-bootstrap-infrastructure)
3. [Phase 3: Deploy VPC & EKS](#phase-3-deploy-vpc--eks)
4. [Phase 4: Configure Kubernetes](#phase-4-configure-kubernetes)
5. [Phase 5: Setup GitOps](#phase-5-setup-gitops)
6. [Phase 6: Deploy Observability](#phase-6-deploy-observability)
7. [Phase 7: Build & Deploy Applications](#phase-7-build--deploy-applications)
8. [Phase 8: Configure CI/CD](#phase-8-configure-cicd)
9. [Phase 9: Verification & Testing](#phase-9-verification--testing)
10. [Phase 10: Cleanup](#phase-10-cleanup)

---

## Phase 1: Prerequisites & Setup

### 1.1 Install Required Tools

```bash
# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# Docker
sudo apt-get install docker.io
sudo usermod -aG docker $USER
```

### 1.2 Configure AWS CLI

```bash
aws configure
# Enter: Access Key, Secret Key, Region (ap-south-1), Output (json)

# Verify
aws sts get-caller-identity
```

### 1.3 Clone Repositories

```bash
mkdir ~/techitfactory && cd ~/techitfactory

git clone https://github.com/YOUR_ORG/techitfactory-infra.git
git clone https://github.com/YOUR_ORG/techitfactory-app.git
git clone https://github.com/YOUR_ORG/techitfactory-gitops.git
```

---

## Phase 2: Bootstrap Infrastructure

### 2.1 Create Terraform State Bucket

```bash
cd ~/techitfactory/techitfactory-infra/bootstrap

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply (creates S3 bucket, DynamoDB table, KMS key)
terraform apply
```

**Expected Output:**
- S3 bucket: `techitfactory-terraform-state-ACCOUNT_ID`
- DynamoDB table: `techitfactory-terraform-locks`
- KMS key for encryption

### 2.2 Configure GitHub OIDC (Optional for CI/CD)

```bash
# Still in bootstrap directory
# OIDC is created by bootstrap, but verify:
aws iam list-open-id-connect-providers

# Note the role ARN from outputs
terraform output github_actions_role_arn
```

---

## Phase 3: Deploy VPC & EKS

### 3.1 Update Backend Configuration

```bash
cd ~/techitfactory/techitfactory-infra/environments/dev

# Update backend.tf with your bucket name
cat > backend.tf << 'EOF'
terraform {
  backend "s3" {
    bucket         = "techitfactory-terraform-state-YOUR_ACCOUNT_ID"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "techitfactory-terraform-locks"
    encrypt        = true
  }
}
EOF
```

### 3.2 Deploy Infrastructure

```bash
# Initialize with backend
terraform init

# Review the plan (VPC + EKS + ECR)
terraform plan

# Deploy (~15-20 minutes)
terraform apply
```

**What Gets Created:**
| Resource | Details |
|----------|---------|
| VPC | 10.0.0.0/16 with 2 AZs |
| Subnets | 2 public + 2 private |
| NAT Gateway | Single (cost optimized) |
| EKS Cluster | v1.28, managed node group |
| Node Group | 2x t3.medium |
| ECR Repos | 6 repositories |

### 3.3 Configure kubectl

```bash
# Get cluster credentials
aws eks update-kubeconfig --name techitfactory-dev --region ap-south-1

# Verify connection
kubectl get nodes
kubectl get ns
```

---

## Phase 4: Configure Kubernetes

### 4.1 Install AWS Load Balancer Controller

```bash
# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# Get VPC ID
VPC_ID=$(aws eks describe-cluster --name techitfactory-dev --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=techitfactory-dev \
  --set serviceAccount.create=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(terraform output -raw alb_controller_role_arn) \
  --set region=ap-south-1 \
  --set vpcId=$VPC_ID

# Verify
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### 4.2 Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl top nodes
```

### 4.3 Install Cluster Autoscaler

```bash
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  -n kube-system \
  --set autoDiscovery.clusterName=techitfactory-dev \
  --set awsRegion=ap-south-1
```

### 4.4 Create Application Namespace

```bash
kubectl create namespace techitfactory
kubectl create namespace techitfactory-prod
```

---

## Phase 5: Setup GitOps

### 5.1 Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo  # newline
```

### 5.2 Access ArgoCD UI

```bash
# Port forward (for local access)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Open: https://localhost:8080
# Username: admin
# Password: (from previous command)
```

### 5.3 Connect GitOps Repository

```bash
# Login to ArgoCD CLI
argocd login localhost:8080 --username admin --password <PASSWORD> --insecure

# Add repository
argocd repo add https://github.com/YOUR_ORG/techitfactory-gitops.git \
  --username YOUR_GITHUB_USERNAME \
  --password YOUR_GITHUB_TOKEN
```

### 5.4 Deploy Root Application

```bash
# Apply root app (App-of-Apps pattern)
kubectl apply -f ~/techitfactory/techitfactory-gitops/apps/root-app.yaml

# Check status
argocd app list
```

---

## Phase 6: Deploy Observability

### 6.1 Install Prometheus Stack

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install with custom values
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --create-namespace \
  -f ~/techitfactory/techitfactory-gitops/monitoring/prometheus-values.yaml

# Verify
kubectl get pods -n monitoring
```

### 6.2 Install Loki

```bash
helm repo add grafana https://grafana.github.io/helm-charts

helm install loki grafana/loki-stack \
  -n monitoring \
  -f ~/techitfactory/techitfactory-gitops/monitoring/loki-values.yaml
```

### 6.3 Access Grafana

```bash
# Port forward
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80 &

# Open: http://localhost:3000
# Username: admin
# Password: TechITFactory123!
```

### 6.4 Import Dashboards

In Grafana:
1. Go to Dashboards → Import
2. Import IDs: `15757` (Kubernetes), `13639` (Loki)
3. Select Prometheus/Loki data sources

---

## Phase 7: Build & Deploy Applications

### 7.1 Build Docker Images

```bash
cd ~/techitfactory/techitfactory-app

# Get ECR login
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.ap-south-1.amazonaws.com

# Set variables
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.ap-south-1.amazonaws.com/techitfactory"

# Build and push each service
for service in api-gateway product order cart user-service frontend; do
  echo "Building $service..."
  
  if [ "$service" == "user-service" ]; then
    SERVICE_PATH="services/user-service"
  elif [ "$service" == "order" ]; then
    SERVICE_PATH="services/order"
    SERVICE_NAME="order-service"
  else
    SERVICE_PATH="services/$service"
    SERVICE_NAME="${service}-service"
    [ "$service" == "api-gateway" ] && SERVICE_NAME="api-gateway"
    [ "$service" == "frontend" ] && SERVICE_NAME="frontend"
  fi
  
  docker build -t $REGISTRY/${SERVICE_NAME:-$service}:latest $SERVICE_PATH
  docker push $REGISTRY/${SERVICE_NAME:-$service}:latest
  
  echo "✅ $service pushed"
done
```

### 7.2 Update GitOps with Actual Image Tags

```bash
cd ~/techitfactory/techitfactory-gitops

# Update all kustomization files with your account ID
find environments -name "kustomization.yaml" -exec sed -i "s/<AWS_ACCOUNT>/$ACCOUNT_ID/g" {} \;

# Commit and push
git add .
git commit -m "Update ECR registry with account ID"
git push
```

### 7.3 Sync Applications in ArgoCD

```bash
# Sync all apps
argocd app sync root-app
argocd app sync frontend
argocd app sync api-gateway
argocd app sync product-service
argocd app sync order-service
argocd app sync cart-service
argocd app sync user-service

# Check status
argocd app list
```

### 7.4 Verify Deployments

```bash
# Check pods
kubectl get pods -n techitfactory

# Check services
kubectl get svc -n techitfactory

# Test endpoint (port-forward)
kubectl port-forward svc/api-gateway -n techitfactory 3001:80 &
curl http://localhost:3001/health
```

---

## Phase 8: Configure CI/CD

### 8.1 Add GitHub Secrets

In GitHub → Settings → Secrets → Actions:

| Secret | Value |
|--------|-------|
| `AWS_ROLE_ARN` | `arn:aws:iam::ACCOUNT:role/techitfactory-github-terraform` |
| `GITOPS_TOKEN` | GitHub PAT with repo access |
| `SONAR_TOKEN` | (Optional) SonarCloud token |

### 8.2 Test CI Pipeline

```bash
cd ~/techitfactory/techitfactory-app

# Make a small change
echo "# test" >> services/api-gateway/README.md

# Commit and push
git add . && git commit -m "test: trigger CI" && git push

# Watch GitHub Actions
# Go to: https://github.com/YOUR_ORG/techitfactory-app/actions
```

### 8.3 Create Production Environment

In GitHub → Settings → Environments:
1. Create environment: `production`
2. Add required reviewers
3. Restrict to tags only

---

## Phase 9: Verification & Testing

### 9.1 End-to-End Test

```bash
# Get ALB URL (if ingress configured)
kubectl get ingress -n techitfactory

# Or use port-forward
kubectl port-forward svc/frontend -n techitfactory 8080:80 &

# Open browser: http://localhost:8080
```

### 9.2 Check Monitoring

```bash
# Prometheus targets
open http://localhost:9090/targets

# Grafana dashboards
open http://localhost:3000/dashboards

# Loki logs
# In Grafana → Explore → Select Loki
# Query: {namespace="techitfactory"}
```

### 9.3 Test Autoscaling

```bash
# Generate load
kubectl run load-generator --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://api-gateway.techitfactory.svc.cluster.local/health; done"

# Watch HPA
kubectl get hpa -n techitfactory -w

# Cleanup
kubectl delete pod load-generator
```

---

## Phase 10: Cleanup

### 10.1 Destroy EKS and VPC

```bash
cd ~/techitfactory/techitfactory-infra/environments/dev

# Destroy all resources (~10 minutes)
terraform destroy
```

### 10.2 Destroy Bootstrap (Optional)

```bash
cd ~/techitfactory/techitfactory-infra/bootstrap

# ⚠️ This deletes state bucket!
terraform destroy
```

### 10.3 Manual Cleanup (if needed)

```bash
# Delete any lingering load balancers
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' --output text | xargs -n1 aws elbv2 delete-load-balancer --load-balancer-arn

# Delete ECR images
for repo in frontend api-gateway product-service order-service cart-service user-service; do
  aws ecr delete-repository --repository-name techitfactory/$repo --force
done
```

---

## 📊 Quick Reference

### Useful Commands

```bash
# EKS
aws eks update-kubeconfig --name techitfactory-dev --region ap-south-1
kubectl get nodes

# ArgoCD
argocd app list
argocd app sync <app-name>
argocd app get <app-name>

# Monitoring
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090

# Logs
kubectl logs -f deployment/api-gateway -n techitfactory
stern -n techitfactory .  # (install stern for multi-pod logs)

# ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com
```

### Estimated Costs (Daily)

| Resource | Cost/Day |
|----------|----------|
| EKS Control Plane | ~$2.40 |
| 2x t3.medium nodes | ~$1.60 |
| NAT Gateway | ~$1.10 |
| ALB | ~$0.60 |
| EBS Volumes | ~$0.30 |
| **Total** | **~$6/day** |

---

## ✅ Completion Checklist

- [ ] AWS CLI configured
- [ ] Terraform installed
- [ ] Bootstrap applied (S3, DynamoDB)
- [ ] VPC deployed
- [ ] EKS cluster running
- [ ] kubectl configured
- [ ] ALB Controller installed
- [ ] ArgoCD installed
- [ ] GitOps repo connected
- [ ] Prometheus stack deployed
- [ ] Loki deployed
- [ ] All services built and pushed
- [ ] Applications synced in ArgoCD
- [ ] CI/CD secrets configured
- [ ] End-to-end test passed

---

## 🎉 Congratulations!

You have successfully deployed a production-grade Kubernetes platform with:
- ✅ Infrastructure as Code (Terraform)
- ✅ GitOps (ArgoCD)
- ✅ Observability (Prometheus, Grafana, Loki)
- ✅ CI/CD (GitHub Actions)
- ✅ Microservices Architecture
- ✅ Security Best Practices
