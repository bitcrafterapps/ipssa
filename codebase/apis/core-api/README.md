# Core API

This folder is reserved for the primary business domain service.

Intended responsibilities:

- chapters, memberships, and roles
- member business profiles
- CoverageMatch requests, matching, and dossier workflows
- ratings, reputation, and gamification
- chapter community features
- Prep Lab content, progress, and related orchestration
- notification intent orchestration

This is expected to become the largest backend service in the platform.

Relevant references:

- `../../../docs/architecture/IPSSA_Data_Schema.md`
- `../../../docs/architecture/IPSSA_SQL_First_Schema_Spec.md`
- `../../../docs/architecture/migrations/004_core_foundation.sql`
- `../../../docs/architecture/migrations/005_media_and_coverage.sql`
- `../../../docs/architecture/migrations/006_community_learning_and_ops.sql`
