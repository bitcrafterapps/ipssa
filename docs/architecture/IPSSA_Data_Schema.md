# IPSSA Data Schema
## Purpose

This document defines the logical data schema for the IPSSA platform across the Auth API, Core API, and Media API.

It covers:

- primary domain objects
- object variants and enums
- field names and types
- validation and integrity rules
- relationships
- ownership boundaries between services

This is a logical schema document, not final SQL DDL. It is intended to guide API contracts, migrations, and implementation sequencing.

---

## Design Principles

- Primary system of record: `PostgreSQL`
- File/blob storage: `S3` or equivalent object storage
- IDs: `uuid`
- Timestamps: `timestamptz`
- Money-like and weighted scores: `numeric`
- Freeform extension data: `jsonb`
- Email values: `citext` where supported, otherwise normalized `text`
- All important state transitions should be auditable
- Avoid cross-service database writes; use API/event boundaries between services
- Use database constraints for validity where possible, and application validation for workflow-specific rules

---

## Service Ownership

### Auth API owns
- users
- identities
- password credentials
- sessions / refresh tokens
- email verification
- password reset
- invitations
- permission catalog
- global roles and role assignments
- global auth/authorization primitives

### Core API owns
- chapters
- memberships
- chapter-scoped roles
- chapter role-to-permission mapping
- member profiles
- service areas
- coverage requests, candidates, matches, dossiers, execution
- ratings, disputes, reputation, tiers
- chapter community
- Prep Lab content and learner progress
- notification intents
- audit events for core workflows

### Media API owns
- upload intents
- media objects
- attachment links
- retention / deletion lifecycle

---

## Shared Field Conventions

Most persisted entities should include:

- `id: uuid`
- `created_at: timestamptz not null`
- `updated_at: timestamptz not null`
- `deleted_at: timestamptz null` for soft-delete when applicable
- `version: integer not null default 1` for optimistic concurrency on important records

Soft-delete is recommended for user-generated content, ratings disputes, and moderation records where auditability matters.

---

## Common Enums

### AccountStatus
- `invited`
- `pending_verification`
- `active`
- `suspended`
- `disabled`

### IdentityProvider
- `password`
- `google`
- `apple`

### TokenStatus
- `active`
- `used`
- `revoked`
- `expired`

### GlobalRoleCode
- `platform_admin`
- `support_admin`
- `readonly_auditor`

### PermissionScope
- `global`
- `chapter`

### MembershipStatus
- `pending`
- `active`
- `inactive`
- `suspended`
- `removed`

### ChapterRole
- `member`
- `tech4tech_chair`
- `president`
- `vice_president`
- `treasurer`
- `secretary`
- `community_moderator`
- `ratings_moderator`
- `admin_delegate`

### ProfileVisibility
- `draft`
- `members_only`
- `public`

### CoverageMode
- `sick_day`
- `emergency`
- `planned`

### CoverageRequestStatus
- `draft`
- `open`
- `matching`
- `matched`
- `in_progress`
- `completed`
- `cancelled`
- `expired`
- `closed`

### CandidateStatus
- `eligible`
- `surfaced`
- `passed`
- `requested`
- `declined`
- `accepted`
- `expired`
- `auto_closed`
- `ineligible`

### MatchStatus
- `pending`
- `active`
- `cancelled`
- `completed`
- `abandoned`
- `disputed`
- `closed`

### DossierStatus
- `open`
- `in_progress`
- `awaiting_review`
- `completed`
- `closed`

### StopStatus
- `pending`
- `in_progress`
- `completed`
- `partial`
- `blocked`
- `skipped`

### ExceptionType
- `access_issue`
- `water_issue`
- `equipment_issue`
- `customer_issue`
- `safety_issue`
- `other`

### ExceptionSeverity
- `low`
- `medium`
- `high`

### RatingDirection
- `requester_to_provider`
- `provider_to_requester`

### RatingStatus
- `submitted`
- `flagged`
- `under_review`
- `resolved`
- `hidden`

### DisputeStatus
- `open`
- `under_review`
- `upheld`
- `dismissed`
- `resolved`

### ChannelType
- `announcements`
- `tips`
- `customer_issues`
- `general`

### ThreadStatus
- `active`
- `locked`
- `archived`
- `removed`

### ReportReasonCode
- `abuse`
- `harassment`
- `spam`
- `privacy_pii`
- `misinformation`
- `retaliation`
- `other`

### ModerationCaseStatus
- `open`
- `in_review`
- `actioned`
- `dismissed`
- `closed`

### QuestionType
- `single_select`
- `multi_select`
- `true_false`

### DifficultyLevel
- `easy`
- `medium`
- `hard`

### ProgressStatus
- `not_started`
- `in_progress`
- `completed`

### DrillMode
- `practice`
- `review`
- `exam_sim`

### ReviewOutcome
- `correct`
- `incorrect`
- `skipped`

### NotificationChannel
- `push`
- `email`
- `sms`

### NotificationPriority
- `low`
- `normal`
- `high`
- `urgent`

### NotificationStatus
- `pending`
- `scheduled`
- `sent`
- `failed`
- `cancelled`

### UploadPurpose
- `dossier_proof`
- `profile_logo`
- `profile_gallery`
- `community_attachment`

### MediaPrivacyClass
- `public`
- `members_only`
- `private`

### AttachmentTargetType
- `coverage_dossier`
- `dossier_stop`
- `member_profile`
- `community_post`

---

# Auth API Schema

## 1. User

Represents a platform account.

### Fields
- `id: uuid`
- `email: citext not null unique`
- `status: AccountStatus not null`
- `display_name: text null`
- `phone_e164: text null`
- `phone_verified_at: timestamptz null`
- `last_login_at: timestamptz null`
- `created_at: timestamptz`
- `updated_at: timestamptz`
- `deleted_at: timestamptz null`

### Validation
- `email` must be syntactically valid and normalized
- `phone_e164` must be E.164 if present
- only one active user per email
- `status` transitions must follow lifecycle rules:
  - `invited -> pending_verification -> active`
  - `active -> suspended|disabled`
- soft-deleted users cannot create new sessions

### Relationships
- one-to-many with `Identity`
- one-to-many with `PasswordCredential`
- one-to-many with `Session`
- one-to-many with `EmailVerificationToken`
- one-to-many with `PasswordResetToken`
- one-to-many with `Invite` as inviter

---

## 2. Identity

Represents an authentication identity/provider binding.

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `provider: IdentityProvider not null`
- `provider_subject: text not null`
- `is_primary: boolean not null default false`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- unique on `(provider, provider_subject)`
- each user may have at most one identity per provider
- at most one `is_primary = true` per user

### Relationships
- many-to-one with `User`

---

## 3. PasswordCredential

Stores password auth material for users using local auth.

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `password_hash: text not null`
- `password_algo: text not null`
- `password_set_at: timestamptz not null`
- `must_rotate: boolean not null default false`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- one active password credential per user
- hashes only; never store plaintext or reversible secrets
- password rotation should invalidate older reset tokens

### Relationships
- many-to-one with `User`

---

## 4. Session

Persisted session / refresh-token record.

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `refresh_token_hash: text not null unique`
- `device_label: text null`
- `user_agent: text null`
- `ip_address: inet null`
- `issued_at: timestamptz not null`
- `expires_at: timestamptz not null`
- `last_seen_at: timestamptz null`
- `revoked_at: timestamptz null`
- `revoke_reason: text null`

### Validation
- `expires_at > issued_at`
- revoked sessions cannot become active again
- only active users may hold active sessions

### Relationships
- many-to-one with `User`

---

## 5. EmailVerificationToken

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `token_hash: text not null unique`
- `status: TokenStatus not null`
- `expires_at: timestamptz not null`
- `used_at: timestamptz null`
- `created_at: timestamptz`

### Validation
- one or more outstanding tokens allowed, but only latest should be honored if policy requires
- token may only be used once
- expired or revoked tokens are invalid

### Relationships
- many-to-one with `User`

---

## 6. PasswordResetToken

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `token_hash: text not null unique`
- `status: TokenStatus not null`
- `expires_at: timestamptz not null`
- `used_at: timestamptz null`
- `created_at: timestamptz`

### Validation
- token single-use only
- reset should revoke older outstanding reset tokens
- abusive creation should be rate limited at application layer

### Relationships
- many-to-one with `User`

---

## 7. Invite

Represents chapter/member onboarding invitations.

### Fields
- `id: uuid`
- `email: citext not null`
- `chapter_id: uuid not null`
- `invited_by_user_id: uuid not null`
- `suggested_chapter_role_code: text not null default 'member'`
- `token_hash: text not null unique`
- `status: TokenStatus not null`
- `expires_at: timestamptz not null`
- `accepted_user_id: uuid null`
- `accepted_at: timestamptz null`
- `created_at: timestamptz`

### Validation
- invite must reference a valid chapter in Core API
- suggested chapter role code should match a Core-recognized chapter role
- accepted invite must create or bind to a user account
- expired invites cannot be accepted

### Relationships
- many-to-one with `User` as inviter
- optional many-to-one with `User` as accepter
- logical reference to Core `Chapter`

---

## 7A. Permission

Canonical permission catalog for platform authorization decisions.

### Fields
- `code: text primary key`
- `scope: PermissionScope not null`
- `service_owner: text not null`
- `description: text not null`
- `is_system: boolean not null default true`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- permission codes should be namespaced, e.g. `chapter.community.moderate`
- `scope` determines whether permission is evaluated as platform-global or chapter-scoped
- codes should be immutable once referenced by role mappings or claims

### Relationships
- one-to-many with `GlobalRolePermission`
- logical one-to-many with `ChapterRolePermission`

---

## 7B. GlobalRole

Platform-wide RBAC role for non-chapter-scoped administrative access.

### Fields
- `code: GlobalRoleCode primary key`
- `name: text not null`
- `description: text null`
- `is_system: boolean not null default true`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- global roles should be few, stable, and limited to platform-wide operations
- global roles should not be used to model chapter duties such as president or Tech-4-Tech chair

### Relationships
- one-to-many with `GlobalRolePermission`
- one-to-many with `UserGlobalRoleAssignment`

---

## 7C. GlobalRolePermission

Maps global roles to permissions in the auth-owned permission catalog.

### Fields
- `global_role_code: GlobalRoleCode not null`
- `permission_code: text not null`
- `created_at: timestamptz`

### Validation
- unique active mapping per `(global_role_code, permission_code)`
- mapped permissions should exist in the auth permission catalog
- permissions attached to global roles should be evaluated without requiring chapter context

### Relationships
- many-to-one with `GlobalRole`
- many-to-one with `Permission`

---

## 7D. UserGlobalRoleAssignment

Assigns a global role to a user for platform-wide administration/support use cases.

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `global_role_code: GlobalRoleCode not null`
- `assigned_by_user_id: uuid not null`
- `starts_at: timestamptz not null`
- `ends_at: timestamptz null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- unique active assignment per `(user_id, global_role_code)`
- expired assignments must be excluded from token claims and gateway-trusted auth context
- assignments should be auditable and limited to authorized platform admins/support staff

### Relationships
- many-to-one with `User`
- many-to-one with `GlobalRole`

---

# Core API Schema

## 8. Chapter

Represents an IPSSA chapter.

### Fields
- `id: uuid`
- `name: text not null`
- `slug: text not null unique`
- `region_code: text null`
- `timezone: text not null`
- `status: text not null`
- `description: text null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- `slug` unique and URL-safe
- `timezone` must be valid IANA timezone
- status should be constrained to allowed chapter lifecycle values

### Relationships
- one-to-many with `ChapterMembership`
- one-to-one with `ChapterPolicy`
- one-to-many with `CommunityChannel`
- one-to-many with `CoverageRequest`

---

## 9. ChapterPolicy

Chapter-level behavior toggles and ranking settings.

### Fields
- `chapter_id: uuid primary key`
- `community_enabled: boolean not null default true`
- `general_chat_enabled: boolean not null default false`
- `leaderboard_enabled: boolean not null default false`
- `coverage_emergency_enabled: boolean not null default true`
- `weight_proximity: numeric(5,2) not null default 0.50`
- `weight_availability: numeric(5,2) not null default 0.25`
- `weight_specialty: numeric(5,2) not null default 0.15`
- `weight_reputation: numeric(5,2) not null default 0.10`
- `max_emergency_response_minutes: integer not null default 15`
- `proof_location_required: boolean not null default false`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- weights should be between `0` and `1`
- sum of ranking weights should equal `1.0`
- policy changes should be auditable

### Relationships
- one-to-one with `Chapter`

---

## 10. ChapterMembership

Represents a user's membership in a chapter.

### Fields
- `id: uuid`
- `chapter_id: uuid not null`
- `user_id: uuid not null`
- `status: MembershipStatus not null`
- `member_since: date null`
- `joined_at: timestamptz not null`
- `left_at: timestamptz null`
- `is_primary: boolean not null default false`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- unique active membership per `(chapter_id, user_id)`
- `left_at` only valid if status is non-active
- at most one primary active membership per user

### Relationships
- many-to-one with `Chapter`
- logical many-to-one with Auth `User`
- one-to-many with `ChapterRoleAssignment`

---

## 11. ChapterRoleAssignment

Stores officer/moderation role assignments within a chapter.

### Fields
- `id: uuid`
- `membership_id: uuid not null`
- `role: ChapterRole not null`
- `starts_at: timestamptz not null`
- `ends_at: timestamptz null`
- `assigned_by_user_id: uuid not null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- unique active role assignment per `(membership_id, role)`
- chapter-scoped roles only; platform-global roles and permission claims should live in Auth API
- expired assignments must be excluded from claim generation

### Relationships
- many-to-one with `ChapterMembership`

---

## 11A. ChapterRolePermission

Maps chapter-scoped roles to permission codes used by Core API authorization checks.

### Fields
- `role: ChapterRole not null`
- `permission_code: text not null`
- `created_at: timestamptz`

### Validation
- unique mapping per `(role, permission_code)`
- `permission_code` should logically reference the auth-owned permission catalog
- chapter-sensitive writes should be authorized from active membership plus current role-permission mappings, not from token role labels alone

### Relationships
- logical many-to-one with `Permission`

---

## 12. MemberProfile

Business/member profile used for trust surfaces and matching.

### Fields
- `id: uuid`
- `user_id: uuid not null unique`
- `business_name: text not null`
- `public_display_name: text null`
- `bio: text null`
- `years_experience: integer null`
- `website_url: text null`
- `phone_public_e164: text null`
- `email_public: citext null`
- `profile_visibility: ProfileVisibility not null default 'draft'`
- `coverage_score_cached: numeric(5,2) null`
- `tier_code_cached: text null`
- `is_profile_complete: boolean not null default false`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- `years_experience >= 0`
- URLs must be valid if present
- public email/phone must be optional and explicit
- cached reputation fields must be derived from reputation subsystem, not edited manually

### Relationships
- one-to-one logical with Auth `User`
- one-to-many with `ProfileServiceArea`
- one-to-many with `ProfileSpecialty`
- one-to-many with `ProfileCertification`
- one-to-many with Media `MediaAttachment`

---

## 13. ProfileServiceArea

Represents where a member/company services pools.

### Fields
- `id: uuid`
- `profile_id: uuid not null`
- `label: text not null`
- `center_point: geography(Point,4326) null`
- `radius_meters: integer null`
- `postal_codes: text[] null`
- `geometry_geojson: jsonb null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- at least one of `radius_meters`, `postal_codes`, or `geometry_geojson` must be present
- `radius_meters > 0` if present
- use either PostGIS geometry/geography or a normalized location strategy consistently

### Relationships
- many-to-one with `MemberProfile`

---

## 14. ProfileSpecialty

### Fields
- `id: uuid`
- `profile_id: uuid not null`
- `specialty_code: text not null`
- `is_primary: boolean not null default false`
- `created_at: timestamptz`

### Validation
- unique on `(profile_id, specialty_code)`

### Relationships
- many-to-one with `MemberProfile`

---

## 15. ProfileCertification

### Fields
- `id: uuid`
- `profile_id: uuid not null`
- `certification_code: text not null`
- `issuer_name: text null`
- `issued_on: date null`
- `expires_on: date null`
- `verification_url: text null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- `expires_on >= issued_on` if both present
- public-facing display should respect visibility/privacy rules

### Relationships
- many-to-one with `MemberProfile`

---

## 16. NotificationPreference

Per-user notification settings.

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `event_code: text not null`
- `channel: NotificationChannel not null`
- `enabled: boolean not null default true`
- `quiet_hours_start_local: time null`
- `quiet_hours_end_local: time null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- unique on `(user_id, event_code, channel)`

### Relationships
- logical many-to-one with Auth `User`

---

## 17. CoverageRequest

Top-level request for route coverage.

### Fields
- `id: uuid`
- `chapter_id: uuid not null`
- `requester_membership_id: uuid not null`
- `created_by_user_id: uuid not null`
- `mode: CoverageMode not null`
- `status: CoverageRequestStatus not null`
- `service_date: date not null`
- `window_start_at: timestamptz null`
- `window_end_at: timestamptz null`
- `requested_stop_count: integer not null default 0`
- `location_context: jsonb null`
- `specialty_requirements: text[] null`
- `notes: text null`
- `officer_override_user_id: uuid null`
- `matched_at: timestamptz null`
- `closed_at: timestamptz null`
- `close_reason: text null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- `requested_stop_count >= 0`
- `window_end_at >= window_start_at` when both present
- mode-specific rules:
  - `sick_day`: same-day or near-immediate start expected
  - `emergency`: may allow officer-created override and shorter response windows
  - `planned`: should require future service date and broader candidate window
- only active chapter members may create requests unless an authorized officer acts on behalf of a member

### Relationships
- many-to-one with `Chapter`
- many-to-one with `ChapterMembership`
- one-to-many with `CoverageCandidate`
- one-to-one or one-to-many with `CoverageMatch` depending on policy; MVP should assume one primary fulfilled match per request

---

## 18. CoverageCandidate

Candidate assembly and ranking result for a coverage request.

### Fields
- `id: uuid`
- `coverage_request_id: uuid not null`
- `candidate_user_id: uuid not null`
- `candidate_profile_id: uuid not null`
- `rank_score: numeric(8,4) not null`
- `score_breakdown: jsonb not null`
- `status: CandidateStatus not null`
- `surfaced_at: timestamptz null`
- `responded_at: timestamptz null`
- `expires_at: timestamptz null`
- `ineligibility_reason: text null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- unique on `(coverage_request_id, candidate_user_id)`
- `score_breakdown` must contain only recognized components
- accepted candidate must be unique per request unless later multi-provider support is added
- ineligible candidates should not be surfaced to users

### Relationships
- many-to-one with `CoverageRequest`
- many-to-one with `MemberProfile`
- optional one-to-one with `CoverageMatch`

---

## 19. CoverageMatch

Accepted provider/requester pairing.

### Fields
- `id: uuid`
- `coverage_request_id: uuid not null unique`
- `coverage_candidate_id: uuid not null unique`
- `provider_membership_id: uuid not null`
- `status: MatchStatus not null`
- `accepted_at: timestamptz not null`
- `started_at: timestamptz null`
- `completed_at: timestamptz null`
- `closed_at: timestamptz null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- only one active match per request in MVP
- provider must belong to the same chapter unless cross-chapter policy is explicitly supported later
- match cannot complete before acceptance

### Relationships
- one-to-one with `CoverageRequest`
- many-to-one with `ChapterMembership` as provider
- one-to-one with `CoverageDossier`
- one-to-many with `Rating`

---

## 20. CoverageDossier

Shared operational record used after a match is confirmed.

### Fields
- `id: uuid`
- `coverage_match_id: uuid not null unique`
- `coverage_request_id: uuid not null unique`
- `requester_membership_id: uuid not null`
- `provider_membership_id: uuid not null`
- `status: DossierStatus not null`
- `route_notes: text null`
- `customer_contact_protocol: text null`
- `safety_notes: text null`
- `internal_handoff_notes: text null`
- `created_at: timestamptz`
- `updated_at: timestamptz`
- `closed_at: timestamptz null`

### Validation
- dossier created only after match acceptance
- access limited to requester, provider, and authorized officers/moderators
- private customer-sensitive content must never be public-facing

### Relationships
- one-to-one with `CoverageMatch`
- one-to-many with `DossierStop`
- one-to-many with `CoverageExecutionEvent`
- one-to-many with `CoverageException`
- one-to-many logical with Media `MediaAttachment`

---

## 21. DossierStop

A service stop within a coverage dossier.

### Fields
- `id: uuid`
- `coverage_dossier_id: uuid not null`
- `sequence_number: integer not null`
- `customer_label: text not null`
- `service_address: jsonb not null`
- `contact_protocol: text null`
- `access_instructions: text null`
- `expected_tasks: jsonb null`
- `status: StopStatus not null default 'pending'`
- `completed_at: timestamptz null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- unique on `(coverage_dossier_id, sequence_number)`
- `sequence_number > 0`
- customer and address data should be minimized and treated as private operational data
- stop cannot be marked `completed` without completion metadata or explicit override

### Relationships
- many-to-one with `CoverageDossier`
- one-to-many with `CoverageExecutionEvent`
- one-to-many with `CoverageException`
- one-to-many logical with Media `MediaAttachment`

---

## 22. CoverageExecutionEvent

Append-only operational event log for execution.

### Fields
- `id: uuid`
- `coverage_dossier_id: uuid not null`
- `dossier_stop_id: uuid null`
- `actor_user_id: uuid not null`
- `event_type: text not null`
- `occurred_at: timestamptz not null`
- `payload: jsonb null`
- `created_at: timestamptz`

### Validation
- event types should come from a controlled application enum or registry
- append-only; updates should be restricted
- payload shape must be validated per `event_type`

### Relationships
- many-to-one with `CoverageDossier`
- optional many-to-one with `DossierStop`

Suggested event types:
- `check_in`
- `proof_uploaded`
- `stop_completed`
- `exception_reported`
- `job_completed`
- `job_reopened`

---

## 23. CoverageException

Exception/problem recorded during execution.

### Fields
- `id: uuid`
- `coverage_dossier_id: uuid not null`
- `dossier_stop_id: uuid null`
- `reported_by_user_id: uuid not null`
- `type: ExceptionType not null`
- `severity: ExceptionSeverity not null`
- `description: text not null`
- `status: text not null`
- `resolved_by_user_id: uuid null`
- `resolved_at: timestamptz null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- description required
- resolution fields only valid when status is resolved/closed
- severe safety issues may require forced officer visibility

### Relationships
- many-to-one with `CoverageDossier`
- optional many-to-one with `DossierStop`

---

## 24. Rating

Two-way rating submitted after coverage work.

### Fields
- `id: uuid`
- `coverage_match_id: uuid not null`
- `reviewer_user_id: uuid not null`
- `reviewee_user_id: uuid not null`
- `direction: RatingDirection not null`
- `overall_score: smallint not null`
- `communication_score: smallint not null`
- `service_quality_score: smallint null`
- `professionalism_score: smallint null`
- `handoff_quality_score: smallint null`
- `fairness_score: smallint null`
- `comment_text: text null`
- `status: RatingStatus not null default 'submitted'`
- `submitted_at: timestamptz not null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- score fields must be integers `1..5`
- `requester_to_provider` requires:
  - `service_quality_score`
  - `professionalism_score`
  - `communication_score`
- `provider_to_requester` requires:
  - `handoff_quality_score`
  - `fairness_score`
  - `communication_score`
- unique on `(coverage_match_id, reviewer_user_id, direction)`
- rating allowed only after match completion or explicit closure rule

### Relationships
- many-to-one with `CoverageMatch`
- one-to-many with `RatingDispute`

---

## 25. RatingDispute

Flags and moderation around ratings.

### Fields
- `id: uuid`
- `rating_id: uuid not null`
- `opened_by_user_id: uuid not null`
- `reason_code: ReportReasonCode not null`
- `description: text null`
- `status: DisputeStatus not null`
- `assigned_to_user_id: uuid null`
- `resolution_code: text null`
- `resolution_notes: text null`
- `resolved_at: timestamptz null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- one open dispute per rating by default unless policy supports multiple reporters
- resolution metadata required when dispute is closed
- officer/moderator permissions required for assignment and resolution

### Relationships
- many-to-one with `Rating`

---

## 26. ReputationSummary

Derived trust surface used by matching and profiles.

### Fields
- `user_id: uuid primary key`
- `coverage_score: numeric(5,2) not null`
- `provisional: boolean not null default true`
- `provider_rating_count: integer not null default 0`
- `requester_rating_count: integer not null default 0`
- `total_completed_matches: integer not null default 0`
- `visible_badge_count: integer not null default 0`
- `last_recalculated_at: timestamptz not null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- counts must be non-negative
- visibility should respect minimum-threshold rules before showing non-provisional score
- derived only from valid, non-hidden ratings and approved badge/tier rules

### Relationships
- logical one-to-one with Auth `User`
- logical one-to-one with `MemberProfile`

---

## 27. TierDefinition

Static or admin-managed reputation tier ladder.

### Fields
- `code: text primary key`
- `name: text not null`
- `sort_order: integer not null`
- `min_coverage_score: numeric(5,2) not null`
- `min_completed_matches: integer not null`
- `active: boolean not null default true`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- `sort_order` unique
- thresholds should not overlap ambiguously

### Relationships
- one-to-many with `UserTierAssignment`

---

## 28. UserTierAssignment

Current or historical tier assignment.

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `tier_code: text not null`
- `status: text not null`
- `awarded_at: timestamptz not null`
- `frozen_at: timestamptz null`
- `demoted_at: timestamptz null`
- `reason: text null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- at most one active assignment per user
- freeze/demotion must include reason where policy requires

### Relationships
- many-to-one with `TierDefinition`

---

## 29. CommunityChannel

Chapter-scoped communication channel.

### Fields
- `id: uuid`
- `chapter_id: uuid not null`
- `type: ChannelType not null`
- `name: text not null`
- `description: text null`
- `is_enabled: boolean not null default true`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- unique on `(chapter_id, type)`
- announcements channel may be restricted to officers/moderators for posting

### Relationships
- many-to-one with `Chapter`
- one-to-many with `CommunityThread`

---

## 30. CommunityThread

Top-level thread in a channel.

### Fields
- `id: uuid`
- `community_channel_id: uuid not null`
- `chapter_id: uuid not null`
- `created_by_user_id: uuid not null`
- `title: text not null`
- `status: ThreadStatus not null default 'active'`
- `is_pinned: boolean not null default false`
- `pinned_at: timestamptz null`
- `last_activity_at: timestamptz not null`
- `created_at: timestamptz`
- `updated_at: timestamptz`
- `deleted_at: timestamptz null`

### Validation
- thread must inherit chapter from channel
- pinned announcements may be limited by channel type and role
- locked or removed threads cannot accept new non-moderator posts

### Relationships
- many-to-one with `CommunityChannel`
- one-to-many with `CommunityPost`

---

## 31. CommunityPost

Post within a thread.

### Fields
- `id: uuid`
- `community_thread_id: uuid not null`
- `author_user_id: uuid not null`
- `reply_to_post_id: uuid null`
- `body_markdown: text not null`
- `body_text_search: tsvector null`
- `pii_flag: text not null default 'none'`
- `status: text not null default 'active'`
- `edited_at: timestamptz null`
- `created_at: timestamptz`
- `updated_at: timestamptz`
- `deleted_at: timestamptz null`

### Validation
- body cannot be empty
- customer-issue posts may require PII warning/interstitial behavior
- replies must belong to the same thread
- soft delete preferred for moderation history

### Relationships
- many-to-one with `CommunityThread`
- one-to-many with `ContentReport`
- one-to-many logical with Media `MediaAttachment`

---

## 32. ContentReport

User-submitted moderation report.

### Fields
- `id: uuid`
- `target_type: text not null`
- `target_id: uuid not null`
- `chapter_id: uuid not null`
- `reported_by_user_id: uuid not null`
- `reason_code: ReportReasonCode not null`
- `notes: text null`
- `status: text not null default 'open'`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- `target_type` should be restricted to allowed reportable entities
- reporter cannot report already deleted/hidden targets without preserving original target reference
- duplicate report throttling recommended

### Relationships
- one-to-one or one-to-many with `ModerationCase` depending on workflow choice

---

## 33. ModerationCase

Moderator workflow record for reported content.

### Fields
- `id: uuid`
- `content_report_id: uuid not null`
- `target_type: text not null`
- `target_id: uuid not null`
- `chapter_id: uuid not null`
- `status: ModerationCaseStatus not null`
- `assigned_to_user_id: uuid null`
- `resolution_code: text null`
- `resolution_notes: text null`
- `closed_at: timestamptz null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- case status transition rules should be enforced
- resolution metadata required on closure
- moderation actions should be auditable

### Relationships
- one-to-many with `ModerationAction`

---

## 34. ModerationAction

Discrete moderator action taken within a case.

### Fields
- `id: uuid`
- `moderation_case_id: uuid not null`
- `actor_user_id: uuid not null`
- `action_type: text not null`
- `reason: text null`
- `created_at: timestamptz`

### Validation
- action type should be constrained to allowed values such as:
  - `hide`
  - `remove`
  - `lock`
  - `warn`
  - `restore`
  - `escalate`
- append-only preferred

### Relationships
- many-to-one with `ModerationCase`

---

## 35. PrepModule

Top-level learning module.

### Fields
- `id: uuid`
- `slug: text not null unique`
- `title: text not null`
- `description: text null`
- `topic_code: text not null`
- `difficulty: DifficultyLevel null`
- `is_active: boolean not null default true`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- slugs unique and URL-safe
- only original/sanctioned content allowed

### Relationships
- one-to-many with `PrepLesson`
- one-to-many with `PrepQuestion`
- one-to-many with `CurriculumMapping`

---

## 36. PrepLesson

Optional lesson/content unit within a module.

### Fields
- `id: uuid`
- `prep_module_id: uuid not null`
- `title: text not null`
- `order_index: integer not null`
- `estimated_minutes: integer null`
- `body_markdown: text null`
- `is_active: boolean not null default true`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- unique on `(prep_module_id, order_index)`
- `estimated_minutes > 0` if present

### Relationships
- many-to-one with `PrepModule`

---

## 37. PrepQuestion

Question bank item.

### Fields
- `id: uuid`
- `prep_module_id: uuid not null`
- `prep_lesson_id: uuid null`
- `question_type: QuestionType not null`
- `difficulty: DifficultyLevel not null`
- `stem_markdown: text not null`
- `explanation_markdown: text not null`
- `provenance_type: text not null`
- `provenance_notes: text null`
- `is_active: boolean not null default true`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- provenance must indicate original/sanctioned/licensed source
- no proprietary exam content copied without rights
- explanation required for review-driven learning
- question must have valid answer option rules based on `question_type`

### Relationships
- many-to-one with `PrepModule`
- optional many-to-one with `PrepLesson`
- one-to-many with `PrepQuestionOption`
- one-to-many with `CurriculumMapping`

---

## 38. PrepQuestionOption

Answer option for a question.

### Fields
- `id: uuid`
- `prep_question_id: uuid not null`
- `label: text not null`
- `order_index: integer not null`
- `is_correct: boolean not null`
- `rationale_markdown: text null`
- `created_at: timestamptz`

### Validation
- unique on `(prep_question_id, order_index)`
- `single_select` and `true_false` questions should have exactly one correct option
- `multi_select` questions should have one or more correct options

### Relationships
- many-to-one with `PrepQuestion`

---

## 39. CurriculumMapping

Maps content to curriculum topics/objectives.

### Fields
- `id: uuid`
- `entity_type: text not null`
- `entity_id: uuid not null`
- `topic_code: text not null`
- `objective_code: text null`
- `weight: numeric(5,2) null`
- `created_at: timestamptz`

### Validation
- `entity_type` restricted to `module`, `lesson`, or `question`
- weights should be non-negative

### Relationships
- logical polymorphic relationship to `PrepModule`, `PrepLesson`, or `PrepQuestion`

---

## 40. LearnerProgress

Per-user progress summary for a module.

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `prep_module_id: uuid not null`
- `status: ProgressStatus not null`
- `mastery_score: numeric(5,2) not null default 0`
- `correct_count: integer not null default 0`
- `incorrect_count: integer not null default 0`
- `last_activity_at: timestamptz null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- unique on `(user_id, prep_module_id)`
- counts non-negative
- `mastery_score` within expected range, e.g. `0..100`

### Relationships
- logical many-to-one with Auth `User`
- many-to-one with `PrepModule`

---

## 41. DrillSession

A user’s practice, review, or exam-sim session.

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `mode: DrillMode not null`
- `prep_module_id: uuid null`
- `started_at: timestamptz not null`
- `completed_at: timestamptz null`
- `total_questions: integer not null default 0`
- `correct_answers: integer not null default 0`
- `score_percent: numeric(5,2) null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- `completed_at >= started_at` if present
- `correct_answers <= total_questions`
- score should be derived, not manually edited

### Relationships
- one-to-many with `DrillAnswer`

---

## 42. DrillAnswer

Recorded answer within a drill session.

### Fields
- `id: uuid`
- `drill_session_id: uuid not null`
- `prep_question_id: uuid not null`
- `selected_option_ids: uuid[] not null`
- `is_correct: boolean not null`
- `response_ms: integer null`
- `answered_at: timestamptz not null`
- `created_at: timestamptz`

### Validation
- selected options must belong to the referenced question
- `response_ms >= 0` if present

### Relationships
- many-to-one with `DrillSession`
- many-to-one with `PrepQuestion`

---

## 43. ReviewItem

Per-user spaced-repetition item.

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `prep_question_id: uuid not null`
- `source_drill_session_id: uuid null`
- `due_at: timestamptz not null`
- `ease_factor: numeric(4,2) not null`
- `interval_days: integer not null`
- `repetition_count: integer not null default 0`
- `last_outcome: ReviewOutcome null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- unique on `(user_id, prep_question_id)` if using single active review item per question
- `interval_days >= 0`
- `ease_factor` bounded by algorithm rules

### Relationships
- logical many-to-one with Auth `User`
- many-to-one with `PrepQuestion`

---

## 44. LearningBadgeDefinition

Optional gamification badge catalog for Prep Lab.

### Fields
- `code: text primary key`
- `name: text not null`
- `description: text null`
- `rule_type: text not null`
- `active: boolean not null default true`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- `rule_type` should correspond to known evaluator logic

### Relationships
- one-to-many with `UserLearningBadge`

---

## 45. UserLearningBadge

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `badge_code: text not null`
- `awarded_at: timestamptz not null`
- `created_at: timestamptz`

### Validation
- unique on `(user_id, badge_code)` unless repeatable badges are intentionally supported

### Relationships
- many-to-one with `LearningBadgeDefinition`

---

## 46. NotificationIntent

Queued notification request inside Core API.

### Fields
- `id: uuid`
- `user_id: uuid not null`
- `event_code: text not null`
- `channel: NotificationChannel not null`
- `priority: NotificationPriority not null default 'normal'`
- `status: NotificationStatus not null default 'pending'`
- `dedupe_key: text null`
- `payload: jsonb not null`
- `scheduled_for: timestamptz null`
- `sent_at: timestamptz null`
- `failure_reason: text null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- if `dedupe_key` used, uniqueness policy should be enforced per event window
- payload schema should be validated by `event_code`
- contactability and user preferences should be checked before send

### Relationships
- logical many-to-one with Auth `User`

---

## 47. AuditEvent

Cross-cutting audit log for business-critical actions.

### Fields
- `id: uuid`
- `actor_user_id: uuid null`
- `actor_type: text not null`
- `chapter_id: uuid null`
- `entity_type: text not null`
- `entity_id: uuid not null`
- `action: text not null`
- `request_id: text null`
- `ip_address: inet null`
- `before_state: jsonb null`
- `after_state: jsonb null`
- `occurred_at: timestamptz not null`
- `created_at: timestamptz`

### Validation
- append-only
- `before_state`/`after_state` should be redacted for secrets and sensitive PII
- actions should be drawn from a controlled vocabulary

### Relationships
- polymorphic reference to any auditable entity

Recommended auditable domains:
- auth events
- membership changes
- role changes
- coverage lifecycle transitions
- dossier access and closures
- rating disputes
- moderation actions
- media deletion

---

# Media API Schema

## 48. UploadIntent

Authorized upload request before an object is stored.

### Fields
- `id: uuid`
- `actor_user_id: uuid not null`
- `purpose: UploadPurpose not null`
- `target_type: AttachmentTargetType not null`
- `target_id: uuid not null`
- `mime_whitelist: text[] not null`
- `max_bytes: bigint not null`
- `status: text not null`
- `expires_at: timestamptz not null`
- `consumed_at: timestamptz null`
- `created_at: timestamptz`
- `updated_at: timestamptz`

### Validation
- upload intent must be permission-checked against target ownership and visibility rules
- `max_bytes > 0`
- intent cannot be reused after `consumed_at`

### Relationships
- logical polymorphic reference to Core entities such as `CoverageDossier`, `DossierStop`, `MemberProfile`, `CommunityPost`

---

## 49. MediaObject

Stored media metadata.

### Fields
- `id: uuid`
- `upload_intent_id: uuid not null`
- `storage_key: text not null unique`
- `bucket_name: text not null`
- `mime_type: text not null`
- `size_bytes: bigint not null`
- `checksum_sha256: text not null`
- `width_px: integer null`
- `height_px: integer null`
- `captured_at: timestamptz null`
- `uploaded_by_user_id: uuid not null`
- `privacy_class: MediaPrivacyClass not null`
- `created_at: timestamptz`
- `updated_at: timestamptz`
- `deleted_at: timestamptz null`

### Validation
- enforce accepted MIME types by upload purpose
- `size_bytes > 0`
- checksums required for integrity
- proof/dossier images should default to `private`

### Relationships
- many-to-one with `UploadIntent`
- one-to-many with `MediaAttachment`

---

## 50. MediaAttachment

Links a media object to a business entity.

### Fields
- `id: uuid`
- `media_object_id: uuid not null`
- `target_type: AttachmentTargetType not null`
- `target_id: uuid not null`
- `usage_code: text not null`
- `sort_order: integer null`
- `created_at: timestamptz`

### Validation
- unique duplicate-prevention rule as needed, e.g. `(media_object_id, target_type, target_id)`
- `usage_code` should be constrained by target type
- attachment visibility must never exceed object privacy class

### Relationships
- many-to-one with `MediaObject`
- logical polymorphic reference to Core entities

Suggested usage codes:
- `proof_photo`
- `profile_logo`
- `profile_gallery`
- `community_attachment`

---

## 51. MediaAccessLog

Optional audit record for private media access.

### Fields
- `id: uuid`
- `media_object_id: uuid not null`
- `viewer_user_id: uuid null`
- `access_type: text not null`
- `request_id: text null`
- `accessed_at: timestamptz not null`
- `created_at: timestamptz`

### Validation
- use for private/protected assets where access auditing matters
- should not log raw signed URLs

### Relationships
- many-to-one with `MediaObject`

---

# Relationship Summary

## Auth internal
- `User -> UserGlobalRoleAssignment -> GlobalRole`
- `GlobalRole -> GlobalRolePermission -> Permission`

## Auth -> Core
- `User.id` is referenced logically by:
  - `ChapterMembership.user_id`
  - `MemberProfile.user_id`
  - `NotificationPreference.user_id`
  - `CoverageExecutionEvent.actor_user_id`
  - `Rating.reviewer_user_id`
  - `Rating.reviewee_user_id`
  - `LearnerProgress.user_id`
  - `NotificationIntent.user_id`
- `Permission.code` is referenced logically by `ChapterRolePermission.permission_code`

## Core internal
- `Chapter -> ChapterMembership -> ChapterRoleAssignment`
- `ChapterRoleAssignment + ChapterRolePermission -> effective chapter authorization`
- `MemberProfile -> ProfileServiceArea / ProfileSpecialty / ProfileCertification`
- `CoverageRequest -> CoverageCandidate -> CoverageMatch -> CoverageDossier -> DossierStop`
- `CoverageMatch -> Rating -> RatingDispute`
- `CommunityChannel -> CommunityThread -> CommunityPost -> ContentReport -> ModerationCase -> ModerationAction`
- `PrepModule -> PrepLesson -> PrepQuestion -> PrepQuestionOption`
- `PrepQuestion -> DrillAnswer / ReviewItem`
- `PrepModule -> LearnerProgress`

## Core -> Media
- `CoverageDossier`, `DossierStop`, `MemberProfile`, and `CommunityPost` may all have `MediaAttachment` records
- Media service should enforce attachment authorization based on target ownership and visibility

---

# Validation and Integrity Rules

## Identity and membership
- no active coverage or community participation for suspended/disabled accounts
- no chapter-scoped actions without active membership in that chapter

## Authorization / RBAC
- Auth owns platform-global roles, permissions, and token-friendly global claims
- Core owns chapter-scoped role assignments and chapter permission resolution
- chapter-sensitive writes should be authorized from current Core state, not only from token role labels
- global admin/support claims may bypass chapter context only for explicitly global permissions
- role and permission mapping changes should be auditable and invalidate cached authorization context promptly

## Coverage workflow
- only one active match per coverage request in MVP
- rating opens only after completion or explicit closure rule
- emergency workflows may allow officer override and first-accept semantics
- proof uploads must be linked to an existing dossier or stop through authorized upload intents

## Reputation
- hidden or invalidated ratings must not count toward `ReputationSummary`
- minimum threshold required before public/non-provisional trust display
- anti-gaming detection should not directly mutate raw ratings; it should produce flags/cases/actions

## Community safety
- chapter scoping enforced on all community queries
- customer-issue content must support PII/privacy moderation rules
- deleted/hidden content should retain moderation traceability

## Prep Lab
- question provenance required
- original or licensed content only
- review scheduling must be reproducible and derivable from answer history if possible

## Media
- private assets served via signed access or equivalent
- retention rules vary by class:
  - dossier proof
  - community attachments
  - profile images
- deletions should be auditable and privacy-driven deletion should cascade through attachments

---

# Recommended Indexes

## Auth API
- `users(email)`
- `sessions(user_id, revoked_at, expires_at)`
- `email_verification_tokens(token_hash)`
- `password_reset_tokens(token_hash)`
- `invites(email, chapter_id)`
- `permissions(scope)`
- `user_global_role_assignments(user_id, global_role_code, ends_at)`
- `global_role_permissions(global_role_code, permission_code)`

## Core API
- `chapter_memberships(user_id, status)`
- `chapter_memberships(chapter_id, status)`
- `chapter_role_assignments(membership_id, role, ends_at)`
- `chapter_role_permissions(role, permission_code)`
- `member_profiles(user_id)`
- `coverage_requests(chapter_id, status, service_date)`
- `coverage_candidates(coverage_request_id, status, rank_score desc)`
- `coverage_matches(provider_membership_id, status)`
- `ratings(reviewee_user_id, status)`
- `community_threads(chapter_id, last_activity_at desc)`
- `community_posts(community_thread_id, created_at)`
- GIN on `community_posts.body_text_search`
- `learner_progress(user_id, prep_module_id)`
- `review_items(user_id, due_at)`

## Media API
- `upload_intents(target_type, target_id, status)`
- `media_objects(storage_key)`
- `media_attachments(target_type, target_id)`

---

# Open Design Decisions

The following should be finalized before first migrations:

- whether permissions should stay as code strings or later become a richer resource/action model
- whether chapter role codes should remain fixed system roles or later move to table-driven custom chapter roles
- whether gateway should cache effective chapter permission summaries or require Core lookup for every sensitive route
- whether cross-chapter coverage is in scope for MVP
- whether service areas use only radius/postal-code logic initially or PostGIS polygons from day one
- whether community attachments are in MVP
- whether `ReputationSummary` is materialized synchronously or via background job
- whether Prep Lab leaderboards need their own snapshot tables in v1
- whether `AuditEvent` is centralized or per-service with shared format

---

# Suggested Migration Order

1. Auth foundation
   - `users`
   - `identities`
   - `password_credentials`
   - `sessions`
   - `email_verification_tokens`
   - `password_reset_tokens`
   - `invites`
   - `permissions`
   - `global_roles`
   - `global_role_permissions`
   - `user_global_role_assignments`

2. Core foundation
   - `chapters`
   - `chapter_policies`
   - `chapter_memberships`
   - `chapter_role_assignments`
   - `chapter_role_permissions`
   - `member_profiles`
   - `profile_service_areas`
   - `profile_specialties`
   - `profile_certifications`
   - `notification_preferences`

3. Media foundation
   - `upload_intents`
   - `media_objects`
   - `media_attachments`

4. Coverage
   - `coverage_requests`
   - `coverage_candidates`
   - `coverage_matches`
   - `coverage_dossiers`
   - `dossier_stops`
   - `coverage_execution_events`
   - `coverage_exceptions`

5. Ratings and trust
   - `ratings`
   - `rating_disputes`
   - `tier_definitions`
   - `user_tier_assignments`
   - `reputation_summary`

6. Community
   - `community_channels`
   - `community_threads`
   - `community_posts`
   - `content_reports`
   - `moderation_cases`
   - `moderation_actions`

7. Prep Lab
   - `prep_modules`
   - `prep_lessons`
   - `prep_questions`
   - `prep_question_options`
   - `curriculum_mappings`
   - `learner_progress`
   - `drill_sessions`
   - `drill_answers`
   - `review_items`
   - `learning_badge_definitions`
   - `user_learning_badges`

8. Cross-cutting
   - `notification_intents`
   - `audit_events`
