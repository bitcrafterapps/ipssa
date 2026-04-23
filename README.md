# IPSSA Platform

This repository contains the planning and implementation artifacts for the IPSSA platform: a native-mobile-first member experience backed by multiple APIs and a limited web presence for marketing, BD, and selected member workflows.

## Current Structure

```text
.
├── .gitignore
├── PRODUCT_OVERVIEW.md
├── README.md
├── codebase/
│   ├── README.md
│   ├── apis/
│   └── uis/
├── docs/
│   ├── README.md
│   ├── architecture/
│   ├── infrastructure/
│   ├── planning/
│   └── product/
```

## Repository Areas

- `docs/`
  Product, architecture, infrastructure, and planning documents.

- `codebase/`
  Container for application code, including backend APIs and all user interfaces.

- `codebase/apis/`
  Placeholder directory for the backend APIs. This is where the gateway, auth API, core API, and media API will be created.

- `codebase/uis/`
  Container for all client-facing user interfaces.

- `codebase/uis/frontend/`
  Web experience for marketing, BD/lead capture, and a limited member portal.

- `codebase/uis/ios/`
  Native iOS application. This folder is intentionally present before the Xcode project is added.

- `codebase/uis/android/`
  Native Android application. This folder is intentionally present before the Android Studio project is added.

## Key Documents

- `PRODUCT_OVERVIEW.md`
  Root-level summary of the platform's major functionality and product areas.

- `docs/product/IPSSA_Mobile_App_Opportunity.md`
  Product opportunity brief, feature definition, and strategic framing.

- `docs/planning/IPSSA_Implementation_Stories_Backlog.md`
  Build-ready stories backlog with service ownership, dependencies, and delivery waves.

- `docs/architecture/IPSSA_AWS_Architecture.md`
  Target AWS production architecture for redundancy, scalability, and fault tolerance.

- `docs/infrastructure/AWS_Environments_and_IaC_Strategy.md`
  AWS environments, account strategy, and infrastructure-as-code approach.

- `docs/infrastructure/AWS_Cost_Conscious_MVP_vs_Production.md`
  Cost-conscious hosting progression from MVP to stronger production posture.

## Intended Platform Shape

- Native iOS app
- Native Android app
- Web frontend for marketing/BD and limited portal features
- Backend APIs under `codebase/apis/`:
  - API gateway
  - Auth API
  - Core API
  - Media API

## Notes

- The native app projects are expected to be created in Xcode and Android Studio first, then added into `codebase/uis/ios/` and `codebase/uis/android/`.
- The backend services will be created under `codebase/apis/` as implementation begins.
- This repository is currently planning-first and code-light. The docs in `docs/` should be treated as the source of truth for initial implementation sequencing.
