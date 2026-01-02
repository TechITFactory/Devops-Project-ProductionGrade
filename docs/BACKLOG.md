# Product Backlog

Copy these Epics and Stories into your Jira board.

---

## Epic 1: Local Development Environment
**Goal:** Any developer can run the full stack locally in under 5 minutes.

### Stories:
| ID | Story | Acceptance Criteria | Points |
|----|-------|---------------------|--------|
| S1.1 | As a developer, I want a single command to start all services | `make local` starts everything | 3 |
| S1.2 | As a developer, I want health checks for all services | `/health` returns 200 | 2 |
| S1.3 | As a developer, I want an automated end-to-end test | `scripts/demo.sh` passes | 3 |

---

## Epic 2: Containerization & Registry
**Goal:** All services are containerized and stored in a private registry.

### Stories:
| ID | Story | Acceptance Criteria | Points |
|----|-------|---------------------|--------|
| S2.1 | As a DevOps engineer, I want optimized Dockerfiles | Multi-stage builds, <100MB images | 3 |
| S2.2 | As a DevOps engineer, I want images pushed to ECR | `make push` succeeds | 3 |

---

## Epic 3: Kubernetes (Local)
**Goal:** The application runs on a local Kubernetes cluster.

### Stories:
| ID | Story | Acceptance Criteria | Points |
|----|-------|---------------------|--------|
| S3.1 | As a DevOps engineer, I want a local cluster | Kind cluster created | 2 |
| S3.2 | As a DevOps engineer, I want deployment manifests | All pods Running | 5 |
| S3.3 | As a DevOps engineer, I want service exposure | Ingress/Gateway routes traffic | 3 |

---

## Epic 4: GitOps & ArgoCD
**Goal:** Deployments are automated via Git.

### Stories:
| ID | Story | Acceptance Criteria | Points |
|----|-------|---------------------|--------|
| S4.1 | As a DevOps engineer, I want ArgoCD installed | ArgoCD UI accessible | 2 |
| S4.2 | As a DevOps engineer, I want App-of-Apps | All apps synced | 5 |

---

## Epic 5: AWS Production
**Goal:** The application runs on AWS EKS.

### Stories:
| ID | Story | Acceptance Criteria | Points |
|----|-------|---------------------|--------|
| S5.1 | As a DevOps engineer, I want an EKS cluster | `kubectl get nodes` shows AWS nodes | 5 |
| S5.2 | As a DevOps engineer, I want GitOps on EKS | ArgoCD deploys to EKS | 5 |

---

## Epic 6: Observability
**Goal:** We can monitor and alert on production health.

### Stories:
| ID | Story | Acceptance Criteria | Points |
|----|-------|---------------------|--------|
| S6.1 | As an SRE, I want Prometheus metrics | `/metrics` scraped | 3 |
| S6.2 | As an SRE, I want Grafana dashboards | CPU/Memory visible | 3 |
| S6.3 | As an SRE, I want security scans | Trivy runs on images | 2 |

---

## Sprint Allocation

| Sprint | Epics |
|--------|-------|
| Sprint 1 | Epic 1 |
| Sprint 2 | Epic 2 |
| Sprint 3 | Epic 3 |
| Sprint 4 | Epic 4 |
| Sprint 5 | Epic 5 |
| Sprint 6 | Epic 6 |
