# AWS Environments and IaC Strategy

## Purpose
This document defines how the IPSSA platform should be organized across AWS environments and how infrastructure should be managed as code.

It complements:

- `docs/architecture/IPSSA_AWS_Architecture.md`
- `docs/planning/IPSSA_Implementation_Stories_Backlog.md`

The goals are:

- predictable environments
- low operational drift
- safe promotions from lower to higher environments
- reproducible infrastructure
- clear separation between proof of concept, staging, and production

---

## Guiding Principles

- Infrastructure must be created and changed through code, not manual console work.
- Production must be isolated from lower environments.
- Staging should resemble production closely enough to validate deployments and failure behavior.
- Environment differences should be intentional and documented, not accidental.
- Secrets, configuration, networking, and deployment pipelines should be standardized early.

---

## Recommended Environment Model

## Local
Purpose:
- day-to-day developer work
- service contract testing
- UI/API integration during feature development

Characteristics:
- local web app
- local API services when practical
- optional shared cloud dependencies for S3/Postgres-compatible testing
- lowest cost, lowest fidelity

Use for:
- fast iteration
- debugging
- contract development

Do not use for:
- production-like performance testing
- release confidence
- failover validation

---

## Dev
Purpose:
- shared integration environment for active feature development
- backend and client integration against hosted services

Characteristics:
- lower-cost AWS footprint
- looser uptime expectations
- may allow more frequent changes and resets
- useful for internal demos and QA collaboration

Use for:
- validating service integration
- mobile app integration against stable endpoints
- early background-job and media workflow checks

Recommendation:
- if budget is tight, `dev` and `staging` can temporarily collapse into one environment
- if the team grows, split them as soon as release cadence increases

---

## Staging
Purpose:
- pre-production validation
- release testing
- migration rehearsal
- operational testing

Characteristics:
- mirrors production architecture as closely as practical
- separate data and secrets
- production-like networking and service boundaries
- smaller scale than production, but same topology shape

Use for:
- deployment rehearsals
- auth and gateway validation
- mobile release candidate testing
- backup/restore and failure drills

Staging should be close enough to production to validate:
- ECS task deployment behavior
- ALB routing
- database migrations
- queue processing
- signed media access
- alarms and observability

---

## Production
Purpose:
- serve real users and real business workflows

Characteristics:
- highest availability and durability
- strict access controls
- change management discipline
- multi-AZ architecture
- monitored and backed up continuously

Production requirements:
- no ad hoc manual edits
- strong approval process for infra and schema changes
- auditable secrets and access paths
- tested rollback and recovery procedures

---

## Recommended AWS Account Strategy

## Preferred model
Use separate AWS accounts for:

- `shared-services` (optional, later)
- `dev`
- `staging`
- `production`

### Why separate accounts
- strongest blast-radius reduction
- clearer IAM boundaries
- easier cost attribution
- reduced risk of accidental production edits

## Early-stage compromise
If the team is very small and cost/ops overhead must stay minimal:

- one AWS account for `dev` and `staging`
- one separate AWS account for `production`

Avoid putting production in the same account as every lower environment for long.

---

## Region Strategy

## Recommended initial region model
- single primary AWS region
- multi-AZ within that region

This is the right default for early production.

## Region selection considerations
Choose a region based on:
- proximity to likely user base
- service availability
- data residency expectations
- team familiarity

Common candidates:
- `us-east-1`
- `us-west-2`

## Future regional expansion
Add multi-region only when justified by:
- formal disaster recovery requirements
- contractual uptime expectations
- major geographic latency needs

---

## VPC Strategy by Environment

Each hosted environment should have its own VPC.

### Dev VPC
- smaller CIDR
- lower-cost footprint
- optional relaxed redundancy compared to production

### Staging VPC
- same subnet model as production
- same routing/security model as production where possible

### Production VPC
- public subnets for ALB and NAT
- private application subnets for ECS
- private data subnets for RDS/Redis
- at least 2 AZs, ideally 3

Do not share a single VPC across unrelated environments.

---

## Infrastructure as Code Recommendation

## Recommended tool
Use **Terraform** as the default IaC tool.

### Why Terraform is the best default here
- widely understood
- strong AWS ecosystem support
- easy to reason about in a small team
- works well across accounts and environments
- produces reviewable plans

## Viable alternative
AWS CDK is also reasonable if the team strongly prefers TypeScript-driven infrastructure definitions.

## Recommendation
Unless there is a strong existing CDK preference, choose:

- Terraform for infrastructure
- application code separately in the service repos/folders

The important decision is less the exact tool and more the discipline:
- no manual drift
- versioned changes
- environment-specific state isolation

---

## Terraform Structure Recommendation

## Folder model
Recommended structure under a future infra area:

```text
infra/
├── modules/
│   ├── network/
│   ├── ecs-service/
│   ├── alb/
│   ├── rds/
│   ├── redis/
│   ├── s3-bucket/
│   ├── sqs/
│   └── observability/
└── environments/
    ├── dev/
    ├── staging/
    └── production/
```

## Module principles
- modules should be composable and small
- avoid one giant module for the entire stack
- keep environment-specific values in environment layers, not hardcoded in modules

---

## State Management

## Recommended Terraform state backend
- S3 for remote state storage
- DynamoDB for state locking

## State rules
- separate state per environment
- strongly restricted access to production state
- no local state files committed to git

## State boundary recommendation
Split state by concern when complexity grows:
- network
- shared platform services
- application services
- data layer

This keeps plans smaller and reduces blast radius.

---

## Naming, Tagging, and Resource Conventions

Every resource should have standardized tags:

- `Project=ipssa`
- `Environment=dev|staging|production`
- `Owner=<team-or-person>`
- `ManagedBy=terraform`
- `Service=<gateway|auth-api|core-api|media-api|frontend>`
- `CostCenter=<optional>`

## Naming conventions
Use clear, environment-prefixed resource naming, for example:

- `ipssa-prod-alb`
- `ipssa-staging-core-api`
- `ipssa-dev-media-bucket`

This improves:
- cost visibility
- debugging
- operational clarity

---

## Secrets and Configuration Strategy

## Secrets
Store in:
- AWS Secrets Manager

Examples:
- database credentials
- signing keys
- third-party API secrets
- notification provider credentials

## Non-secret config
Store in:
- SSM Parameter Store

Examples:
- feature flags with low sensitivity
- service URLs
- environment-level numeric thresholds
- retention settings

## Rules
- never hardcode secrets into Terraform variables files committed to git
- never keep production secrets only in CI settings with no documented source of truth
- rotate secrets on a scheduled basis when feasible

---

## CI/CD and Promotion Strategy

## Build pipeline responsibilities
CI should:
- lint and typecheck
- run tests
- scan dependencies
- build artifacts
- build container images
- publish versioned images to ECR

## Deployment pipeline responsibilities
CD should:
- deploy infrastructure changes through IaC workflows
- deploy service updates separately from infra when possible
- support staged promotions:
  - dev
  - staging
  - production

## Promotion model

### Recommended
- merge to main can deploy automatically to `dev`
- promotion to `staging` should be intentional
- promotion to `production` should require approval

### Production guardrails
- approval gate
- migration plan reviewed
- rollback strategy known before rollout
- alarms observed during deployment

---

## Deployment Strategy by Layer

## Web frontend
- static assets built in CI
- stored in S3
- served via CloudFront
- invalidate cache only when needed

## APIs
- build Docker images
- push to ECR
- deploy to ECS services
- use rolling deployment or blue/green patterns where warranted

## Database migrations
- migrations must be versioned
- staging migrations run before production
- backward compatibility should be favored when possible
- production schema changes should have rollback or mitigation plans

---

## Environment Differences That Should Exist

These differences are acceptable and expected:

### Dev
- smaller instance/task counts
- lower database size
- less aggressive retention
- reduced alarms

### Staging
- lower scale than prod
- same service boundaries
- similar routing, auth, and media behavior

### Production
- multi-AZ
- stronger alarms
- stricter IAM and access review
- longer backups and retention

## Differences that should not exist
- different auth model
- different gateway behavior
- different service boundaries
- missing queues in staging if prod depends on them
- radically different media access patterns

---

## Access Control Model

## Human access
Use IAM Identity Center or an equivalent centralized access model where possible.

Principles:
- least privilege
- separate admin access from day-to-day developer access
- production access should be narrower and more audited

## Machine access
Use:
- IAM roles for ECS tasks
- short-lived credentials where possible

Avoid:
- long-lived shared access keys
- credentials embedded in containers

---

## Observability by Environment

## Dev
- enough logs to debug quickly
- lower-cost retention

## Staging
- logs, metrics, and alarms should look like prod
- ideal place to validate dashboards and alert thresholds

## Production
- full business and infrastructure telemetry
- clear alert ownership
- runbooks linked to alarms

---

## Backup and Recovery by Environment

## Dev
- minimal backups if cost constrained
- not a business continuity environment

## Staging
- enough backup discipline to test restore procedures

## Production
- automated DB backups
- point-in-time recovery
- tested restore drills
- documented RTO/RPO targets

---

## Recommended Delivery Sequence

### Step 1
Create:
- `dev` environment foundations
- Terraform backend/state layout
- basic network and shared modules

### Step 2
Deploy:
- ALB
- ECS cluster/services
- ECR repos
- S3 buckets
- Secrets Manager/Parameter Store structure

### Step 3
Add:
- staging environment
- database and media workflows
- observability baseline

### Step 4
Promote:
- production environment
- production alarms
- production backup/recovery policies

### Step 5
Refine:
- cost optimization
- security hardening
- DR posture

---

## Recommended Initial Decisions

If the team wants a concrete baseline, use:

- Terraform
- one AWS account for `dev/staging` initially, one separate account for `production`
- one primary AWS region
- separate VPC per hosted environment
- ECS Fargate for services
- Aurora PostgreSQL or RDS PostgreSQL Multi-AZ
- S3 + CloudFront for web
- S3 + pre-signed URLs for media
- SQS for async jobs
- CloudWatch for logs/metrics/alarms
- Secrets Manager + Parameter Store for config management

This is the best balance of rigor, cost control, and operational realism for the current stage of the platform.
