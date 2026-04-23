# AWS Cost-Conscious MVP vs Production

## Purpose
This document compares two AWS operating modes for the IPSSA platform:

- a **cost-conscious MVP footprint**
- a **fuller resilient production footprint**

It is meant to help decide what to deploy first on AWS without overbuilding too early, while still preserving a path to a robust long-term architecture.

This document complements:

- `docs/architecture/IPSSA_AWS_Architecture.md`
- `docs/infrastructure/AWS_Environments_and_IaC_Strategy.md`

---

## Executive Recommendation

### Recommended path

#### Stage 1: Proof of concept
- keep web on Vercel
- keep APIs on Railway if speed is the priority
- use PostgreSQL and S3-compatible storage patterns from day one

#### Stage 2: Cost-conscious AWS MVP
- move to AWS with simpler, lower-cost defaults
- keep service boundaries intact
- avoid expensive high-availability features where business risk does not yet justify them

#### Stage 3: Production-grade AWS
- upgrade to stronger redundancy, Multi-AZ data services, broader observability, and tighter operational controls

This path gives the team:
- fast initial delivery
- lower burn in the early phase
- a clean migration path
- no major rewrite when the platform needs stronger resilience

---

## Two AWS Modes

## Mode A: Cost-Conscious AWS MVP

This is the smallest AWS footprint that still preserves the intended architecture shape.

### Suggested components
- Route 53
- CloudFront
- S3 for web assets
- ALB
- ECS Fargate
- ECR
- RDS PostgreSQL
- S3 for media
- SQS for a small number of async workflows
- CloudWatch basic logs and alarms
- Secrets Manager / Parameter Store

### What is intentionally lighter
- fewer ECS tasks
- fewer alarms
- no Redis on day one unless clearly needed
- RDS PostgreSQL instead of Aurora if cost sensitivity is high
- 2 AZs instead of 3 if cost must be controlled
- simpler staging footprint

---

## Mode B: Production-Grade AWS

This is the more resilient target for when real uptime, failover, and growth pressures justify the spend.

### Suggested components
- Route 53
- WAF
- CloudFront
- S3 for web assets
- ALB
- ECS Fargate with autoscaling across multiple AZs
- ECR
- Aurora PostgreSQL or RDS Multi-AZ with stronger failover posture
- ElastiCache Redis Multi-AZ
- S3 with stronger lifecycle and optional cross-region strategies
- SQS with DLQs and worker services
- CloudWatch dashboards, alarms, and stronger observability
- Secrets Manager / Parameter Store
- KMS

### What is stronger here
- more redundancy
- more fault isolation
- better failover
- more operational visibility
- better scaling posture under load

---

## Side-by-Side Comparison

| Area | Cost-Conscious AWS MVP | Production-Grade AWS |
|---|---|---|
| AZ strategy | 2 AZs acceptable | 3 AZs preferred |
| Web hosting | S3 + CloudFront | S3 + CloudFront |
| API runtime | ECS Fargate, smaller tasks | ECS Fargate, autoscaled and multi-AZ hardened |
| Gateway | Single ALB + gateway service | Same, with stronger alarm coverage and stricter protections |
| Database | RDS PostgreSQL, preferably Multi-AZ if budget allows | Aurora PostgreSQL or stronger RDS Multi-AZ posture |
| Cache | Skip initially unless needed | ElastiCache Redis Multi-AZ |
| Async jobs | Basic SQS use | SQS + DLQs + separate worker scaling |
| Media | S3 | S3 with more advanced lifecycle/DR options |
| Security edge | TLS + core protections | TLS + WAF + stricter policies |
| Observability | Logs + essential alarms | Full dashboards, alerts, tracing, runbooks |
| DR posture | Restore-oriented | Stronger failover + stronger restore posture |

---

## Recommended MVP AWS Footprint

If the team wants the most practical first AWS deployment, use this:

## Web
- `codebase/uis/frontend/` built and deployed to S3
- CloudFront in front

## APIs
- `codebase/apis/gateway/` on ECS Fargate
- `codebase/apis/auth-api/` on ECS Fargate
- `codebase/apis/core-api/` on ECS Fargate
- `codebase/apis/media-api/` on ECS Fargate

### Task count
Early MVP can begin with:
- 1 task per service in lower environments
- 2 tasks for the most critical services in production-facing MVP if budget allows

If cost pressure is high:
- start with 1 task per service in production for a very early pilot
- but recognize this weakens fault tolerance materially

## Database
Preferred MVP database choice:
- `RDS PostgreSQL Multi-AZ` if budget allows

Cheaper fallback:
- single-instance `RDS PostgreSQL`

Important note:
- single-instance RDS lowers cost, but it is a clear single point of failure
- this is acceptable only for very early pilot phases with explicit business sign-off

## Media
- S3 for uploads and proof photos
- direct uploads via signed URLs where possible

## Async
- SQS for notifications and cleanup jobs

## Security/config
- ACM
- Secrets Manager
- Parameter Store
- IAM task roles

## Observability
Minimum acceptable:
- CloudWatch logs for every service
- ALB 5xx alarm
- ECS unhealthy task alarm
- database CPU/storage alarm
- queue backlog alarm if SQS is in use

---

## What to Avoid in the MVP

To stay cost-conscious, avoid these unless there is a concrete need:

- EKS
- multi-region DR
- Redis before performance or product needs justify it
- overly complex service meshes
- advanced event-driven sprawl before the basic system is stable
- separate worker fleet for every small async job
- overprovisioned staging that sits mostly idle

These are classic ways to spend too much too early.

---

## Production Upgrade Path

When the platform moves from pilot to true production expectations, upgrade in this order:

## 1. Database resilience first
- move from single-instance RDS to Multi-AZ if not already there
- move from basic RDS to Aurora PostgreSQL if scale/failover/read patterns justify it

## 2. Compute resilience
- ensure at least 2 tasks per critical service
- spread across multiple AZs
- tune autoscaling thresholds

## 3. Edge hardening
- add WAF
- strengthen rate limiting
- review TLS, headers, and edge policies

## 4. Async and cache hardening
- add Redis if query patterns or coordination needs justify it
- split worker workloads if queue depth increases
- add DLQs and runbooks

## 5. Observability maturity
- dashboards for business and infrastructure KPIs
- traceability across gateway, auth, core, and media APIs
- documented incident playbooks

## 6. Disaster recovery maturity
- stronger restore testing
- optional cross-region replication strategies

---

## Cost-Saving Decisions That Are Usually Safe Early

These are generally reasonable early-stage cost optimizations:

- keep the web layer static on S3 + CloudFront
- avoid Redis until data proves it is needed
- keep staging smaller than production
- use ECS Fargate without overprovisioned baseline tasks
- use RDS PostgreSQL before Aurora if database load is still modest
- keep 2 AZs before moving to 3 AZs if budget is constrained
- centralize logs in CloudWatch before adding extra tooling

---

## Cost-Saving Decisions That Create Meaningful Risk

These are cost cuts that materially increase platform fragility:

- only one ECS task for every critical service in production
- single-instance database for a real production workload
- no queueing for slow or bursty async jobs
- no alarms on ALB, ECS, and database health
- serving private media through ad hoc application endpoints instead of durable storage patterns
- no backup restore testing

These should be treated as conscious business risks, not invisible technical shortcuts.

---

## Practical Decision Matrix

## If the platform is in closed pilot
Use:
- Vercel/Railway or a minimal AWS MVP
- lower spend
- faster iteration

## If real chapters depend on the service operationally
Use:
- AWS MVP with stronger defaults
- at minimum:
  - ALB
  - ECS
  - Multi-AZ database if possible
  - S3
  - alarms

## If the platform becomes business-critical
Use:
- full production-grade AWS design
- multi-AZ compute and data
- stronger monitoring
- WAF
- improved DR posture

---

## Cost-Conscious Recommendation by Layer

## Web layer
Recommendation:
- keep this cheap and simple
- S3 + CloudFront is the right answer in both MVP and production

## API layer
Recommendation:
- use ECS Fargate in both MVP and production
- change scale settings, not platforms

This avoids a later migration from one compute model to another.

## Database layer
Recommendation:
- if budget allows, start with Multi-AZ RDS PostgreSQL
- if not, use single-instance RDS only as a temporary step
- move to Aurora later if performance/read/failover requirements justify it

## Media layer
Recommendation:
- use S3 immediately
- do not postpone this behind local disk or ad hoc file storage

## Async layer
Recommendation:
- use SQS early for anything bursty or non-blocking
- this is usually worth the cost because it reduces operational pain

---

## Suggested Triggers for Upgrading from MVP to Production Mode

Move from cost-conscious AWS to stronger production posture when any of these become true:

- multiple chapters rely on the platform daily
- downtime would directly harm customer retention or route protection
- media upload volume increases meaningfully
- queue depth or API latency becomes spiky
- the team starts doing regular releases and needs safer rollouts
- support burden grows because observability is too weak
- the business begins making uptime promises

---

## Recommended Baselines

## Best early AWS baseline
If you skip Railway/Vercel and go straight to AWS with cost in mind, this is the recommended baseline:

- Route 53
- CloudFront
- S3 for web
- ALB
- ECS Fargate
- ECR
- RDS PostgreSQL
- S3 for media
- SQS
- CloudWatch
- Secrets Manager
- Parameter Store

This gives you:
- the right architecture shape
- manageable cost
- good upgrade path

## Best long-term production baseline
- Route 53
- WAF
- CloudFront
- S3 for web and media
- ALB
- ECS Fargate
- Aurora PostgreSQL
- ElastiCache Redis
- SQS
- CloudWatch
- Secrets Manager
- Parameter Store
- KMS

This gives you:
- strong availability
- good horizontal scaling
- better operational resilience

---

## Final Recommendation

The best practical strategy is:

1. Move fast with Railway/Vercel if needed for PoC speed.
2. Preserve service boundaries, PostgreSQL, S3-style storage, and structured observability from the start.
3. Move to a cost-conscious AWS MVP that already uses:
   - ECS Fargate
   - ALB
   - RDS PostgreSQL
   - S3
   - SQS
4. Upgrade to stronger production posture by improving redundancy and operations, not by replacing the whole platform stack.

That path controls cost without painting the platform into a corner.
