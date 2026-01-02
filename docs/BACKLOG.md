# Product Backlog (Production-Grade)

> 10 Epics across 6 Sprints (+ Sprint 0 for Agile Setup)

---

## Sprint 0: Agile Foundation
*No code. Jira setup only.*

---

## Sprint 1: Foundation & Infrastructure

### Epic 1: Course Foundation – Repos, Standards, Trunk-Based Workflow

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Create 3 repos (Infra/App/GitOps) | Each repo has README, branching model, skeleton | Create infra, app, gitops repo skeletons |
| Enforce Trunk-Based Development | Branch protection, PR templates, CODEOWNERS | Configure GitHub rules, add templates |

### Epic 2: Terraform Bootstrap – Remote State + IAM + GitHub OIDC

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Build bootstrap stack (S3 + DynamoDB + KMS) | Remote state works, idempotent | Implement S3/DynamoDB/KMS Terraform |
| Configure GitHub OIDC for AWS | No static keys, least-privilege | Create OIDC provider, IAM role |
| Create Terraform module skeleton | /modules/vpc, /modules/eks exist | Scaffold modules, add CI |

### Epic 3: Networking – VPC + Subnets + Single NAT + Endpoints

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Provision VPC (multi-AZ, single NAT) | Cost-optimized, 2 AZs, clean destroy | Implement VPC module |
| Add VPC endpoints (S3 gateway) | Reduce NAT costs, document impact | Add endpoints, measure |

---

## Sprint 2: Platform Setup

### Epic 4: EKS Cluster Baseline – Managed Nodes + Autoscaling + Add-ons

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Provision EKS cluster | Terraform, version pinned, OIDC issuer | EKS module, logging |
| Configure SSO access | kubectl works with SSO, no static keys | aws-auth mapping, guide |
| Install Cluster Autoscaler (IRSA) | Scale-out/in verified | IRSA role, deploy autoscaler |
| Install baseline add-ons | metrics-server, EBS CSI | Add-ons via Terraform |

### Epic 5: Ingress + Domain – ALB Controller + Route53 + TLS

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Install ALB Controller (IRSA) | Test ingress creates ALB | IRSA, install, validate |
| Configure Route53 + TLS (dev.techitfactory.com) | HTTPS working, smoke test | ACM cert, Route53 record |

---

## Sprint 3: GitOps & Observability

### Epic 6: ArgoCD Production Bootstrap – App-of-Apps

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Install ArgoCD (Helm) | UI accessible via ingress | Helm install, expose |
| Bootstrap App-of-Apps | GitOps repo syncs automatically | Root app, sync policies |
| Create Argo Projects (dev/prod) | Blast-radius control | Namespaces, project restrictions |

### Epic 7: Observability – Prometheus + Loki + Grafana

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Deploy kube-prometheus-stack | Grafana accessible, metrics visible | Install, dashboard |
| Deploy Loki | Logs visible in Grafana | Loki stack, datasource |

---

## Sprint 4: Application Development

### Epic 8: Walking Skeleton App – Polyglot Services + Dockerfiles + Helm

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Create monorepo structure | /services/frontend, product, cart, order | Folder structure, READMEs |
| Create Dockerfiles | Non-root, multi-stage, <100MB | Dockerfiles, .dockerignore |
| Create Helm charts | Deployment + Service + probes | Scaffold charts, values |
| Expose dev entrypoint | dev.techitfactory.com serves frontend | Ingress routes, smoke test |

---

## Sprint 5: CI/CD Pipeline

### Epic 9: GitHub Actions + Dev Auto-Deploy + Prod Promotion

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Per-service GitHub Actions | Lint, test, Trivy scan, push to DockerHub | Workflows per service |
| Integrate SonarCloud | Quality gates in PR | SonarCloud setup |
| Dev auto-deploy on merge | GitOps repo updated, ArgoCD syncs | Workflow updates GitOps |
| Prod promotion via Release/Tag | Manual gate, prod values updated | Release workflow |

---

## Sprint 6: Automation & Polish

### Epic 10: Daily Build & Destroy Automation

| Story | Acceptance Criteria | Tasks |
|-------|---------------------|-------|
| Create make up / make down scripts | One-command, idempotent | Orchestration scripts |
| Capture boot-time metrics (<20 min) | Timed, documented | Timing, optimization doc |

---

## Summary

| Sprint | Epics | Focus |
|--------|-------|-------|
| 0 | - | Agile Foundation |
| 1 | 1, 2, 3 | Repos + Terraform + VPC |
| 2 | 4, 5 | EKS + Ingress |
| 3 | 6, 7 | ArgoCD + Observability |
| 4 | 8 | Application |
| 5 | 9 | CI/CD |
| 6 | 10 | Automation |
