# Infrastructure Execution Guide

## Overview
Complete step-by-step guide to deploy the entire infrastructure in the correct order.

---

## Prerequisites Checklist
- [ ] AWS Account access
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Terraform >= 1.6.0 installed
- [ ] kubectl installed
- [ ] Helm installed
- [ ] Git repositories cloned

---

## Execution Order

```
┌─────────────────────────────────────────────────────────────┐
│  PHASE 1: Bootstrap (One-time setup)                        │
│  ├── 1.1 Terraform State Backend                            │
│  └── 1.2 GitHub OIDC Provider                               │
├─────────────────────────────────────────────────────────────┤
│  PHASE 2: Core Infrastructure                                │
│  ├── 2.1 VPC & Networking                                   │
│  ├── 2.2 EKS Cluster                                        │
│  └── 2.3 ECR Repositories                                   │
├─────────────────────────────────────────────────────────────┤
│  PHASE 3: Kubernetes Add-ons                                │
│  ├── 3.1 AWS Load Balancer Controller                       │
│  ├── 3.2 Cluster Autoscaler                                 │
│  └── 3.3 ArgoCD                                             │
├─────────────────────────────────────────────────────────────┤
│  PHASE 4: Applications                                       │
│  ├── 4.1 Build Docker Images                                │
│  └── 4.2 Deploy via GitOps                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## PHASE 1: Bootstrap

### 1.1 Create Terraform State Backend

```bash
cd ~/Desktop/Devops-Project/techitfactory-infra/bootstrap

# Initialize
terraform init

# Review plan
terraform plan

# Apply (creates S3, DynamoDB, KMS)
terraform apply
# Type 'yes'

# Save outputs - you'll need these!
terraform output
```

**Expected outputs:**
- `state_bucket_name` → S3 bucket for state
- `lock_table_name` → DynamoDB for locking
- `github_actions_role_arn` → Role ARN for CI/CD

---

### 1.2 Configure GitHub Repository Secret

```bash
# Get the role ARN
terraform output github_actions_role_arn

# Go to GitHub:
# https://github.com/TechITFactory/techitfactory-infra/settings/secrets/actions
# Add secret: AWS_ROLE_ARN = <paste the ARN>
```

---

### 1.3 Configure Backend in Dev Environment

```bash
cd ~/Desktop/Devops-Project/techitfactory-infra/environments/dev

# Edit main.tf - uncomment the backend block and fill values:
# backend "s3" {
#   bucket         = "<BUCKET_NAME_FROM_STEP_1.1>"
#   key            = "environments/dev/terraform.tfstate"
#   region         = "ap-south-1"
#   encrypt        = true
#   dynamodb_table = "<TABLE_NAME_FROM_STEP_1.1>"
# }
```

---

## PHASE 2: Core Infrastructure

### 2.1 Deploy VPC + EKS + ECR

```bash
cd ~/Desktop/Devops-Project/techitfactory-infra/environments/dev

# Initialize with new backend
terraform init

# Review what will be created
terraform plan

# Apply (takes ~15-20 minutes for EKS)
terraform apply
# Type 'yes'
```

**What gets created:**
- VPC with 2 public + 2 private subnets
- NAT Gateway
- EKS Cluster
- EKS Node Group (2 nodes)
- ECR Repositories (5)
- All IAM roles

---

### 2.2 Configure kubectl

```bash
# Get the command from output
terraform output kubeconfig_command

# Run it
aws eks update-kubeconfig --name techitfactory-dev --region ap-south-1

# Verify
kubectl get nodes
kubectl get pods -n kube-system
```

---

## PHASE 3: Kubernetes Add-ons

### 3.1 Install AWS Load Balancer Controller

```bash
# Add Helm repo
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

# Get role ARN
ALB_ROLE_ARN=$(terraform output -raw alb_controller_role_arn)
VPC_ID=$(terraform output -raw vpc_id)

# Create service account
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${ALB_ROLE_ARN}
EOF

# Install controller
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=techitfactory-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-south-1 \
  --set vpcId=${VPC_ID}

# Verify
kubectl get deployment aws-load-balancer-controller -n kube-system
```

---

### 3.2 Install Cluster Autoscaler

```bash
# Get role ARN
CA_ROLE_ARN=$(terraform output -raw cluster_autoscaler_role_arn)

# Create service account
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: ${CA_ROLE_ARN}
EOF

# Deploy autoscaler
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    app: cluster-autoscaler
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
        - name: cluster-autoscaler
          image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.28.2
          command:
            - ./cluster-autoscaler
            - --v=4
            - --stderrthreshold=info
            - --cloud-provider=aws
            - --skip-nodes-with-local-storage=false
            - --expander=least-waste
            - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/techitfactory-dev
            - --balance-similar-node-groups
            - --skip-nodes-with-system-pods=false
          resources:
            limits:
              cpu: 100m
              memory: 600Mi
            requests:
              cpu: 100m
              memory: 600Mi
EOF

# Verify
kubectl get pods -n kube-system | grep autoscaler
```

---

### 3.3 Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait and verify
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
```

---

## PHASE 4: Verification

### Check Everything

```bash
echo "=== Nodes ==="
kubectl get nodes

echo "=== System Pods ==="
kubectl get pods -n kube-system

echo "=== EKS Add-ons ==="
aws eks list-addons --cluster-name techitfactory-dev

echo "=== ECR Repositories ==="
aws ecr describe-repositories --query "repositories[*].repositoryName"
```

### Test ALB Ingress

```bash
# Deploy test app
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-test
  template:
    metadata:
      labels:
        app: hello-test
    spec:
      containers:
      - name: hello
        image: hashicorp/http-echo
        args: ["-text=Hello from TechITFactory!"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: hello-test
spec:
  selector:
    app: hello-test
  ports:
  - port: 80
    targetPort: 5678
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-test
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-test
            port:
              number: 80
EOF

# Wait 2 minutes, then get URL
kubectl get ingress hello-test
# curl http://<ALB-URL>

# Cleanup
kubectl delete ingress,svc,deployment hello-test
```

---

## Cost Summary

| Resource | Monthly Cost |
|----------|--------------|
| NAT Gateway | ~$32 |
| EKS Control Plane | ~$72 |
| 2x t3.medium nodes | ~$60 |
| EBS Storage | ~$10 |
| CloudWatch | ~$5 |
| ECR Storage | ~$1 |
| ALB (when running) | ~$16 |
| **Total** | **~$195/month** |

---

## Cleanup (When Done)

```bash
# Destroy in reverse order
cd ~/Desktop/Devops-Project/techitfactory-infra/environments/dev
terraform destroy

cd ../bootstrap
terraform destroy
```

---

## Troubleshooting

### EKS Node Not Joining
```bash
kubectl describe nodes
aws eks describe-nodegroup --cluster-name techitfactory-dev --nodegroup-name techitfactory-dev-nodes
```

### ALB Not Creating
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

### Terraform State Lock
```bash
terraform force-unlock <LOCK_ID>
```
