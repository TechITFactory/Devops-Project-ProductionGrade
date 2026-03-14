# Product Backlog (Production-Grade)

> 10 Epics across 6 Sprints (+ Sprint 0 for Agile Setup)
> 
> **How to Read This Document:**
> Each Epic contains an **Architect's Brief** explaining the *why*, *what*, and *how*. Read this first before starting any story. The tables show the work breakdown.

---

## Sprint 0: Agile Foundation

**Duration:** 1 Day | **No Code**

### Architect's Brief
Before writing any code, we establish our working process. This mirrors real companies where a new engineer first learns the team's workflow before contributing.

**Goals:**
- Understand Scrum ceremonies (standup, planning, retro)
- Set up personal Jira board with all Epics/Stories
- Familiarize with Definition of Done

**Outcome:** You can explain the sprint process in an interview.

---

## Sprint 1: Foundation & Infrastructure

**Duration:** 2 Weeks | **Key Deliverable:** VPC + Terraform Pipeline

---

### Epic 1: Course Foundation – Repos, Standards, Trunk-Based Workflow

#### Architect's Brief

**Problem Statement:**
Most teams fail not because of bad code, but because of bad Git hygiene. Broken deploys come from:
- Direct pushes to main
- Missing code reviews
- No CI gates

**Our Approach:**
We adopt **Trunk-Based Development** — all work happens on short-lived feature branches merged quickly to `main`. No long-lived branches. No "develop" branch.

**The 3-Repo Model:**
```
techitfactory-infra     → Terraform (VPC, EKS, IAM)
techitfactory-app       → Microservices Code + Dockerfiles
techitfactory-gitops    → ArgoCD Manifests (Source of Truth)
```

**Why 3 repos?**
- **Separation of Concerns**: Infra changes don't trigger app builds
- **Permissions**: Not everyone should have Terraform access
- **GitOps**: App code must not live with deployment manifests

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Create 3 repos (Infra/App/GitOps) | Each repo has README, branching model, skeleton | Create infra, app, gitops repo skeletons |
| Enforce Trunk-Based Development | Branch protection, PR templates, CODEOWNERS | Configure GitHub rules, add templates |

---

### Epic 2: Terraform Bootstrap – Remote State + IAM + GitHub OIDC

#### Architect's Brief

**Problem Statement:**
If two engineers run `terraform apply` at the same time, they can corrupt state. If we store AWS keys in GitHub, one leak = account compromised.

**Our Approach:**
1. **Remote State**: Store `terraform.tfstate` in S3 with DynamoDB locking
2. **OIDC Authentication**: GitHub → AWS without any static credentials
3. **Bootstrap First**: Create state bucket *before* any other infrastructure

**Technical Flow:**
```
GitHub Actions → Assumes AWS Role via OIDC → Runs Terraform → S3 locks state
```

**Key Security Principle:**
*No long-lived AWS credentials anywhere.* Not in GitHub secrets. Not on laptops.

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Build bootstrap stack (S3 + DynamoDB + KMS) | Remote state works, idempotent | Implement S3/DynamoDB/KMS Terraform |
| Configure GitHub OIDC for AWS | No static keys, least-privilege | Create OIDC provider, IAM role |
| Create Terraform module skeleton | /modules/vpc, /modules/eks exist | Scaffold modules, add CI |

---

### Epic 3: Networking – VPC + Subnets + Single NAT + Endpoints

#### Architect's Brief

**Problem Statement:**
A poorly designed VPC costs money and creates security holes. Common mistakes:
- NAT Gateway per AZ = $96/month wasted in learning env
- Public subnets for worker nodes = security risk
- No VPC endpoints = unnecessary NAT traffic

**Our Approach:**
```
┌─────────────────────────────────────────────┐
│                    VPC                       │
│  ┌─────────────┐      ┌─────────────┐       │
│  │  Public     │      │  Public     │       │
│  │  Subnet A   │      │  Subnet B   │       │
│  └─────┬───────┘      └─────────────┘       │
│        │ NAT Gateway (Single)               │
│  ┌─────▼───────┐      ┌─────────────┐       │
│  │  Private    │      │  Private    │       │
│  │  Subnet A   │      │  Subnet B   │       │
│  │  (Workers)  │      │  (Workers)  │       │
│  └─────────────┘      └─────────────┘       │
└─────────────────────────────────────────────┘
```

**Cost Optimization:**
- Single NAT = saves $32/month (acceptable for non-HA learning env)
- S3 Gateway Endpoint = free, avoids NAT for S3 traffic

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Provision VPC (multi-AZ, single NAT) | Cost-optimized, 2 AZs, clean destroy | Implement VPC module |
| Add VPC endpoints (S3 gateway) | Reduce NAT costs, document impact | Add endpoints, measure |

---

## Sprint 2: Platform Setup

**Duration:** 2 Weeks | **Key Deliverable:** EKS Cluster + HTTPS Ingress

---

### Epic 4: EKS Cluster Baseline – Managed Nodes + Autoscaling + Add-ons

#### Architect's Brief

**Problem Statement:**
Running Kubernetes is hard. Self-managed clusters (kubeadm, kops) require patching, upgrades, and HA management. Most teams don't have time for this.

**Our Approach:**
Use **AWS EKS** — a managed Kubernetes control plane. AWS handles:
- Control plane HA (3 masters behind the scenes)
- Kubernetes version upgrades
- etcd backups

**We manage:**
- Worker nodes (Managed Node Groups)
- Add-ons (metrics-server, CSI drivers)
- Pod security

**Key Pattern — IRSA (IAM Roles for Service Accounts):**
Instead of giving all pods the node's IAM role, each pod gets its own role.
```
Pod (product-service) → ServiceAccount → IAM Role (S3 read only)
Pod (order-service)   → ServiceAccount → IAM Role (SQS write)
```

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Provision EKS cluster | Terraform, version pinned, OIDC issuer | EKS module, logging |
| Configure SSO access | kubectl works with SSO, no static keys | aws-auth mapping, guide |
| Install Cluster Autoscaler (IRSA) | Scale-out/in verified | IRSA role, deploy autoscaler |
| Install baseline add-ons | metrics-server, EBS CSI | Add-ons via Terraform |

---

### Epic 5: Ingress + Domain – ALB Controller + Route53 + TLS

#### Architect's Brief

**Problem Statement:**
Kubernetes Services are internal by default. We need:
- External access (LoadBalancer)
- HTTPS (TLS termination)
- Custom domain (dev.techitfactory.com)

**Our Approach:**
1. **AWS Load Balancer Controller**: Watches Ingress objects, creates ALBs automatically
2. **ACM Certificate**: Free, auto-renewing TLS from AWS
3. **Route53**: DNS management for techitfactory.com

**Traffic Flow:**
```
User → Route53 (DNS) → ALB (TLS) → K8s Ingress → Pod
```

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Install ALB Controller (IRSA) | Test ingress creates ALB | IRSA, install, validate |
| Configure Route53 + TLS (dev.techitfactory.com) | HTTPS working, smoke test | ACM cert, Route53 record |

---

## Sprint 3: GitOps & Observability

**Duration:** 2 Weeks | **Key Deliverable:** ArgoCD + Grafana Dashboards

---

### Epic 6: ArgoCD Production Bootstrap – App-of-Apps

#### Architect's Brief

**Problem Statement:**
Manual `kubectl apply` is error-prone and unauditable:
- Who deployed what?
- When did it change?
- How do we rollback?

**Our Approach — GitOps:**
Git is the **single source of truth**. The cluster *pulls* desired state from Git.

**Key Pattern — App-of-Apps:**
```
root-app.yaml (ArgoCD watches this)
    └── Applications/
        ├── platform.yaml → Prometheus, Loki, Grafana
        └── services.yaml → Frontend, Product, Cart, Order
```

**Promotion Model:**
- `main` branch → deploys to `dev` namespace (auto-sync)
- Git Tag/Release → deploys to `prod` namespace (manual gate)

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Install ArgoCD (Helm) | UI accessible via ingress | Helm install, expose |
| Bootstrap App-of-Apps | GitOps repo syncs automatically | Root app, sync policies |
| Create Argo Projects (dev/prod) | Blast-radius control | Namespaces, project restrictions |

---

### Epic 7: Observability – Prometheus + Loki + Grafana

#### Architect's Brief

**Problem Statement:**
"The app is slow" is not actionable. We need:
- **Metrics**: CPU, memory, request latency, error rates
- **Logs**: Structured, searchable, correlated with metrics
- **Dashboards**: Visual, alertable

**Our Approach — PLG Stack:**
```
Prometheus (Metrics) ─┐
                      ├──▶ Grafana (Dashboards)
Loki (Logs) ─────────┘
```

**Why PLG over ELK?**
- Loki is cheaper (no full-text indexing)
- Same label model as Prometheus
- Lighter footprint

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Deploy kube-prometheus-stack | Grafana accessible, metrics visible | Install, dashboard |
| Deploy Loki | Logs visible in Grafana | Loki stack, datasource |

---

## Sprint 4: Application Development

**Duration:** 2 Weeks | **Key Deliverable:** 4 Microservices Running in Dev

---

### Epic 8: Walking Skeleton App – Polyglot Services + Dockerfiles + Helm

#### Architect's Brief

**Problem Statement:**
The platform is ready, but empty. We need an application to validate the entire flow.

**Our Approach — Walking Skeleton:**
A "Walking Skeleton" is a minimal, end-to-end working system. Not feature-complete, but proves the architecture works.

**Service Design:**
```
Frontend (React) → Product API (Node) → MongoDB
                 → Cart API (Node)    → MongoDB
                 → Order API (Python) → MongoDB
```

**Key Contracts:**
- Every service MUST expose `/health` and `/ready`
- Every Dockerfile MUST be multi-stage (builder + runtime)
- Every container MUST run as non-root
- Every Helm chart MUST define resource requests/limits

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Create monorepo structure | /services/frontend, product, cart, order | Folder structure, READMEs |
| Create Dockerfiles | Non-root, multi-stage, <100MB | Dockerfiles, .dockerignore |
| Create Helm charts | Deployment + Service + probes | Scaffold charts, values |
| Expose dev entrypoint | dev.techitfactory.com serves frontend | Ingress routes, smoke test |

---

## Sprint 5: CI/CD Pipeline

**Duration:** 2 Weeks | **Key Deliverable:** Automated Build → Scan → Deploy

---

### Epic 9: GitHub Actions + Dev Auto-Deploy + Prod Promotion

#### Architect's Brief

**Problem Statement:**
Building and deploying manually doesn't scale. We need:
- Automated builds on PR
- Security scanning before merge
- Automatic deployment to dev
- Controlled promotion to prod

**Our Pipeline:**
```
PR Created  → Lint + Test + SonarCloud
PR Merged   → Docker Build → Trivy Scan → Push to DockerHub
            → Update GitOps repo (dev values)
            → ArgoCD auto-syncs to dev

Release Tag → Update GitOps repo (prod values)
            → ArgoCD syncs to prod (manual sync)
```

**Quality Gates:**
1. **SonarCloud**: Code quality (bugs, code smells, coverage)
2. **Trivy**: Container image vulnerabilities (CRITICAL = fail)

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Per-service GitHub Actions | Lint, test, Trivy scan, push to DockerHub | Workflows per service |
| Integrate SonarCloud | Quality gates in PR | SonarCloud setup |
| Dev auto-deploy on merge | GitOps repo updated, ArgoCD syncs | Workflow updates GitOps |
| Prod promotion via Release/Tag | Manual gate, prod values updated | Release workflow |

---

## Sprint 6: Automation & Polish

**Duration:** 1 Week | **Key Deliverable:** One-Command Platform

---

### Epic 10: Daily Build & Destroy Automation

#### Architect's Brief

**Problem Statement:**
AWS bills add up. A running EKS cluster costs ~$72/month even when idle.

**Our Approach:**
Create `make up` and `make down` scripts for daily build/destroy.

```bash
# Morning: Spin up environment
make up   # ~15-20 minutes

# Evening: Tear down (save $$$)
make down # ~5 minutes
```

**Idempotency Requirement:**
Running `make up` twice should not break anything. Running `make down` twice should not error.

**Boot Time Target:**
Under 20 minutes from `make up` to working Grafana dashboard.

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Create make up / make down scripts | One-command, idempotent | Orchestration scripts |
| Capture boot-time metrics (<20 min) | Timed, documented | Timing, optimization doc |

---

## Summary

| Sprint | Epics | Focus | Key Outcome |
|--------|-------|-------|-------------|
| 0 | - | Agile Foundation | Jira board ready |
| 1 | 1, 2, 3 | Repos + Terraform + VPC | Infrastructure pipeline working |
| 2 | 4, 5 | EKS + Ingress | Cluster with HTTPS ingress |
| 3 | 6, 7 | ArgoCD + Observability | GitOps + Monitoring |
| 4 | 8 | Application | 4 services running in dev |
| 5 | 9 | CI/CD | Fully automated pipeline |
| 6 | 10 | Automation | One-command platform |
