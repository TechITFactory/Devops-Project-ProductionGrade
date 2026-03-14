# Repository Structure (3-Repo Model)

Production-grade DevOps uses **separate repositories** for different concerns.

---

## Why 3 Repos?

| Concern | Single Repo (Anti-Pattern) | 3 Repos (Best Practice) |
|---------|---------------------------|-------------------------|
| **Blast Radius** | One bad commit breaks everything | Isolated failures |
| **Permissions** | Everyone has access to infra | RBAC: Infra team vs App team |
| **CI/CD** | Slow pipelines (rebuild all) | Fast, targeted pipelines |
| **GitOps** | Mixing app code with deployments | Clean separation |

---

## The 3 Repositories

### 1. Infra Repo (`techitfactory-infra`)
**Purpose:** Terraform code for AWS infrastructure.

```
techitfactory-infra/
├── bootstrap/          # S3 state, DynamoDB lock, KMS
├── modules/
│   ├── vpc/           # VPC, subnets, NAT
│   └── eks/           # EKS cluster, node groups
├── environments/
│   ├── dev/
│   └── prod/
└── .github/workflows/  # Terraform plan/apply
```

### 2. App Repo (`techitfactory-app`)
**Purpose:** Microservices source code + Dockerfiles.

```
techitfactory-app/
├── services/
│   ├── frontend/      # React
│   ├── product/       # Node.js
│   ├── cart/          # Node.js
│   └── order/         # Python
├── charts/            # Helm charts
└── .github/workflows/ # Build, scan, push images
```

### 3. GitOps Repo (`techitfactory-gitops`)
**Purpose:** ArgoCD Application manifests (source of truth for cluster state).

```
techitfactory-gitops/
├── apps/
│   ├── platform/      # ArgoCD, Prometheus, Loki
│   └── services/      # App Helm releases
├── environments/
│   ├── dev/
│   └── prod/
└── app-of-apps.yaml   # Root ArgoCD application
```

---

## When Are They Created?

| Sprint | Repo Created |
|--------|--------------|
| Sprint 1 | All 3 skeletons |
| Sprint 1-2 | Infra populated |
| Sprint 3 | GitOps populated |
| Sprint 4 | App populated |
