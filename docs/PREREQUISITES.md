# Course Prerequisites

## Who Is This Course For?

DevOps engineers who have completed **fundamentals training** but want to understand how **real-world production projects** work.

---

## Required Knowledge (Must Have)

| Topic | What You Should Know |
|-------|---------------------|
| **Linux** | Terminal, SSH, file permissions |
| **Git** | Clone, branch, commit, push, PR |
| **Docker** | Build, run, Dockerfile basics |
| **Kubernetes** | Pods, Deployments, Services, kubectl |
| **AWS** | EC2, S3, IAM basics, Console navigation |

---

## Required Accounts (Free Tier Sufficient)

| Account | Why | Link |
|---------|-----|------|
| **GitHub** | Code hosting, CI/CD | https://github.com |
| **AWS** | Cloud infrastructure | https://aws.amazon.com/free |
| **Jira** | Agile project management | https://www.atlassian.com/software/jira/free |
| **DockerHub** | Container registry | https://hub.docker.com |
| **SonarCloud** | Code quality (optional) | https://sonarcloud.io |

---

## Required Tools (Install Before Starting)

### Core Tools
```bash
# Check versions with these commands
docker --version          # Docker 24+
kubectl version --client  # Kubernetes 1.28+
terraform --version       # Terraform 1.6+
aws --version            # AWS CLI 2.x
helm version             # Helm 3.x
```

### Installation Links

| Tool | macOS | Linux |
|------|-------|-------|
| Docker | `brew install --cask docker` | [Docker Docs](https://docs.docker.com/engine/install/) |
| kubectl | `brew install kubectl` | [K8s Docs](https://kubernetes.io/docs/tasks/tools/) |
| Terraform | `brew install terraform` | [TF Docs](https://developer.hashicorp.com/terraform/install) |
| AWS CLI | `brew install awscli` | [AWS Docs](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Helm | `brew install helm` | [Helm Docs](https://helm.sh/docs/intro/install/) |
| eksctl | `brew install eksctl` | [eksctl Docs](https://eksctl.io/installation/) |
| Kind | `brew install kind` | [Kind Docs](https://kind.sigs.k8s.io/docs/user/quick-start/) |

---

## AWS Budget Warning ⚠️

This course creates real AWS resources. Estimated costs:

| Resource | Hourly Cost | Daily (8hr) |
|----------|-------------|-------------|
| EKS Control Plane | $0.10/hr | ~$0.80 |
| 2x t3.medium nodes | $0.08/hr | ~$1.28 |
| NAT Gateway | $0.045/hr | ~$0.36 |
| **Total** | ~$0.23/hr | **~$2.50/day** |

**Important:** We provide `make down` scripts to destroy resources when not in use.

---

## Recommended (Nice to Have)

- VS Code with extensions: Docker, Kubernetes, Terraform, GitLens
- Terminal: iTerm2 (macOS) or Windows Terminal
- Basic understanding of YAML and JSON
