# Sprint 5 — CI/CD: A Complete Beginner's Conversation

> This document is written as a Q&A conversation between a **student** (you) and a **teacher** (the explanation).
> Every question a beginner would ask is answered in plain English before anything technical is introduced.
> Read it top to bottom — each answer builds on the previous one.

---

## CHAPTER 1: What Even Is CI/CD?

---

**Q: What is CI/CD? I keep hearing this term.**

CI/CD stands for **Continuous Integration / Continuous Delivery**.

Let's break that down with a real example.

Before CI/CD, a developer would:
1. Write code
2. Manually test it on their laptop
3. Manually build a Docker image
4. Manually push it to AWS
5. Manually update the Kubernetes deployment
6. Manually verify it worked

This is slow, error-prone, and doesn't scale. If 5 developers are doing this at the same time, they step on each other.

**Continuous Integration (CI)** means: every time you push code, an automated system automatically tests it, builds it, and checks it for security issues.

**Continuous Delivery (CD)** means: once those checks pass, the system automatically deploys it — no human needs to do anything.

**The result:** You write code and push it. Everything else is automatic.

---

**Q: Okay, but what tool does this? Where does the automation run?**

The tool we use is called **GitHub Actions**.

It's built directly into GitHub. When you push code to GitHub, GitHub Actions can automatically run scripts — called **workflows** — in response.

Think of it like this:

```
You push code to GitHub
       ↓
GitHub sees the push
       ↓
GitHub asks: "Do I have any workflows that should run for this?"
       ↓
Yes → GitHub spins up a fresh Linux machine (called a "runner")
       ↓
Runner downloads your code
       ↓
Runner runs the steps you defined (test, build, deploy...)
       ↓
Runner shuts down when done
```

The Linux machine is provided by GitHub for free (up to limits). You don't manage any servers.

---

**Q: Where do I write these workflows?**

Inside your repository, in a special folder called `.github/workflows/`.

Any `.yml` file inside that folder is a workflow. GitHub automatically detects and runs them.

In our project, we have:

```
techitfactory-infra/
  .github/
    workflows/
      terraform-ci.yml      ← runs Terraform (creates AWS infra)
      platform-bootstrap.yml ← installs ArgoCD on the cluster

techitfactory-app/
  .github/
    workflows/
      ci.yml                ← tests + builds app images
      build-all.yml         ← first-time seed: builds all 6 services
      release.yml           ← production release pipeline
      sonarcloud.yml        ← code quality checks
```

---

**Q: What does a workflow YAML file look like? Can you show me the anatomy?**

Here is the absolute minimum workflow — it runs when you push to main and prints "Hello":

```yaml
name: My First Workflow         # Display name in GitHub UI

on:                             # WHEN does this run?
  push:                         #   "when someone pushes code..."
    branches: [main]            #   "...to the main branch"

jobs:                           # WHAT does it do?
  say-hello:                    #   job name (you make this up)
    runs-on: ubuntu-latest      #   use a fresh Ubuntu Linux machine

    steps:                      #   list of steps to run, in order
      - name: Print hello       #   step name (shown in logs)
        run: echo "Hello World" #   the actual command to run
```

That's the entire skeleton. Every workflow is just:
- **`on:`** — the trigger (when to run)
- **`jobs:`** — what to do (one or more jobs)
- **`steps:`** inside each job — the commands to execute

---

**Q: What is a "job"? What is a "step"? What's the difference?**

A **step** is a single command. Example: `run: terraform init`

A **job** is a group of steps that run together on the same machine, in order. Example: the "plan" job runs: fmt → init → validate → plan.

Multiple **jobs** can run at the same time (in parallel), but on separate machines.

```
Workflow run
├── Job 1: "test"     (runs on machine A)
│   ├── Step 1: npm install
│   ├── Step 2: npm test
│   └── Step 3: report results
│
├── Job 2: "lint"     (runs on machine B, in parallel with Job 1)
│   ├── Step 1: install linter
│   └── Step 2: run linter
│
└── Job 3: "build"    (WAITS for Job 1 and Job 2 to pass first)
    ├── Step 1: docker build
    └── Step 2: docker push
```

The `needs:` keyword makes a job wait for another job to finish:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps: [...]

  build:
    needs: test          # ← "don't start until 'test' passes"
    runs-on: ubuntu-latest
    steps: [...]
```

---

## CHAPTER 2: Secrets — How We Store Passwords Safely

---

**Q: If the pipeline needs to talk to AWS, where do I put the AWS password?**

You **never** put passwords directly in a workflow YAML file. That file is committed to git and visible to anyone with repo access.

Instead, GitHub has a **Secrets** system. You store sensitive values there, and workflow files reference them by name.

**How to add a secret:**

```
GitHub repo → Settings → Secrets and variables → Actions → New repository secret

Name:  AWS_ROLE_ARN
Value: arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/techitfactory-github-terraform
```

**How to use a secret in a workflow:**

```yaml
- name: Configure AWS
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}   # ← reads from Secrets
    aws-region: ap-south-1
```

The `${{ secrets.AWS_ROLE_ARN }}` syntax tells GitHub: "replace this with the secret value at runtime." The value is **never printed in logs** — GitHub masks it automatically.

---

**Q: What secrets does our project need and where do I add them?**

**In `techitfactory-infra` repo:**

```
Settings → Secrets and variables → Actions → New repository secret

Secret 1:
  Name:  AWS_ROLE_ARN
  Value: arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/techitfactory-github-terraform
```

**In `techitfactory-app` repo:**

```
Secret 1:
  Name:  AWS_ROLE_ARN
  Value: arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/techitfactory-github-terraform

Secret 2:
  Name:  GITOPS_TOKEN
  Value: (a GitHub Personal Access Token — see below)
```

**Why does the app repo need a GITOPS_TOKEN?**

The app CI pipeline needs to push commits to a *different* repo (`techitfactory-gitops`). GitHub Actions' default token only has access to the current repo. To push to another repo, you need a Personal Access Token (PAT) with write access to that other repo.

**How to create the GITOPS_TOKEN:**

```
GitHub.com → Your profile (top right) → Settings
→ Developer settings (bottom left)
→ Personal access tokens → Fine-grained tokens → Generate new token

Settings:
  Token name:     gitops-writer
  Expiration:     90 days (or custom)
  Repository access: Only select repositories → techitfactory-gitops
  Permissions:
    Contents: Read and Write   ← this is what allows git push

→ Generate token → COPY IT (shown only once)
```

Paste that token as the `GITOPS_TOKEN` secret in `techitfactory-app`.

---

## CHAPTER 3: Environments — What They Are and Why We Need Them

---

**Q: I've seen "environments" mentioned. What is a GitHub Environment?**

A GitHub Environment is a **deployment target** with optional protection rules.

Without environments, every workflow job runs immediately when triggered.

With environments, you can say: **"this job must wait for a human to approve it before running."**

This is critical for production. You don't want an automated pipeline directly deploying untested code to production without anyone reviewing it.

---

**Q: What environments do we need to create?**

**In `techitfactory-infra` repo:**

```
Settings → Environments → New environment

Environment 1: "dev"
  Protection rules: none (dev deploys automatically)

Environment 2: "prod" (or "production-infra")
  Protection rules:
    ✅ Required reviewers → add yourself
    (Any Terraform change to prod pauses and waits for your approval)

Environment 3: "bootstrap"
  Protection rules: none
```

**In `techitfactory-app` repo:**

```
Environment 1: "dev"
  Protection rules: none

Environment 2: "production"
  Protection rules:
    ✅ Required reviewers → add yourself
    Deployment branches: Tag pattern → v*
    (Only tags matching v1.0.0, v2.1.0, etc. can deploy to prod)
```

**How does a workflow use an environment?**

```yaml
jobs:
  tf-prod-apply:
    environment: production-infra   # ← names the environment to use
    steps:
      - run: terraform apply
```

When this job reaches the `environment:` line, GitHub **pauses the entire job** and sends you a notification. You go to GitHub Actions, click "Review deployments", and either Approve or Deny. Only after approval does `terraform apply` actually run.

---

## CHAPTER 4: OIDC — How GitHub Actions Talks to AWS Without a Password

---

**Q: What is OIDC? I've heard it mentioned but never understood it.**

OIDC stands for **OpenID Connect**. It's a way to prove your identity without a password.

The old (bad) way was:
```
Store permanent AWS access keys in GitHub Secrets:
  AWS_ACCESS_KEY_ID     = AKIAIOSFODNN7EXAMPLE
  AWS_SECRET_ACCESS_KEY = wJalrXUtnFEMI/K7MDENG...

Problem: These never expire. If leaked, the attacker has permanent AWS access.
```

The new (good) way with OIDC:
```
1. GitHub Actions starts a job
2. GitHub issues a JWT (a short-lived digital certificate):
   "I am GitHub Actions, running in repo YOUR_GITHUB_ORG/techitfactory-infra,
    on branch main, at 14:30 UTC, for commit abc123"
3. The workflow sends this JWT to AWS
4. AWS checks: "Does this match a trusted identity provider?"
   Answer: yes — we set up GitHub as a trusted OIDC provider in bootstrap
5. AWS issues temporary credentials valid for 1 hour
6. Workflow uses those credentials
7. After 1 hour, credentials expire automatically — even if stolen
```

---

**Q: Where was the OIDC trust set up?**

In our `bootstrap/` Terraform code. When we ran bootstrap, it created:

1. An **OIDC Identity Provider** in AWS IAM:
   ```
   Provider: token.actions.githubusercontent.com
   Thumbprint: (GitHub's SSL certificate fingerprint)
   ```
   This tells AWS: "Trust JWT tokens signed by GitHub"

2. An **IAM Role** called `techitfactory-github-terraform` with a trust policy:
   ```json
   {
     "Effect": "Allow",
     "Principal": {
       "Federated": "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
     },
     "Action": "sts:AssumeRoleWithWebIdentity",
     "Condition": {
       "StringLike": {
         "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/*:*"
       }
     }
   }
   ```
   This says: "Only allow GitHub Actions from the TechITFactory org to assume this role"

3. That role has permissions to do Terraform things: create VPCs, EKS clusters, ECR repos, etc.

---

**Q: What does the workflow YAML look like for OIDC?**

```yaml
permissions:
  id-token: write    # ← REQUIRED: allows the job to request an OIDC token
  contents: read

steps:
  - name: Configure AWS credentials (OIDC)
    uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
      aws-region: ap-south-1
```

The `aws-actions/configure-aws-credentials` action handles the entire OIDC exchange automatically. After this step runs, all subsequent AWS CLI commands and Terraform commands work without any additional configuration.

---

## CHAPTER 5: The `[deploy]` Keyword — Why Not Every Push Triggers the Pipeline

---

**Q: Why would you NOT want the pipeline to run on every push?**

Imagine you're working on a feature and you push 5 times in an hour:
- Push 1: "wip, added function skeleton"
- Push 2: "wip, filling in logic"
- Push 3: "oops, fixing typo"
- Push 4: "half working, moving on"
- Push 5: "done, ready to deploy"

Without a filter, each of those 5 pushes triggers the full pipeline:
- 5 Docker builds (each ~3 minutes)
- 5 ECR pushes
- 5 gitops commits (competing with each other)
- 5 ArgoCD syncs deploying half-baked code

That's wasteful and potentially breaks the running application 4 times for no reason.

---

**Q: So how does the `[deploy]` keyword solve this?**

We added one condition to the beginning of every pipeline:

```yaml
jobs:
  detect-changes:
    if: |
      github.event_name == 'pull_request' ||
      github.event_name == 'workflow_dispatch' ||
      github.event_name == 'schedule' ||
      contains(github.event.head_commit.message, '[deploy]')
```

Now the rules are:
- Push to main **without** `[deploy]` → nothing happens
- Push to main **with** `[deploy]` → pipeline runs
- Pull Request → pipeline always runs (but only tests, no deploy)
- Manual trigger (workflow_dispatch button in GitHub UI) → always runs
- Scheduled run (every Monday) → always runs

**Usage:**

```bash
# This push → no pipeline
git commit -m "wip: halfway done"
git push

# This push → pipeline runs
git commit -m "feat: add cart total calculation [deploy]"
git push

# This Terraform push → infra pipeline runs
git commit -m "feat: increase EKS node count to 3 [deploy]"
git push
```

---

## CHAPTER 6: The Terraform Pipeline — Explained Line by Line

---

**Q: Walk me through the Terraform CI/CD workflow. What does each line mean?**

Here is the full workflow broken down with explanations for every important section.

**File:** `techitfactory-infra/.github/workflows/terraform-ci.yml`

---

**SECTION 1: The trigger block**

```yaml
on:
  push:
    branches: [main]        # run on pushes to main (filtered by [deploy] keyword below)
  pull_request:
    branches: [main]        # run on PRs targeting main
  schedule:
    - cron: '0 6 * * 1'    # every Monday at 6am UTC (drift detection)
  workflow_dispatch:        # manual "Run workflow" button in GitHub UI
    inputs:
      environment:          # dropdown: bootstrap / dev / prod
        type: choice
        options: [dev, prod, bootstrap]
      action:               # dropdown: plan / apply
        type: choice
        options: [plan, apply]
```

The `schedule` block uses cron syntax: `0 6 * * 1` means "at minute 0, hour 6, any day of month, any month, on Monday (day 1)".

---

**SECTION 2: Concurrency control**

```yaml
concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: false   # ← NEVER cancel Terraform mid-run
```

`cancel-in-progress: false` is a critical safety setting for Terraform.

If you push two commits quickly:
- Run 1 starts: `terraform apply` begins creating the VPC...
- Run 2 starts: DO NOT cancel Run 1

If Run 1 is cancelled while creating the VPC, Terraform has:
- Created some subnets (now orphaned in AWS, billing you)
- The state file is locked (no one can run Terraform until force-unlock)
- Resources in an unknown half-created state

Always let Terraform finish, even if a newer commit is waiting.

---

**SECTION 3: The detect-changes job**

```yaml
jobs:
  detect-changes:
    name: Detect Changed Environments
    runs-on: ubuntu-latest
    if: |
      github.event_name == 'pull_request' ||
      github.event_name == 'workflow_dispatch' ||
      github.event_name == 'schedule' ||
      contains(github.event.head_commit.message, '[deploy]')
    outputs:
      bootstrap: ${{ steps.changes.outputs.bootstrap }}
      dev: ${{ steps.changes.outputs.dev }}
      prod: ${{ steps.changes.outputs.prod }}
    steps:
      - uses: actions/checkout@v4

      - name: Detect changes
        uses: dorny/paths-filter@v3
        id: changes
        with:
          filters: |
            bootstrap:
              - 'bootstrap/**'       # if any file in bootstrap/ changed
            dev:
              - 'environments/dev/**'
              - 'modules/**'         # module changes affect all envs
            prod:
              - 'environments/prod/**'
              - 'modules/**'
```

`dorny/paths-filter` compares the current commit against the previous commit.

It outputs `true` or `false` for each filter. Example output:
```
bootstrap = false
dev = true        ← someone changed environments/dev/main.tf
prod = false
```

The `outputs:` section makes these values available to other jobs via `needs.detect-changes.outputs.dev`.

---

**SECTION 4: The Plan job (dev as example)**

```yaml
tf-dev-plan:
  name: "Dev: Plan"
  needs: detect-changes        # wait for detect-changes to finish
  if: |
    needs.detect-changes.outputs.dev == 'true' ||
    github.event_name == 'schedule' ||
    (github.event_name == 'workflow_dispatch' && github.event.inputs.environment == 'dev')
```

This job runs ONLY if:
- Files in `environments/dev/**` changed, OR
- It's a scheduled drift check, OR
- Someone manually triggered with `environment: dev`

```yaml
  defaults:
    run:
      working-directory: environments/dev   # all steps run from this folder
```

Without `defaults.run.working-directory`, every `run:` step would need `cd environments/dev &&` at the start. This DRYs that up.

```yaml
  steps:
    - uses: actions/checkout@v4       # download the code

    - name: Configure AWS credentials (OIDC)
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
        aws-region: ap-south-1

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: 1.9.8      # pinned version — no surprises from auto-upgrades

    - name: Terraform Format Check
      run: terraform fmt -check -recursive ../../
```

`terraform fmt -check` does NOT modify files. It returns exit code 1 if any file is not formatted. This fails the job and forces the developer to run `terraform fmt` before pushing.

The `../../` means "check formatting in the entire repo, not just environments/dev". That catches formatting issues in `modules/` too.

```yaml
    - name: Terraform Init
      run: terraform init -upgrade
```

`terraform init` downloads the AWS provider plugin and configures the S3 backend.
`-upgrade` updates provider versions if newer ones are available within the `~> 5.0` constraint.

```yaml
    - name: Terraform Plan
      id: plan
      run: |
        terraform plan \
          -no-color \
          -input=false \
          -out=tfplan.binary \
          2>&1 | tee plan.txt
```

- `-no-color` — removes ANSI color codes (they look like garbage in log files)
- `-input=false` — never ask for interactive input (CI is non-interactive)
- `-out=tfplan.binary` — save the plan to a file (used for review)
- `2>&1 | tee plan.txt` — capture both stdout and stderr, save to plan.txt AND show in logs simultaneously

---

**SECTION 5: The Apply job (dev as example)**

```yaml
tf-dev-apply:
  name: "Dev: Apply"
  needs: tf-dev-plan
  if: |
    github.ref == 'refs/heads/main' && github.event_name == 'push' &&
    needs.tf-dev-plan.result == 'success'
```

Three conditions that ALL must be true:
1. We're on the `main` branch (not a feature branch or PR)
2. This is a push event (not a scheduled or manual run — those don't auto-apply)
3. The plan job succeeded

```yaml
  steps:
    - uses: actions/checkout@v4

    - name: Configure AWS credentials (OIDC)
      ...

    - name: Terraform Init
      run: terraform init -upgrade

    - name: Terraform Plan + Apply
      run: |
        terraform plan -out=tfplan.binary -input=false -no-color
        terraform apply -input=false -auto-approve tfplan.binary
```

We do a fresh plan immediately before applying. This avoids the "Saved plan is stale" error that happens when a previous failed run partially modified the state between the plan job and this apply job.

- `-auto-approve` — don't ask "Do you want to apply?" (CI is non-interactive)
- `tfplan.binary` — apply the specific plan we just created (not just any pending changes)

---

## CHAPTER 7: The App CI Pipeline — Explained Line by Line

---

**Q: Now walk me through the app CI pipeline.**

**File:** `techitfactory-app/.github/workflows/ci.yml`

---

**The trigger:**

```yaml
on:
  push:
    branches: [main]
    paths: ['services/**', '.github/workflows/ci.yml']
  pull_request:
    branches: [main]
    paths: ['services/**']
  workflow_dispatch:
```

`paths:` is an additional filter — even on main, the pipeline only runs if someone changed files inside `services/` or the workflow file itself. Changing a README at the root level doesn't trigger it.

---

**The detect-changes job for services:**

```yaml
detect-changes:
  if: |
    github.event_name == 'pull_request' ||
    github.event_name == 'workflow_dispatch' ||
    contains(github.event.head_commit.message, '[deploy]')
  outputs:
    matrix: ${{ steps.set-matrix.outputs.matrix }}
  steps:
    - uses: actions/checkout@v4

    - name: Detect changed services
      uses: dorny/paths-filter@v3
      id: filter
      with:
        filters: |
          api-gateway:
            - 'services/api-gateway/**'
          frontend:
            - 'services/frontend/**'
          user-service:
            - 'services/user-service/**'
          ...

    - name: Build matrix
      id: set-matrix
      run: |
        MATRIX='[]'
        if [ "${{ steps.filter.outputs.api-gateway }}" == "true" ]; then
          MATRIX=$(echo $MATRIX | jq '. += [{"service":"api-gateway","path":"services/api-gateway","type":"node"}]')
        fi
        ...
        echo "matrix=$MATRIX" >> $GITHUB_OUTPUT
```

The output `matrix` is a JSON array of only the services that changed:
```json
[{"service":"api-gateway","path":"services/api-gateway","type":"node"}]
```

If you only changed `api-gateway`, only `api-gateway` goes into the matrix. The other 5 services don't build at all.

---

**The test job with matrix:**

```yaml
test:
  needs: detect-changes
  if: needs.detect-changes.outputs.matrix != '[]'
  strategy:
    matrix:
      include: ${{ fromJson(needs.detect-changes.outputs.matrix) }}
  runs-on: ubuntu-latest

  steps:
    - uses: actions/checkout@v4

    - name: Test (Node.js)
      if: matrix.type == 'node'
      run: |
        cd ${{ matrix.path }}
        npm ci
        npm run lint
        npm test

    - name: Test (Python)
      if: matrix.type == 'python'
      run: |
        cd ${{ matrix.path }}
        pip install -r requirements.txt
        flake8 .
        pytest
```

`strategy.matrix` makes GitHub run this job once per item in the matrix. If `api-gateway` and `frontend` both changed, this job runs twice in parallel — once for each service.

`matrix.type` lets us handle Node.js and Python services differently within the same job definition.

---

**The build job:**

```yaml
build:
  needs: [detect-changes, test]
  if: |
    github.ref == 'refs/heads/main' &&
    github.event_name == 'push' &&
    needs.detect-changes.outputs.matrix != '[]'
  strategy:
    matrix:
      include: ${{ fromJson(needs.detect-changes.outputs.matrix) }}

  steps:
    - uses: actions/checkout@v4

    - name: Configure AWS credentials (OIDC)
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
        aws-region: ap-south-1

    - name: Login to ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v2

    - name: Build and push
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        IMAGE_TAG: ${{ github.sha }}       # e.g., a1b2c3d4e5f6...40chars
      run: |
        docker build -t $ECR_REGISTRY/techitfactory/${{ matrix.service }}:$IMAGE_TAG \
                     -t $ECR_REGISTRY/techitfactory/${{ matrix.service }}:latest \
                     ${{ matrix.path }}
        docker push $ECR_REGISTRY/techitfactory/${{ matrix.service }}:$IMAGE_TAG
        docker push $ECR_REGISTRY/techitfactory/${{ matrix.service }}:latest
```

`github.sha` is the full git commit SHA (40 characters like `a1b2c3d4e5f67890...`). Every image is tagged with the exact commit that produced it. This means you can always trace any running container back to the exact line of code it was built from.

```yaml
    - name: Trivy security scan
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ env.ECR_REGISTRY }}/techitfactory/${{ matrix.service }}:${{ env.IMAGE_TAG }}
        exit-code: 1                    # fail the build if vulnerabilities found
        severity: CRITICAL,HIGH         # only fail on serious issues
        ignore-unfixed: true            # don't fail on CVEs with no available fix
```

Trivy scans the Docker image for known security vulnerabilities (CVEs). It checks:
- The base OS packages (e.g., vulnerable version of OpenSSL)
- Language packages (e.g., a vulnerable npm package)

`ignore-unfixed: true` is practical — if there's a known CVE but no patch exists yet, blocking the build doesn't help you. You can't fix what has no fix.

---

**The update-gitops job:**

```yaml
update-gitops:
  needs: [detect-changes, build]
  if: |
    github.ref == 'refs/heads/main' && github.event_name == 'push'
  strategy:
    matrix:
      include: ${{ fromJson(needs.detect-changes.outputs.matrix) }}
    max-parallel: 1    # ← run ONE service update at a time
```

`max-parallel: 1` is crucial. If `api-gateway` and `frontend` both built successfully, we need to update the gitops repo for both. But if they both try to `git push` at the same time:

```
api-gateway: git push → REJECTED (frontend pushed first)
frontend: git push → success
```

By running them one at a time, each update completes before the next starts.

```yaml
  steps:
    - name: Checkout gitops repo
      uses: actions/checkout@v4
      with:
        repository: YOUR_GITHUB_ORG/techitfactory-gitops
        token: ${{ secrets.GITOPS_TOKEN }}   # PAT with write access to gitops repo
        path: gitops

    - name: Update image tag
      env:
        IMAGE_TAG: ${{ github.sha }}
      run: |
        cd gitops
        yq -i '.images[0].newTag = strenv(IMAGE_TAG)' \
          environments/dev/${{ matrix.service }}/kustomization.yaml

    - name: Commit and push
      run: |
        cd gitops
        git config user.name  "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        git pull --rebase origin main    # absorb any concurrent updates first
        git add environments/dev/${{ matrix.service }}/kustomization.yaml
        git commit -m "chore: update ${{ matrix.service }} → ${{ github.sha }} [dev]"
        git push
```

`git pull --rebase` before `git push` ensures: even if another service updated gitops 2 seconds ago, we incorporate that change before pushing our own. This prevents push rejections.

**Why `yq` not `sed`?**

```bash
# Bad — sed matches ANY line containing "newTag", including comments:
sed -i "s|newTag:.*|newTag: abc123|" kustomization.yaml
# If a comment says "# previous newTag: old-sha", sed breaks the file

# Good — yq navigates YAML structure precisely:
yq -i '.images[0].newTag = strenv(IMAGE_TAG)' kustomization.yaml
# Only modifies exactly .images[0].newTag — nothing else
```

---

## CHAPTER 8: ArgoCD — How It Watches the GitOps Repo and Deploys

---

**Q: After the gitops repo is updated, what happens? Who actually does the deployment?**

**ArgoCD** is a tool running inside the Kubernetes cluster. Its job is:

1. Watch the `techitfactory-gitops` repository on GitHub
2. Every ~3 minutes, check: "Does the cluster state match what's in Git?"
3. If they're different: apply the changes to the cluster

```
techitfactory-gitops
  environments/dev/api-gateway/kustomization.yaml
    images:
      - name: api-gateway
        newTag: a1b2c3d4    ← CI just updated this

ArgoCD sees: cluster is running old-sha, git says a1b2c3d4
ArgoCD: "these are different — syncing..."
ArgoCD runs: kustomize build environments/dev/api-gateway
ArgoCD applies: the rendered Deployment manifest
Kubernetes: rolls out new pod with image api-gateway:a1b2c3d4
Old pod: terminates gracefully
```

This is **GitOps**: Git is the single source of truth for what should be running. ArgoCD enforces it.

---

**Q: What is `selfHeal: true`? Why does it matter?**

```json
{
  "automated": {
    "prune": true,
    "selfHeal": true
  }
}
```

`selfHeal: true` means: if someone manually changes the cluster (e.g., `kubectl edit deployment api-gateway` to bump the replica count to 5), ArgoCD will detect the drift within 3 minutes and revert it back to what Git says (3 replicas).

**Why this matters:**

Without selfHeal, manual changes accumulate silently. Six months later, your cluster looks nothing like your Git repo. When you need to rebuild from scratch (disaster recovery), your "infrastructure as code" is missing all those manual changes.

With selfHeal, the rule is: **the only way to make a permanent change is through a Git commit.** Manual changes don't stick.

---

**Q: What is the App-of-Apps pattern?**

Instead of applying each application's YAML separately, we have one "root" application that manages all the others.

```
root-app.yaml (applied once manually during bootstrap)
  ↓ ArgoCD watches: apps/ directory in gitops repo
  ↓ Creates these ArgoCD Application objects:

  apps/platform/nginx-ingress.yaml       → ArgoCD App: installs NGINX Ingress
  apps/platform/cluster-autoscaler.yaml  → ArgoCD App: installs Cluster Autoscaler
  apps/platform/metrics-server.yaml      → ArgoCD App: installs Metrics Server
  apps/frontend.yaml                     → ArgoCD App: deploys frontend
  apps/api-gateway.yaml                  → ArgoCD App: deploys api-gateway
  apps/services/user-service.yaml        → ArgoCD App: deploys user-service
  ... etc
```

You apply ONE manifest → ArgoCD creates and manages everything. Adding a new service means adding one YAML to `apps/` and committing — ArgoCD picks it up automatically.

---

## CHAPTER 9: Step-by-Step Execution (Exactly What to Do)

---

**Q: Enough theory. Tell me exactly what to click and type, from zero.**

Here is the complete execution sequence. Each step tells you what to do AND what you should see when it works.

---

### STEP 1 — Create the Seed Bucket (Done Once, Manually)

This is the ONLY thing in the entire project that is not automated. It exists to store the bootstrap Terraform state, breaking the chicken-and-egg problem.

```bash
export AWS_PROFILE=techitfactory

aws s3 mb s3://YOUR_BOOTSTRAP_BUCKET --region ap-south-1
aws s3api put-bucket-versioning \
  --bucket YOUR_BOOTSTRAP_BUCKET \
  --versioning-configuration Status=Enabled
```

**What you should see:**
```
make_bucket: YOUR_BOOTSTRAP_BUCKET
```

---

### STEP 2 — Run Bootstrap Terraform Locally (First Time Only)

```bash
cd /home/jai/Desktop/Devops-Project/techitfactory-infra/bootstrap

terraform init
# Expected: "Successfully configured the backend s3"
# Expected: "Terraform has been successfully initialized!"

terraform plan
# Read this output — it shows what will be created:
# + aws_s3_bucket.terraform_state
# + aws_dynamodb_table.terraform_lock
# + aws_kms_key.terraform_state
# + aws_iam_openid_connect_provider.github
# + aws_iam_role.github_actions
# + ...about 11 resources total

terraform apply -auto-approve
```

**Expected output:**
```
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:
state_bucket_name   = "YOUR_TFSTATE_BUCKET"
kms_key_arn         = "arn:aws:kms:ap-south-1:YOUR_AWS_ACCOUNT_ID:key/YOUR_KMS_KEY_ID"
github_actions_role = "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/techitfactory-github-terraform"
```

Note down `state_bucket_name` and `kms_key_arn`.

---

### STEP 3 — Set Up GitHub Secrets (One-Time, In Browser)

**In `techitfactory-infra` repo:**
```
Go to: github.com/YOUR_GITHUB_ORG/techitfactory-infra
→ Settings → Secrets and variables → Actions → New repository secret

Name:  AWS_ROLE_ARN
Value: arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/techitfactory-github-terraform
→ Add secret
```

**Create your GITOPS_TOKEN PAT:**
```
Go to: github.com → top-right profile photo → Settings
→ Developer settings (very bottom of left sidebar)
→ Personal access tokens → Fine-grained tokens → Generate new token

Token name: gitops-writer
Expiration: 90 days
Resource owner: TechITFactory (or your username)
Repository access: Only select repositories → techitfactory-gitops
Permissions → Repository permissions:
  Contents: Read and write

→ Generate token → COPY THIS VALUE (shown only once!)
```

**In `techitfactory-app` repo:**
```
Go to: github.com/YOUR_GITHUB_ORG/techitfactory-app
→ Settings → Secrets and variables → Actions

Add secret 1:
  Name:  AWS_ROLE_ARN
  Value: arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/techitfactory-github-terraform

Add secret 2:
  Name:  GITOPS_TOKEN
  Value: (paste the PAT you just copied)
```

---

### STEP 4 — Set Up GitHub Environments (One-Time, In Browser)

**In `techitfactory-infra` repo:**
```
Settings → Environments → New environment → "dev" → Configure → Save
Settings → Environments → New environment → "bootstrap" → Configure → Save
Settings → Environments → New environment → "production-infra" → Configure
  → Required reviewers → Add yourself → Save protection rules
```

**In `techitfactory-app` repo:**
```
Settings → Environments → New environment → "dev" → Configure → Save
Settings → Environments → New environment → "production" → Configure
  → Required reviewers → Add yourself
  → Deployment branches → Tag matching pattern → v*
  → Save protection rules
```

---

### STEP 5 — Trigger the Infra Pipeline via workflow_dispatch

The dev infrastructure pipeline builds the EKS cluster. We trigger it manually the first time.

```
Go to: github.com/YOUR_GITHUB_ORG/techitfactory-infra
→ Actions tab (top nav)
→ Left sidebar: "Terraform CI/CD"
→ "Run workflow" button (right side, grey button)

In the dropdown:
  environment: dev
  action: apply

→ Click "Run workflow" (green button)
```

**Watch the jobs run (click into the workflow run):**
```
Detect Changed Environments → ✅ (skipped by path filter, but workflow_dispatch overrides)
Dev: Plan → running...
  terraform fmt check → ✅
  terraform init → ✅
  terraform validate → ✅
  terraform plan → ✅ (shows ~40 resources to create)
Dev: Apply → running...
  terraform init → ✅
  terraform plan + apply → running... (this takes ~15 minutes for EKS)
  → ✅ Dev Infrastructure Applied
```

**Wait ~15 minutes, then verify:**
```bash
aws eks update-kubeconfig --name techitfactory-dev \
  --region ap-south-1 --profile techitfactory

kubectl get nodes
```

**If `kubectl get nodes` shows credential errors:**

```
E0313 17:05:29 memcache.go:265] "Unhandled Error" err="couldn't get current
server API group list: the server has asked for the client to provide credentials"
```

This means your local SSO identity is not yet authorized on the cluster.
The cluster was created by the CI pipeline's IAM role — your local user is different.

Fix it by adding your SSO role to the EKS access entries:

```bash
# Step 1: Check which IAM identity your SSO profile resolves to
aws sts get-caller-identity --profile techitfactory
# Note the "Arn" field — it looks like:
# arn:aws:sts::YOUR_AWS_ACCOUNT_ID:assumed-role/AWSReservedSSO_AdministratorAccess_xxxx/jaiadmin

# Step 2: Create an access entry using the ROLE portion of the ARN
# (replace YOUR_SSO_ADMIN_ROLE with your value)
aws eks create-access-entry \
  --cluster-name techitfactory-dev \
  --principal-arn "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/aws-reserved/sso.amazonaws.com/ap-south-1/YOUR_SSO_ADMIN_ROLE" \
  --region ap-south-1 \
  --profile techitfactory

# Step 3: Grant cluster-admin permissions to that role
aws eks associate-access-policy \
  --cluster-name techitfactory-dev \
  --principal-arn "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/aws-reserved/sso.amazonaws.com/ap-south-1/YOUR_SSO_ADMIN_ROLE" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region ap-south-1 \
  --profile techitfactory

# Step 4: Now try again
kubectl get nodes
```

**Why this happens:** When Terraform's CI pipeline creates the EKS cluster, the IAM role
it uses (`techitfactory-github-terraform`) becomes the cluster's implicit admin.
Your local SSO login is a completely separate IAM identity. EKS access entries are
how you grant additional identities access to the cluster. This is a one-time setup.

**Expected after the fix:**
```
NAME                                          STATUS   ROLES    AGE
ip-10-0-1-xxx.ap-south-1.compute.internal   Ready    <none>   5m
ip-10-0-2-xxx.ap-south-1.compute.internal   Ready    <none>   5m
```

---

### STEP 6 — Install ArgoCD via Platform Bootstrap

```
Go to: github.com/YOUR_GITHUB_ORG/techitfactory-infra
→ Actions → "Platform Bootstrap" → "Run workflow"

Inputs:
  environment: dev
  gitops_repo: YOUR_GITHUB_ORG/techitfactory-gitops
  argocd_version: 7.8.14

→ Run workflow
```

**Watch the job:**
```
Step: Configure AWS credentials → ✅
Step: Update kubeconfig → ✅
Step: Add Helm repo → ✅
Step: Install ArgoCD → ✅ (helm upgrade --install argocd)
Step: Configure gitops credentials → ✅
Step: Apply root-app → ✅
Step: Wait for ArgoCD → ✅
Step: Print access info → ✅
  Admin password: (shown in logs)
```

**Access ArgoCD:**
```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port-forward to localhost
kubectl port-forward svc/argocd-server -n argocd 8080:80

# Open browser: http://localhost:8080  (NOT https — ArgoCD runs in insecure/HTTP mode)
# Username: admin
# Password: (from above)
```

**In ArgoCD UI, you should see:**
```
root-app           ● Synced   ✓ Healthy
nginx-ingress      ● Synced   ✓ Healthy
cluster-autoscaler ● Synced   ✓ Healthy
metrics-server     ● Synced   ✓ Healthy
frontend           ○ OutOfSync  (normal — no image built yet)
api-gateway        ○ OutOfSync  (normal)
... etc
```

The service apps show OutOfSync because we haven't built the Docker images yet. That's expected.

**If pods show `CreateContainerConfigError: secret "app-secrets" not found`:**

The platform bootstrap creates this secret automatically (step 7b). But if you're on an
older bootstrap run that didn't have this step, create it manually:

```bash
kubectl create secret generic app-secrets \
  --from-literal=jwt-secret="$(openssl rand -base64 32)" \
  -n techitfactory
```

This creates the JWT signing key used by `api-gateway` and `user-service`.
The pods will start automatically within 30 seconds.

**Why not store this in Git?** Secrets must never be committed to a git repository.
They are generated at bootstrap time and live only inside the cluster.

---

### STEP 7 — Build All 6 Service Images (First-Time Seed)

```
Go to: github.com/YOUR_GITHUB_ORG/techitfactory-app
→ Actions → "Build All Services" → "Run workflow"

Inputs:
  environment: dev
  (leave image_tag blank — uses git SHA automatically)

→ Run workflow
```

**Watch the jobs (~10-15 minutes):**
```
Build frontend       → docker build → ECR push → Trivy scan → ✅
Build api-gateway    → docker build → ECR push → Trivy scan → ✅
Build user-service   → docker build → ECR push → Trivy scan → ✅
Build order-service  → docker build → ECR push → Trivy scan → ✅
Build product-service → docker build → ECR push → Trivy scan → ✅
Build cart-service   → docker build → ECR push → Trivy scan → ✅
  (all 6 run in parallel)

Update GitOps: frontend    → commit to techitfactory-gitops → ✅
Update GitOps: api-gateway → commit → ✅
... (one at a time)
```

**Verify:**
```bash
# Check ECR has images
aws ecr list-images \
  --repository-name techitfactory/frontend \
  --region ap-south-1 \
  --query 'imageIds[*].imageTag' \
  --output table

# Check gitops was updated
cd /home/jai/Desktop/Devops-Project/techitfactory-gitops
git pull
git log --oneline -6
# Should show 6 commits from github-actions[bot]

grep newTag environments/dev/frontend/kustomization.yaml
# newTag: (a real 40-char git SHA)
```

**Go back to ArgoCD UI** — within 3 minutes you should see:
```
frontend           ● Synced   ✓ Healthy
api-gateway        ● Synced   ✓ Healthy
user-service       ● Synced   ✓ Healthy
order-service      ● Synced   ✓ Healthy
product-service    ● Synced   ✓ Healthy
cart-service       ● Synced   ✓ Healthy
```

**Verify pods are running:**
```bash
kubectl get pods -n techitfactory
```

Expected:
```
NAME                               READY   STATUS    RESTARTS
frontend-6d4f9b-xxx                1/1     Running   0
api-gateway-7c8d5f-xxx             1/1     Running   0
user-service-5b9e4c-xxx            1/1     Running   0
order-service-8a3b2d-xxx           1/1     Running   0
product-service-4e7f1a-xxx         1/1     Running   0
cart-service-9d2c8e-xxx            1/1     Running   0
```

**Get the NLB URL:**
```bash
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""

# e.g.: abc123def.elb.ap-south-1.amazonaws.com
```

Open that URL in a browser → you should see the frontend.

---

### STEP 8 — Demonstrate the Full Automated Loop (The Showcase)

This is the demo moment. Make a code change and watch it go from commit to live pod automatically.

```bash
cd /home/jai/Desktop/Devops-Project/techitfactory-app

# Find a visible text in the frontend and change it
# This makes the change obvious in the browser after deploy
grep -rn "TechIT\|Welcome\|title\|heading" services/frontend/src/ | head -10
# Pick a line — change something like "TechIT Factory" to "TechIT Factory v2 🚀"

# Or a safe guaranteed-visible change: update the page title in index.html
# (adjust path based on your frontend structure)
ls services/frontend/

git add services/frontend/
git commit -m "demo: update frontend title for sprint5 CI/CD showcase [deploy]"
git push origin main
```

**Open these four things simultaneously:**

Window 1 — GitHub Actions:
```
github.com/YOUR_GITHUB_ORG/techitfactory-app → Actions
Watch the workflow run in real time
```

Window 2 — ArgoCD UI:
```
https://localhost:8080
Watch api-gateway app status
```

Window 3 — Watch pods:
```bash
watch kubectl get pods -n techitfactory -l app=api-gateway
```

Window 4 — Watch gitops:
```bash
watch -n5 "cd /home/jai/Desktop/Devops-Project/techitfactory-gitops && git pull -q && grep newTag environments/dev/api-gateway/kustomization.yaml"
```

**Timeline of what you'll see:**
```
t=0:00  You pushed the commit
t=0:20  GitHub Actions: workflow starts, "Detect Changes" job begins
t=0:40  api-gateway = true, matrix built
t=1:00  "Test api-gateway" job starts → npm test
t=1:30  Tests pass ✅
t=2:00  "Build api-gateway" starts → docker build
t=3:30  ECR push complete, Trivy scan starts
t=4:00  Trivy passes ✅
t=4:30  "Update GitOps" starts → yq update → git commit + push
t=5:00  Window 4: newTag changes to new SHA!
t=5:30  Window 2: ArgoCD shows "Syncing..."
t=6:00  Window 3: new pod starts (STATUS: ContainerCreating)
t=6:30  Window 3: new pod Running, old pod Terminating
t=7:00  Window 2: ArgoCD shows "Synced ✓ Healthy"
```

Zero manual steps after the git push.

---

## CHAPTER 10: Common Questions

---

**Q: What if the pipeline fails? Does it break the running application?**

No. For the app pipeline: if any step fails (test, build, scan, or gitops update), the running application is untouched. The old pods keep serving traffic. Nothing is deployed until everything passes.

For Terraform: if apply partially fails, the successfully created resources remain and Terraform state reflects them. The next run picks up from the current state.

---

**Q: How do I roll back a bad deployment?**

```bash
# Option A: ArgoCD rollback (fastest — immediate)
argocd app rollback api-gateway
# Redeploys the previous image tag from ArgoCD history

# Option B: Git revert (recommended — keeps audit trail)
cd /home/jai/Desktop/Devops-Project/techitfactory-gitops
git log environments/dev/api-gateway/      # find the bad commit
git revert HEAD                             # creates a new commit that undoes it
git push
# ArgoCD detects the revert and deploys old image within 3 minutes
```

---

**Q: What happens if I push to main without `[deploy]` in the message?**

```
detect-changes job:
  checks: github.event.head_commit.message
  contains '[deploy]'? → NO
  github.event_name == 'pull_request'? → NO (this is a push)
  github.event_name == 'workflow_dispatch'? → NO
  github.event_name == 'schedule'? → NO
  Result: if condition is FALSE

detect-changes job: SKIPPED
All downstream jobs (test, build, apply): SKIPPED because detect-changes was skipped

Final result: nothing happens
```

---

**Q: The pipeline says "No changes detected" and skips. Why?**

The `dorny/paths-filter` action compares your commit to the previous commit. If only the workflow YAML changed (not any Terraform files or service files), all filters return `false` and the plan/apply jobs are skipped.

**Fix:** Use `workflow_dispatch` (manual trigger) to force a run regardless of changed files:
```
GitHub → repo → Actions → [workflow name] → Run workflow
```

---

**Q: Can two developers trigger the pipeline at the same time?**

For Terraform:
```yaml
concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: false
```
The second run waits for the first to complete. They never run in parallel (state locking would cause one to fail anyway).

For the app CI pipeline:
Two separate pushes can trigger two pipeline runs. They build in parallel safely because ECR accepts multiple pushes. The `update-gitops` job's `max-parallel: 1` + `git pull --rebase` ensures the gitops commits are serialized correctly.

---

**Q: What is the NLB vs ALB thing?**

AWS ALB (Application Load Balancer) via the ALB Ingress Controller requires special IAM permissions (`elasticloadbalancing:CreateLoadBalancer`, etc.) that are restricted in this AWS account.

NGINX Ingress Controller is the standard alternative:
- Runs as a pod inside the cluster
- Creates an NLB (Network Load Balancer) automatically using Kubernetes' built-in cloud controller
- NLB → NGINX pod → routes traffic to services based on URL path rules
- Uses `ingressClassName: nginx` in Ingress manifests

Same result for the application. Different AWS resource underneath.

---

**Q: Where is the application accessible?**

```bash
# Get the NLB DNS name
# NOTE: service name has the Helm release name as prefix: nginx-ingress-ingress-nginx-controller
kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""

# Or just list all services to see the exact name
kubectl get svc -n ingress-nginx
```

The ingress rules (in `techitfactory-gitops/environments/dev/ingress.yaml`):
```
http://<NLB>/       → frontend service (port 80)
http://<NLB>/api    → api-gateway service (port 80)
```

---

## Troubleshooting Quick Reference

| Error | Cause | Fix |
|---|---|---|
| `No valid credential sources found` | AWS SSO token expired | `aws sso login --profile techitfactory` |
| `the server has asked for the client to provide credentials` | Your SSO role not in EKS access entries | Run `aws eks create-access-entry` + `associate-access-policy` (see STEP 5) |
| `Error: Saved plan is stale` | Re-ran old job from before the fix | Use "Run workflow" button, not "Re-run job" |
| `ImagePullBackOff` | ECR image doesn't exist | Check ECR for the image tag in `kustomization.yaml` |
| `CreateContainerConfigError: secret "app-secrets" not found` | JWT secret not created during bootstrap | Run: `kubectl create secret generic app-secrets --from-literal=jwt-secret="$(openssl rand -base64 32)" -n techitfactory` |
| `CrashLoopBackOff` | App crashing at startup | `kubectl logs <pod-name> -n techitfactory` |
| `Pending` (pod) | Not enough cluster resources | Wait for cluster autoscaler (2-3 min) |
| Pipeline skips all jobs | No `[deploy]` in commit message | Use `workflow_dispatch` or add `[deploy]` to commit |
| `git push rejected` in update-gitops | Rebase conflict | Re-run the failed job (rebase succeeds on retry) |
| ArgoCD `SyncFailed` | Invalid YAML in gitops | `kustomize build environments/dev/<app>` locally to debug |
| NLB stuck `<pending>` | Node IAM missing ELB permissions | Check node role has `elasticloadbalancing:*` |
