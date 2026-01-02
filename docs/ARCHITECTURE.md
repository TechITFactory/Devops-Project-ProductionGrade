# Course Architecture

## What You Will Build

By the end of this course, you will have built a **production-grade e-commerce platform** running on AWS.

---

## Architectural Thinking: Why These Choices?

This section explains the **reasoning** behind each technology decision. In real interviews, you'll be asked "Why did you choose X over Y?"

### Infrastructure Decisions

| Decision | Choice | Why | Alternatives Considered |
|----------|--------|-----|------------------------|
| **Cloud Provider** | AWS | Market leader (32%), most job postings, mature EKS | GCP (GKE), Azure (AKS) |
| **IaC Tool** | Terraform | Cloud-agnostic, industry standard, huge community | Pulumi, CloudFormation, CDK |
| **Container Orchestration** | EKS (Kubernetes) | Industry standard, portable skills, managed control plane | ECS (AWS-native), Fargate |
| **Region** | ap-south-1 | Low latency for India, cost-effective | us-east-1 (more services) |

### Networking Decisions

| Decision | Choice | Why | Cost Impact |
|----------|--------|-----|-------------|
| **NAT Gateway** | Single (1 AZ) | Cost optimization for learning; prod would use 2 | Saves ~$32/month |
| **VPC Endpoints** | S3 Gateway | Free, reduces NAT traffic | Saves data transfer costs |
| **Subnets** | Public + Private | Security best practice; nodes in private | Standard pattern |

### GitOps & Deployment Decisions

| Decision | Choice | Why | Alternatives Considered |
|----------|--------|-----|------------------------|
| **GitOps Tool** | ArgoCD | Pull-based, declarative, great UI | FluxCD (lighter), Jenkins X |
| **Package Manager** | Helm | Industry standard, templating, easy rollback | Kustomize (simpler) |
| **Registry** | DockerHub | Free tier, public images OK for course | ECR (private, costs more) |
| **CI Platform** | GitHub Actions | Integrated with GitHub, free for public repos | GitLab CI, CircleCI |

### Observability Decisions

| Decision | Choice | Why | Alternatives Considered |
|----------|--------|-----|------------------------|
| **Metrics** | Prometheus | CNCF standard, pull-based, free | Datadog (expensive SaaS) |
| **Logs** | Loki | Label-based like Prometheus, cost-efficient | ELK (heavy, expensive) |
| **Dashboards** | Grafana | Works with both Prometheus & Loki | CloudWatch (AWS lock-in) |
| **Stack Name** | PLG (Prometheus, Loki, Grafana) | Lightweight, open-source, production-proven | ELK, Datadog |

### Application Decisions

| Decision | Choice | Why | Alternatives Considered |
|----------|--------|-----|------------------------|
| **Architecture** | Microservices | Real-world pattern, independent scaling | Monolith (simpler) |
| **Languages** | Node.js + Python | Polyglot = realistic; shows both sync & async | Single language |
| **Database** | MongoDB | Schema-flexible, easy local setup | PostgreSQL, DynamoDB |
| **API Style** | REST | Universal, easy to debug | GraphQL, gRPC |

### Security Decisions

| Decision | Choice | Why | Benefit |
|----------|--------|-----|---------|
| **CI Auth** | GitHub OIDC | No static AWS keys | Zero secrets in CI |
| **Human Auth** | AWS SSO | Short-lived tokens | No IAM users |
| **Pod Identity** | IRSA | Least privilege per pod | No node-level creds |
| **Image Scanning** | Trivy | Free, fast, OSS | Snyk (paid) |
| **Code Quality** | SonarCloud | Free for OSS, quality gates | CodeClimate |

### Cost Optimization Decisions

| Decision | Why |
|----------|-----|
| **Single NAT** | Learning env doesn't need HA; saves $32/month |
| **t3.medium nodes** | Burstable, cheap, sufficient for microservices |
| **S3 Endpoint** | Avoids NAT charges for S3 traffic |
| **Daily Destroy** | `make down` saves ~$60/month if unused |
| **Spot Instances** | (Future optimization) Can save 60-90% |

---

### Decision Framework for Any Project

When choosing technologies, ask:
1. **Is it the industry standard?** → Maximizes job market value
2. **Is it open-source?** → Avoids vendor lock-in
3. **Does it have good documentation?** → Faster debugging
4. **Is there a free tier?** → Important for learning
5. **Is it portable?** → Skills transfer to other clouds

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                    │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Route53 (DNS)                                    │
│                    dev.techitfactory.com                                 │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    AWS Application Load Balancer                         │
│                         (ALB Ingress)                                    │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
┌─────────────────────────────────┼───────────────────────────────────────┐
│                         AWS EKS Cluster                                  │
│  ┌──────────────────────────────┼──────────────────────────────────┐    │
│  │                    Kubernetes Ingress                            │    │
│  └──────────────────────────────┼──────────────────────────────────┘    │
│                                 │                                        │
│  ┌──────────────────────────────┼──────────────────────────────────┐    │
│  │                      APPLICATION LAYER                           │    │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐    │    │
│  │  │ Frontend  │  │  Product  │  │   Cart    │  │   Order   │    │    │
│  │  │  (React)  │  │ (Node.js) │  │ (Node.js) │  │ (Python)  │    │    │
│  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                 │                                        │
│  ┌──────────────────────────────┼──────────────────────────────────┐    │
│  │                      PLATFORM LAYER                              │    │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐    │    │
│  │  │  ArgoCD   │  │Prometheus │  │   Loki    │  │  Grafana  │    │    │
│  │  │ (GitOps)  │  │ (Metrics) │  │  (Logs)   │  │(Dashboard)│    │    │
│  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘    │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS Infrastructure                               │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐            │
│  │    VPC    │  │    NAT    │  │    S3     │  │    ACM    │            │
│  │ (Network) │  │ (Egress)  │  │  (State)  │  │   (TLS)   │            │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘            │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## DevOps Pipeline Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Developer  │────▶│   GitHub    │────▶│   GitHub    │────▶│  DockerHub  │
│  (Commit)   │     │    (PR)     │     │  Actions    │     │  (Images)   │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                               │
                    ┌──────────────────────────┼──────────────────────────┐
                    │                          ▼                          │
                    │  ┌─────────────┐   ┌─────────────┐                 │
                    │  │   SonarCloud │   │    Trivy    │                 │
                    │  │(Code Quality)│   │(Image Scan) │                 │
                    │  └─────────────┘   └─────────────┘                 │
                    │         QUALITY GATES                               │
                    └──────────────────────────┬──────────────────────────┘
                                               │
                                               ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   GitOps    │◀───▶│   ArgoCD    │────▶│     EKS     │────▶│  Production │
│   (Repo)    │     │   (Sync)    │     │  (Deploy)   │     │   (Live)    │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

---

## 3-Repository Structure

```
┌────────────────────────────────────────────────────────────────────────┐
│                           GITHUB ORGANIZATION                           │
│                                                                          │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐│
│  │   INFRA REPO       │  │    APP REPO        │  │   GITOPS REPO      ││
│  │ (Terraform)        │  │ (Microservices)    │  │ (ArgoCD Manifests) ││
│  │                    │  │                    │  │                    ││
│  │ /bootstrap         │  │ /services          │  │ /apps              ││
│  │   └─ S3, DynamoDB  │  │   ├─ frontend      │  │   ├─ platform      ││
│  │ /modules           │  │   ├─ product       │  │   └─ services      ││
│  │   ├─ vpc           │  │   ├─ cart          │  │ /environments      ││
│  │   └─ eks           │  │   └─ order         │  │   ├─ dev           ││
│  │ /environments      │  │ /charts            │  │   └─ prod          ││
│  │   ├─ dev           │  │   └─ (Helm)        │  │                    ││
│  │   └─ prod          │  │                    │  │                    ││
│  └────────────────────┘  └────────────────────┘  └────────────────────┘│
│           │                       │                       │             │
│           └───────────────────────┼───────────────────────┘             │
│                                   ▼                                      │
│                        SINGLE SOURCE OF TRUTH                            │
└────────────────────────────────────────────────────────────────────────┘
```

---

## What You Will Learn (By Sprint)

| Sprint | Skills Gained |
|--------|---------------|
| **0** | Agile/Scrum, Jira, Backlog management |
| **1** | Terraform, Remote State, OIDC, VPC design |
| **2** | EKS, SSO, Autoscaling, Add-ons, ALB |
| **3** | ArgoCD, GitOps, App-of-Apps, PLG stack |
| **4** | Docker best practices, Helm, Service mesh basics |
| **5** | GitHub Actions, SonarCloud, Trivy, Release promotion |
| **6** | Cost optimization, Automation, Production readiness |

----

## AWS Infrastructure Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS ACCOUNT                                     │
│                           (ap-south-1 Region)                                │
│                                                                              │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                              VPC (10.0.0.0/16)                         │  │
│  │                                                                         │  │
│  │  ┌─────────────────────────────┐  ┌─────────────────────────────┐     │  │
│  │  │     Availability Zone A      │  │     Availability Zone B      │     │  │
│  │  │                              │  │                              │     │  │
│  │  │  ┌────────────────────────┐ │  │ ┌────────────────────────┐  │     │  │
│  │  │  │  Public Subnet         │ │  │ │  Public Subnet         │  │     │  │
│  │  │  │  10.0.1.0/24           │ │  │ │  10.0.2.0/24           │  │     │  │
│  │  │  │  ┌──────────────────┐  │ │  │ │  ┌──────────────────┐  │  │     │  │
│  │  │  │  │   ALB (Ingress)  │  │ │  │ │  │   ALB (Ingress)  │  │  │     │  │
│  │  │  │  └──────────────────┘  │ │  │ │  └──────────────────┘  │  │     │  │
│  │  │  └────────────────────────┘ │  │ └────────────────────────┘  │     │  │
│  │  │                              │  │                              │     │  │
│  │  │  ┌────────────────────────┐ │  │ ┌────────────────────────┐  │     │  │
│  │  │  │  Private Subnet        │ │  │ │  Private Subnet        │  │     │  │
│  │  │  │  10.0.10.0/24          │ │  │ │  10.0.20.0/24          │  │     │  │
│  │  │  │  ┌──────────────────┐  │ │  │ │  ┌──────────────────┐  │  │     │  │
│  │  │  │  │  EKS Worker Node │  │ │  │ │  │  EKS Worker Node │  │  │     │  │
│  │  │  │  │   (t3.medium)    │  │ │  │ │  │   (t3.medium)    │  │  │     │  │
│  │  │  │  └──────────────────┘  │ │  │ │  └──────────────────┘  │  │     │  │
│  │  │  └────────────────────────┘ │  │ └────────────────────────┘  │     │  │
│  │  │                              │  │                              │     │  │
│  │  └─────────────────────────────┘  └─────────────────────────────┘     │  │
│  │                                                                         │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐        │  │
│  │  │   NAT Gateway   │  │  S3 Endpoint    │  │ Internet Gateway │        │  │
│  │  │   (Single, AZ-A)│  │  (Cost Saving)  │  │                  │        │  │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘        │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │                         SUPPORTING SERVICES                              ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    ││
│  │  │    EKS      │  │   Route53   │  │     ACM     │  │     IAM     │    ││
│  │  │Control Plane│  │    (DNS)    │  │   (Certs)   │  │   (OIDC)    │    ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘    ││
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                     ││
│  │  │     S3      │  │  DynamoDB   │  │     KMS     │                     ││
│  │  │(Tfstate)    │  │ (State Lock)│  │ (Encryption)│                     ││
│  │  └─────────────┘  └─────────────┘  └─────────────┘                     ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key AWS Components

| Component | Purpose | Cost Impact |
|-----------|---------|-------------|
| **VPC** | Network isolation | Free |
| **NAT Gateway** | Private subnet internet access | $0.045/hr + data |
| **S3 Endpoint** | Bypass NAT for S3 traffic | Saves NAT costs |
| **EKS Control Plane** | Managed Kubernetes | $0.10/hr |
| **EC2 (t3.medium)** | Worker nodes | $0.0416/hr each |
| **ALB** | Load balancer | $0.0225/hr + LCU |
| **Route53** | DNS | $0.50/zone + queries |
| **ACM** | TLS certificates | Free |

---

## Application Architecture (Microservices)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER BROWSER                                    │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │ HTTPS
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FRONTEND (React SPA)                                 │
│                         dev.techitfactory.com                                │
│                                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Homepage  │  │   Product   │  │    Cart     │  │   Checkout  │        │
│  │    Page     │  │   Catalog   │  │    View     │  │    Flow     │        │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │ REST API
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           API GATEWAY (Ingress)                              │
│                                                                              │
│  /api/products/*  ──────▶  Product Service                                  │
│  /api/cart/*      ──────▶  Cart Service                                     │
│  /api/orders/*    ──────▶  Order Service                                    │
└─────────────────────────────────────────────────────────────────────────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        ▼                         ▼                         ▼
┌───────────────┐         ┌───────────────┐         ┌───────────────┐
│ PRODUCT SVC   │         │   CART SVC    │         │  ORDER SVC    │
│ (Node.js)     │         │  (Node.js)    │         │  (Python)     │
│               │         │               │         │               │
│ GET  /products│         │ GET  /cart    │         │ POST /orders  │
│ POST /products│         │ POST /cart    │         │ GET  /orders  │
│ GET  /health  │         │ DEL  /cart/:id│         │ GET  /health  │
│ GET  /ready   │         │ GET  /health  │         │ GET  /ready   │
└───────┬───────┘         └───────┬───────┘         └───────┬───────┘
        │                         │                         │
        └─────────────────────────┼─────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────┐
                    │        MongoDB          │
                    │   (In-cluster or Atlas) │
                    │                         │
                    │  Collections:           │
                    │  - products             │
                    │  - carts                │
                    │  - orders               │
                    │  - users                │
                    └─────────────────────────┘
```

### Service Communication Matrix

| From | To | Protocol | Port |
|------|-----|----------|------|
| Browser | Frontend | HTTPS | 443 |
| Frontend | Product API | HTTP | 3001 |
| Frontend | Cart API | HTTP | 3002 |
| Frontend | Order API | HTTP | 3003 |
| All Services | MongoDB | MongoDB | 27017 |

### Service Specifications

| Service | Language | Framework | Port | Image Size |
|---------|----------|-----------|------|------------|
| Frontend | TypeScript | React | 80 | ~50MB |
| Product | JavaScript | Express | 3001 | ~80MB |
| Cart | JavaScript | Express | 3002 | ~80MB |
| Order | Python | Flask | 3003 | ~100MB |

### Health Endpoints (Required for Kubernetes)

| Endpoint | Purpose | Expected Response |
|----------|---------|-------------------|
| `/health` | Liveness probe | `{"status": "ok"}` |
| `/ready` | Readiness probe | `{"status": "ready"}` (checks DB) |
| `/metrics` | Prometheus scrape | Metric export (optional) |
