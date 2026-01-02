#!/bin/bash
# S1.1 - Create 3 Production Repos (Skeleton)
# Usage: ./create.sh

set -e

ORG="TechITFactory"
BASE_DIR="${1:-$HOME/techitfactory}"

echo "=== Creating repos in: $BASE_DIR ==="
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

# ============================================
# REPO 1: techitfactory-infra
# ============================================
echo ""
echo "=== Creating techitfactory-infra ==="

mkdir -p techitfactory-infra
cd techitfactory-infra
git init

# Folder structure
mkdir -p bootstrap
mkdir -p modules/vpc
mkdir -p modules/eks
mkdir -p environments/dev
mkdir -p environments/prod
mkdir -p .github/workflows

# README
cat > README.md << 'EOF'
# TechIT Factory - Infrastructure

Terraform code for AWS infrastructure.

## Structure
- `bootstrap/` - S3 state, DynamoDB lock, KMS
- `modules/vpc/` - VPC, subnets, NAT
- `modules/eks/` - EKS cluster, node groups
- `environments/` - Dev and Prod configurations

## Branching
- `main` → Protected, requires PR
- Feature branches → Short-lived
EOF

# .gitignore
cat > .gitignore << 'EOF'
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl
*.tfvars
!*.tfvars.example
.idea/
.vscode/
.DS_Store
EOF

# CODEOWNERS
cat > CODEOWNERS << 'EOF'
* @TechITFactory/infra-team
bootstrap/ @TechITFactory/security-team
EOF

# Placeholders
echo "# Bootstrap - Coming in Sprint 1, Epic 2" > bootstrap/main.tf
echo "# VPC Module - Coming in Sprint 1, Epic 3" > modules/vpc/main.tf
echo "# EKS Module - Coming in Sprint 2, Epic 4" > modules/eks/main.tf
echo "# Dev Environment - Coming later" > environments/dev/main.tf

git add .
git commit -m "Initial infra repo skeleton"
echo "✅ techitfactory-infra created"

cd "$BASE_DIR"

# ============================================
# REPO 2: techitfactory-app
# ============================================
echo ""
echo "=== Creating techitfactory-app ==="

mkdir -p techitfactory-app
cd techitfactory-app
git init

# Folder structure
mkdir -p services/frontend
mkdir -p services/product
mkdir -p services/cart
mkdir -p services/order
mkdir -p charts
mkdir -p .github/workflows

# README
cat > README.md << 'EOF'
# TechIT Factory - Application

Microservices monorepo for e-commerce platform.

## Structure
- `services/frontend/` - React SPA
- `services/product/` - Product API (Node.js)
- `services/cart/` - Cart API (Node.js)
- `services/order/` - Order API (Python)
- `charts/` - Helm charts

## Service Contracts
All services MUST expose:
- `GET /health` → Liveness probe
- `GET /ready` → Readiness probe

## Coming in Sprint 4
- Service implementation
- Dockerfiles
- Helm charts
EOF

# .gitignore
cat > .gitignore << 'EOF'
node_modules/
__pycache__/
*.pyc
.venv/
dist/
build/
.env
.idea/
.vscode/
.DS_Store
EOF

# CODEOWNERS
cat > CODEOWNERS << 'EOF'
services/ @TechITFactory/app-team
charts/ @TechITFactory/platform-team
EOF

# Service placeholders
echo "# Frontend - Coming in Sprint 4" > services/frontend/README.md
echo "# Product Service - Coming in Sprint 4" > services/product/README.md
echo "# Cart Service - Coming in Sprint 4" > services/cart/README.md
echo "# Order Service - Coming in Sprint 4" > services/order/README.md

git add .
git commit -m "Initial app repo skeleton"
echo "✅ techitfactory-app created"

cd "$BASE_DIR"

# ============================================
# REPO 3: techitfactory-gitops
# ============================================
echo ""
echo "=== Creating techitfactory-gitops ==="

mkdir -p techitfactory-gitops
cd techitfactory-gitops
git init

# Folder structure
mkdir -p apps/platform
mkdir -p apps/services
mkdir -p environments/dev
mkdir -p environments/prod

# README
cat > README.md << 'EOF'
# TechIT Factory - GitOps

ArgoCD Application manifests - Single Source of Truth.

## Structure
- `apps/platform/` - ArgoCD, Prometheus, Loki, Grafana
- `apps/services/` - App Helm releases
- `environments/` - Dev and Prod value overrides

## How It Works
1. ArgoCD watches this repo
2. Changes here = Changes in cluster
3. Git history = Audit log

## Coming in Sprint 3
- ArgoCD App-of-Apps setup
- Platform applications
EOF

# CODEOWNERS
cat > CODEOWNERS << 'EOF'
apps/platform/ @TechITFactory/platform-team
apps/services/ @TechITFactory/app-team
environments/prod/ @TechITFactory/leads
EOF

# Placeholders
echo "# Platform apps - Coming in Sprint 3" > apps/platform/README.md
echo "# Service releases - Coming in Sprint 4" > apps/services/README.md

git add .
git commit -m "Initial gitops repo skeleton"
echo "✅ techitfactory-gitops created"

cd "$BASE_DIR"

# ============================================
# Summary
# ============================================
echo ""
echo "=== DONE ==="
echo "Created repos in: $BASE_DIR"
echo ""
ls -la
echo ""
echo "Next steps:"
echo "1. Create repos on GitHub (TechITFactory org)"
echo "2. Add remotes: git remote add origin https://github.com/TechITFactory/<repo>.git"
echo "3. Push: git push -u origin main"
