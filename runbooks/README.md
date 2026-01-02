# Runbooks

Executable step-by-step guides for each Sprint and Story.

## Structure

```
runbooks/
├── sprint1/           # Foundation & Infrastructure
│   ├── S1.1_CREATE_3_REPOS.md
│   ├── S1.2_TRUNK_BASED_DEV.md
│   ├── S2.1_TERRAFORM_BOOTSTRAP.md
│   ├── S2.2_GITHUB_OIDC.md
│   └── S3.1_VPC_NETWORKING.md
├── sprint2/           # Platform Setup
├── sprint3/           # GitOps & Observability
├── sprint4/           # Application
├── sprint5/           # CI/CD
└── sprint6/           # Automation
```

## How to Use

1. Open the runbook for your current story
2. Execute commands in order
3. Check completion checklist at the end
4. Commit your work
5. Move to next story

## Naming Convention

`S{Epic}.{Story}_{SHORT_NAME}.md`

Example: `S1.1_CREATE_3_REPOS.md` = Epic 1, Story 1
