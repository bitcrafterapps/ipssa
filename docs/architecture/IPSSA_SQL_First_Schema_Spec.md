# IPSSA SQL-First Schema Spec
## Purpose

This document translates the logical model in `docs/architecture/IPSSA_Data_Schema.md` into a PostgreSQL-first schema specification.

It is intended to guide:

- initial database setup
- migration planning
- service-owned table design
- enum creation
- foreign key strategy
- index planning

This is still a specification document, not production-ready DDL. It is intentionally close to SQL so engineering can turn it into migrations with minimal interpretation.

---

## PostgreSQL Target

- Engine: `PostgreSQL 16+`
- Primary extensions:
  - `pgcrypto` for `gen_random_uuid()`
  - `citext` for case-insensitive email fields
  - `pg_trgm` for search helpers
  - `postgis` if geospatial service-area queries are needed in MVP

Recommended bootstrap:

```sql
create extension if not exists pgcrypto;
create extension if not exists citext;
create extension if not exists pg_trgm;
-- enable only if geospatial matching is adopted early
create extension if not exists postgis;
```

---

## Database and Schema Strategy

The product architecture is service-oriented, so the SQL model should follow service ownership.

### Recommended deployment pattern

Use one PostgreSQL cluster initially, with one logical schema per service:

- `auth`
- `core`
- `media`

This keeps operating cost down early while preserving boundaries that can later split into separate databases.

### Important foreign key rule

Use **physical foreign keys only within a service-owned schema**.

Do **not** create database-level foreign keys across service boundaries such as:

- `core.* -> auth.users`
- `media.* -> core.coverage_dossiers`

For those, use:

- UUID reference columns
- application/service validation
- background consistency checks if needed

This avoids tight coupling between service-owned schemas and supports later service/database separation.

---

## Naming Conventions

- Tables: plural snake_case, e.g. `coverage_requests`
- Primary keys: `id uuid primary key`
- Foreign key columns: `<target>_id`
- Timestamps: `created_at`, `updated_at`, optional `deleted_at`
- Enum types: `<schema>.<name>_enum`
- Index names: `idx_<table>__<columns>`
- Unique constraints: `uq_<table>__<columns>`
- Check constraints: `chk_<table>__<rule>`
- Foreign keys: `fk_<table>__<target>`

---

## Shared Column Conventions

Most tables should include:

```sql
id uuid primary key default gen_random_uuid(),
created_at timestamptz not null default now(),
updated_at timestamptz not null default now()
```

Soft-delete tables should also include:

```sql
deleted_at timestamptz null
```

Versioned records should include:

```sql
version integer not null default 1
```

---

## Enum Definitions

## Auth enums

```sql
create type auth.account_status_enum as enum (
  'invited',
  'pending_verification',
  'active',
  'suspended',
  'disabled'
);

create type auth.identity_provider_enum as enum (
  'password',
  'google',
  'apple'
);

create type auth.token_status_enum as enum (
  'active',
  'used',
  'revoked',
  'expired'
);

create type auth.global_role_code_enum as enum (
  'platform_admin',
  'support_admin',
  'readonly_auditor'
);

create type auth.permission_scope_enum as enum (
  'global',
  'chapter'
);
```

## Core enums

```sql
create type core.membership_status_enum as enum (
  'pending',
  'active',
  'inactive',
  'suspended',
  'removed'
);

create type core.chapter_role_enum as enum (
  'member',
  'tech4tech_chair',
  'president',
  'vice_president',
  'treasurer',
  'secretary',
  'community_moderator',
  'ratings_moderator',
  'admin_delegate'
);

create type core.profile_visibility_enum as enum (
  'draft',
  'members_only',
  'public'
);

create type core.coverage_mode_enum as enum (
  'sick_day',
  'emergency',
  'planned'
);

create type core.coverage_request_status_enum as enum (
  'draft',
  'open',
  'matching',
  'matched',
  'in_progress',
  'completed',
  'cancelled',
  'expired',
  'closed'
);

create type core.candidate_status_enum as enum (
  'eligible',
  'surfaced',
  'passed',
  'requested',
  'declined',
  'accepted',
  'expired',
  'auto_closed',
  'ineligible'
);

create type core.match_status_enum as enum (
  'pending',
  'active',
  'cancelled',
  'completed',
  'abandoned',
  'disputed',
  'closed'
);

create type core.dossier_status_enum as enum (
  'open',
  'in_progress',
  'awaiting_review',
  'completed',
  'closed'
);

create type core.stop_status_enum as enum (
  'pending',
  'in_progress',
  'completed',
  'partial',
  'blocked',
  'skipped'
);

create type core.exception_type_enum as enum (
  'access_issue',
  'water_issue',
  'equipment_issue',
  'customer_issue',
  'safety_issue',
  'other'
);

create type core.exception_severity_enum as enum (
  'low',
  'medium',
  'high'
);

create type core.rating_direction_enum as enum (
  'requester_to_provider',
  'provider_to_requester'
);

create type core.rating_status_enum as enum (
  'submitted',
  'flagged',
  'under_review',
  'resolved',
  'hidden'
);

create type core.dispute_status_enum as enum (
  'open',
  'under_review',
  'upheld',
  'dismissed',
  'resolved'
);

create type core.channel_type_enum as enum (
  'announcements',
  'tips',
  'customer_issues',
  'general'
);

create type core.thread_status_enum as enum (
  'active',
  'locked',
  'archived',
  'removed'
);

create type core.report_reason_code_enum as enum (
  'abuse',
  'harassment',
  'spam',
  'privacy_pii',
  'misinformation',
  'retaliation',
  'other'
);

create type core.moderation_case_status_enum as enum (
  'open',
  'in_review',
  'actioned',
  'dismissed',
  'closed'
);

create type core.question_type_enum as enum (
  'single_select',
  'multi_select',
  'true_false'
);

create type core.difficulty_level_enum as enum (
  'easy',
  'medium',
  'hard'
);

create type core.progress_status_enum as enum (
  'not_started',
  'in_progress',
  'completed'
);

create type core.drill_mode_enum as enum (
  'practice',
  'review',
  'exam_sim'
);

create type core.review_outcome_enum as enum (
  'correct',
  'incorrect',
  'skipped'
);

create type core.notification_channel_enum as enum (
  'push',
  'email',
  'sms'
);

create type core.notification_priority_enum as enum (
  'low',
  'normal',
  'high',
  'urgent'
);

create type core.notification_status_enum as enum (
  'pending',
  'scheduled',
  'sent',
  'failed',
  'cancelled'
);
```

## Media enums

```sql
create type media.upload_purpose_enum as enum (
  'dossier_proof',
  'profile_logo',
  'profile_gallery',
  'community_attachment'
);

create type media.media_privacy_class_enum as enum (
  'public',
  'members_only',
  'private'
);

create type media.attachment_target_type_enum as enum (
  'coverage_dossier',
  'dossier_stop',
  'member_profile',
  'community_post'
);
```

---

# Auth Schema

## `auth.users`

```sql
create table auth.users (
  id uuid primary key default gen_random_uuid(),
  email citext not null,
  status auth.account_status_enum not null,
  display_name text null,
  phone_e164 text null,
  phone_verified_at timestamptz null,
  last_login_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint uq_users__email unique (email),
  constraint chk_users__phone_e164_format
    check (phone_e164 is null or phone_e164 ~ '^\+[1-9][0-9]{7,14}$')
);
```

Indexes:

```sql
create index idx_users__status on auth.users(status);
create index idx_users__deleted_at on auth.users(deleted_at);
```

## `auth.identities`

```sql
create table auth.identities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  provider auth.identity_provider_enum not null,
  provider_subject text not null,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_identities__users
    foreign key (user_id) references auth.users(id) on delete cascade,
  constraint uq_identities__provider_subject
    unique (provider, provider_subject)
);
```

Indexes:

```sql
create unique index uq_identities__user_provider
  on auth.identities(user_id, provider);

create unique index uq_identities__primary_per_user
  on auth.identities(user_id)
  where is_primary = true;
```

## `auth.password_credentials`

```sql
create table auth.password_credentials (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  password_hash text not null,
  password_algo text not null,
  password_set_at timestamptz not null,
  must_rotate boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_password_credentials__users
    foreign key (user_id) references auth.users(id) on delete cascade
);
```

Indexes:

```sql
create unique index uq_password_credentials__user_id
  on auth.password_credentials(user_id);
```

## `auth.sessions`

```sql
create table auth.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  refresh_token_hash text not null,
  device_label text null,
  user_agent text null,
  ip_address inet null,
  issued_at timestamptz not null,
  expires_at timestamptz not null,
  last_seen_at timestamptz null,
  revoked_at timestamptz null,
  revoke_reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_sessions__users
    foreign key (user_id) references auth.users(id) on delete cascade,
  constraint uq_sessions__refresh_token_hash unique (refresh_token_hash),
  constraint chk_sessions__time_window check (expires_at > issued_at)
);
```

Indexes:

```sql
create index idx_sessions__user_id on auth.sessions(user_id);
create index idx_sessions__expires_at on auth.sessions(expires_at);
create index idx_sessions__active_window
  on auth.sessions(user_id, expires_at)
  where revoked_at is null;
```

## `auth.email_verification_tokens`

```sql
create table auth.email_verification_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  token_hash text not null,
  status auth.token_status_enum not null,
  expires_at timestamptz not null,
  used_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint fk_email_verification_tokens__users
    foreign key (user_id) references auth.users(id) on delete cascade,
  constraint uq_email_verification_tokens__token_hash unique (token_hash)
);
```

## `auth.password_reset_tokens`

```sql
create table auth.password_reset_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  token_hash text not null,
  status auth.token_status_enum not null,
  expires_at timestamptz not null,
  used_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint fk_password_reset_tokens__users
    foreign key (user_id) references auth.users(id) on delete cascade,
  constraint uq_password_reset_tokens__token_hash unique (token_hash)
);
```

## `auth.invites`

`chapter_id` is a **logical** reference to `core.chapters(id)`, not a physical FK.
`suggested_chapter_role_code` is a Core-recognized role code, not a physical FK/enum dependency.

```sql
create table auth.invites (
  id uuid primary key default gen_random_uuid(),
  email citext not null,
  chapter_id uuid not null,
  invited_by_user_id uuid not null,
  suggested_chapter_role_code text not null default 'member',
  token_hash text not null,
  status auth.token_status_enum not null,
  expires_at timestamptz not null,
  accepted_user_id uuid null,
  accepted_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_invites__invited_by_user
    foreign key (invited_by_user_id) references auth.users(id),
  constraint fk_invites__accepted_user
    foreign key (accepted_user_id) references auth.users(id),
  constraint uq_invites__token_hash unique (token_hash)
);
```

Indexes:

```sql
create index idx_invites__email on auth.invites(email);
create index idx_invites__chapter_id on auth.invites(chapter_id);
create index idx_invites__status_expires_at on auth.invites(status, expires_at);
```

## `auth.permissions`

```sql
create table auth.permissions (
  code text primary key,
  scope auth.permission_scope_enum not null,
  service_owner text not null,
  description text not null,
  is_system boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

Indexes:

```sql
create index idx_permissions__scope
  on auth.permissions(scope);
```

## `auth.global_roles`

```sql
create table auth.global_roles (
  code auth.global_role_code_enum primary key,
  name text not null,
  description text null,
  is_system boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

## `auth.global_role_permissions`

```sql
create table auth.global_role_permissions (
  global_role_code auth.global_role_code_enum not null,
  permission_code text not null,
  created_at timestamptz not null default now(),
  constraint fk_global_role_permissions__global_roles
    foreign key (global_role_code) references auth.global_roles(code) on delete cascade,
  constraint fk_global_role_permissions__permissions
    foreign key (permission_code) references auth.permissions(code) on delete cascade,
  constraint uq_global_role_permissions__role_permission
    unique (global_role_code, permission_code)
);
```

Indexes:

```sql
create index idx_global_role_permissions__permission_code
  on auth.global_role_permissions(permission_code);
```

## `auth.user_global_role_assignments`

```sql
create table auth.user_global_role_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  global_role_code auth.global_role_code_enum not null,
  assigned_by_user_id uuid not null,
  starts_at timestamptz not null,
  ends_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_user_global_role_assignments__users
    foreign key (user_id) references auth.users(id) on delete cascade,
  constraint fk_user_global_role_assignments__assigned_by_user
    foreign key (assigned_by_user_id) references auth.users(id),
  constraint fk_user_global_role_assignments__global_roles
    foreign key (global_role_code) references auth.global_roles(code),
  constraint chk_user_global_role_assignments__time_window
    check (ends_at is null or ends_at > starts_at)
);
```

Indexes:

```sql
create unique index uq_user_global_role_assignments__active_role
  on auth.user_global_role_assignments(user_id, global_role_code)
  where ends_at is null;

create index idx_user_global_role_assignments__role_window
  on auth.user_global_role_assignments(global_role_code, ends_at);
```

---

# Core Schema

## `core.chapters`

```sql
create table core.chapters (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null,
  region_code text null,
  timezone text not null,
  status text not null,
  description text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_chapters__slug unique (slug)
);
```

## `core.chapter_policies`

```sql
create table core.chapter_policies (
  chapter_id uuid primary key,
  community_enabled boolean not null default true,
  general_chat_enabled boolean not null default false,
  leaderboard_enabled boolean not null default false,
  coverage_emergency_enabled boolean not null default true,
  weight_proximity numeric(5,2) not null default 0.50,
  weight_availability numeric(5,2) not null default 0.25,
  weight_specialty numeric(5,2) not null default 0.15,
  weight_reputation numeric(5,2) not null default 0.10,
  max_emergency_response_minutes integer not null default 15,
  proof_location_required boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_chapter_policies__chapters
    foreign key (chapter_id) references core.chapters(id) on delete cascade,
  constraint chk_chapter_policies__weight_range
    check (
      weight_proximity between 0 and 1 and
      weight_availability between 0 and 1 and
      weight_specialty between 0 and 1 and
      weight_reputation between 0 and 1
    ),
  constraint chk_chapter_policies__weight_sum
    check (round((weight_proximity + weight_availability + weight_specialty + weight_reputation)::numeric, 2) = 1.00)
);
```

## `core.chapter_memberships`

`user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.chapter_memberships (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null,
  user_id uuid not null,
  status core.membership_status_enum not null,
  member_since date null,
  joined_at timestamptz not null,
  left_at timestamptz null,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_chapter_memberships__chapters
    foreign key (chapter_id) references core.chapters(id),
  constraint chk_chapter_memberships__left_at
    check (
      left_at is null or status in ('inactive', 'suspended', 'removed')
    )
);
```

Indexes:

```sql
create index idx_chapter_memberships__chapter_status
  on core.chapter_memberships(chapter_id, status);

create index idx_chapter_memberships__user_status
  on core.chapter_memberships(user_id, status);

create unique index uq_chapter_memberships__active_membership
  on core.chapter_memberships(chapter_id, user_id)
  where status = 'active';

create unique index uq_chapter_memberships__primary_active_per_user
  on core.chapter_memberships(user_id)
  where is_primary = true and status = 'active';
```

## `core.chapter_role_assignments`

```sql
create table core.chapter_role_assignments (
  id uuid primary key default gen_random_uuid(),
  membership_id uuid not null,
  role core.chapter_role_enum not null,
  starts_at timestamptz not null,
  ends_at timestamptz null,
  assigned_by_user_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_chapter_role_assignments__memberships
    foreign key (membership_id) references core.chapter_memberships(id) on delete cascade,
  constraint chk_chapter_role_assignments__time_window
    check (ends_at is null or ends_at > starts_at)
);
```

Indexes:

```sql
create unique index uq_chapter_role_assignments__active_role
  on core.chapter_role_assignments(membership_id, role)
  where ends_at is null;
```

## `core.chapter_role_permissions`

`permission_code` is a logical reference to `auth.permissions(code)`.

```sql
create table core.chapter_role_permissions (
  role core.chapter_role_enum not null,
  permission_code text not null,
  created_at timestamptz not null default now(),
  constraint uq_chapter_role_permissions__role_permission
    unique (role, permission_code)
);
```

Indexes:

```sql
create index idx_chapter_role_permissions__permission_code
  on core.chapter_role_permissions(permission_code);
```

## `core.member_profiles`

`user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.member_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  business_name text not null,
  public_display_name text null,
  bio text null,
  years_experience integer null,
  website_url text null,
  phone_public_e164 text null,
  email_public citext null,
  profile_visibility core.profile_visibility_enum not null default 'draft',
  coverage_score_cached numeric(5,2) null,
  tier_code_cached text null,
  is_profile_complete boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_member_profiles__user_id unique (user_id),
  constraint chk_member_profiles__years_experience
    check (years_experience is null or years_experience >= 0),
  constraint chk_member_profiles__phone_public_e164
    check (phone_public_e164 is null or phone_public_e164 ~ '^\+[1-9][0-9]{7,14}$')
);
```

## `core.profile_service_areas`

If `postgis` is enabled, prefer `geography(point,4326)` for `center_point`.

```sql
create table core.profile_service_areas (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  label text not null,
  center_point geography(point,4326) null,
  radius_meters integer null,
  postal_codes text[] null,
  geometry_geojson jsonb null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_profile_service_areas__member_profiles
    foreign key (profile_id) references core.member_profiles(id) on delete cascade,
  constraint chk_profile_service_areas__radius_meters
    check (radius_meters is null or radius_meters > 0),
  constraint chk_profile_service_areas__shape_present
    check (
      radius_meters is not null or
      postal_codes is not null or
      geometry_geojson is not null
    )
);
```

## `core.profile_specialties`

```sql
create table core.profile_specialties (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  specialty_code text not null,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  constraint fk_profile_specialties__member_profiles
    foreign key (profile_id) references core.member_profiles(id) on delete cascade,
  constraint uq_profile_specialties__profile_specialty
    unique (profile_id, specialty_code)
);
```

## `core.profile_certifications`

```sql
create table core.profile_certifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  certification_code text not null,
  issuer_name text null,
  issued_on date null,
  expires_on date null,
  verification_url text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_profile_certifications__member_profiles
    foreign key (profile_id) references core.member_profiles(id) on delete cascade,
  constraint chk_profile_certifications__date_order
    check (issued_on is null or expires_on is null or expires_on >= issued_on)
);
```

## `core.notification_preferences`

`user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  event_code text not null,
  channel core.notification_channel_enum not null,
  enabled boolean not null default true,
  quiet_hours_start_local time null,
  quiet_hours_end_local time null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_notification_preferences__user_event_channel
    unique (user_id, event_code, channel)
);
```

## `core.coverage_requests`

`created_by_user_id` and `officer_override_user_id` are logical references to `auth.users(id)`.

```sql
create table core.coverage_requests (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null,
  requester_membership_id uuid not null,
  created_by_user_id uuid not null,
  mode core.coverage_mode_enum not null,
  status core.coverage_request_status_enum not null,
  service_date date not null,
  window_start_at timestamptz null,
  window_end_at timestamptz null,
  requested_stop_count integer not null default 0,
  location_context jsonb null,
  specialty_requirements text[] null,
  notes text null,
  officer_override_user_id uuid null,
  matched_at timestamptz null,
  closed_at timestamptz null,
  close_reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_coverage_requests__chapters
    foreign key (chapter_id) references core.chapters(id),
  constraint fk_coverage_requests__requester_membership
    foreign key (requester_membership_id) references core.chapter_memberships(id),
  constraint chk_coverage_requests__requested_stop_count
    check (requested_stop_count >= 0),
  constraint chk_coverage_requests__window
    check (window_end_at is null or window_start_at is null or window_end_at >= window_start_at)
);
```

Indexes:

```sql
create index idx_coverage_requests__chapter_status_date
  on core.coverage_requests(chapter_id, status, service_date);

create index idx_coverage_requests__requester_membership
  on core.coverage_requests(requester_membership_id);
```

## `core.coverage_candidates`

`candidate_user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.coverage_candidates (
  id uuid primary key default gen_random_uuid(),
  coverage_request_id uuid not null,
  candidate_user_id uuid not null,
  candidate_profile_id uuid not null,
  rank_score numeric(8,4) not null,
  score_breakdown jsonb not null,
  status core.candidate_status_enum not null,
  surfaced_at timestamptz null,
  responded_at timestamptz null,
  expires_at timestamptz null,
  ineligibility_reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_coverage_candidates__coverage_requests
    foreign key (coverage_request_id) references core.coverage_requests(id) on delete cascade,
  constraint fk_coverage_candidates__candidate_profiles
    foreign key (candidate_profile_id) references core.member_profiles(id),
  constraint uq_coverage_candidates__request_candidate
    unique (coverage_request_id, candidate_user_id)
);
```

Indexes:

```sql
create index idx_coverage_candidates__request_rank
  on core.coverage_candidates(coverage_request_id, rank_score desc);

create index idx_coverage_candidates__status
  on core.coverage_candidates(status);
```

## `core.coverage_matches`

```sql
create table core.coverage_matches (
  id uuid primary key default gen_random_uuid(),
  coverage_request_id uuid not null,
  coverage_candidate_id uuid not null,
  provider_membership_id uuid not null,
  status core.match_status_enum not null,
  accepted_at timestamptz not null,
  started_at timestamptz null,
  completed_at timestamptz null,
  closed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_coverage_matches__coverage_requests
    foreign key (coverage_request_id) references core.coverage_requests(id),
  constraint fk_coverage_matches__coverage_candidates
    foreign key (coverage_candidate_id) references core.coverage_candidates(id),
  constraint fk_coverage_matches__provider_memberships
    foreign key (provider_membership_id) references core.chapter_memberships(id),
  constraint uq_coverage_matches__coverage_request_id unique (coverage_request_id),
  constraint uq_coverage_matches__coverage_candidate_id unique (coverage_candidate_id),
  constraint chk_coverage_matches__completion_after_acceptance
    check (completed_at is null or completed_at >= accepted_at)
);
```

## `core.coverage_dossiers`

```sql
create table core.coverage_dossiers (
  id uuid primary key default gen_random_uuid(),
  coverage_match_id uuid not null,
  coverage_request_id uuid not null,
  requester_membership_id uuid not null,
  provider_membership_id uuid not null,
  status core.dossier_status_enum not null,
  route_notes text null,
  customer_contact_protocol text null,
  safety_notes text null,
  internal_handoff_notes text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz null,
  constraint fk_coverage_dossiers__coverage_matches
    foreign key (coverage_match_id) references core.coverage_matches(id),
  constraint fk_coverage_dossiers__coverage_requests
    foreign key (coverage_request_id) references core.coverage_requests(id),
  constraint fk_coverage_dossiers__requester_memberships
    foreign key (requester_membership_id) references core.chapter_memberships(id),
  constraint fk_coverage_dossiers__provider_memberships
    foreign key (provider_membership_id) references core.chapter_memberships(id),
  constraint uq_coverage_dossiers__coverage_match_id unique (coverage_match_id),
  constraint uq_coverage_dossiers__coverage_request_id unique (coverage_request_id)
);
```

## `core.dossier_stops`

```sql
create table core.dossier_stops (
  id uuid primary key default gen_random_uuid(),
  coverage_dossier_id uuid not null,
  sequence_number integer not null,
  customer_label text not null,
  service_address jsonb not null,
  contact_protocol text null,
  access_instructions text null,
  expected_tasks jsonb null,
  status core.stop_status_enum not null default 'pending',
  completed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_dossier_stops__coverage_dossiers
    foreign key (coverage_dossier_id) references core.coverage_dossiers(id) on delete cascade,
  constraint uq_dossier_stops__sequence
    unique (coverage_dossier_id, sequence_number),
  constraint chk_dossier_stops__sequence_number
    check (sequence_number > 0)
);
```

## `core.coverage_execution_events`

`actor_user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.coverage_execution_events (
  id uuid primary key default gen_random_uuid(),
  coverage_dossier_id uuid not null,
  dossier_stop_id uuid null,
  actor_user_id uuid not null,
  event_type text not null,
  occurred_at timestamptz not null,
  payload jsonb null,
  created_at timestamptz not null default now(),
  constraint fk_coverage_execution_events__coverage_dossiers
    foreign key (coverage_dossier_id) references core.coverage_dossiers(id) on delete cascade,
  constraint fk_coverage_execution_events__dossier_stops
    foreign key (dossier_stop_id) references core.dossier_stops(id) on delete set null
);
```

Indexes:

```sql
create index idx_coverage_execution_events__dossier_occurred_at
  on core.coverage_execution_events(coverage_dossier_id, occurred_at);
```

## `core.coverage_exceptions`

`reported_by_user_id` and `resolved_by_user_id` are logical references to `auth.users(id)`.

```sql
create table core.coverage_exceptions (
  id uuid primary key default gen_random_uuid(),
  coverage_dossier_id uuid not null,
  dossier_stop_id uuid null,
  reported_by_user_id uuid not null,
  type core.exception_type_enum not null,
  severity core.exception_severity_enum not null,
  description text not null,
  status text not null,
  resolved_by_user_id uuid null,
  resolved_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_coverage_exceptions__coverage_dossiers
    foreign key (coverage_dossier_id) references core.coverage_dossiers(id) on delete cascade,
  constraint fk_coverage_exceptions__dossier_stops
    foreign key (dossier_stop_id) references core.dossier_stops(id) on delete set null
);
```

## `core.ratings`

`reviewer_user_id` and `reviewee_user_id` are logical references to `auth.users(id)`.

```sql
create table core.ratings (
  id uuid primary key default gen_random_uuid(),
  coverage_match_id uuid not null,
  reviewer_user_id uuid not null,
  reviewee_user_id uuid not null,
  direction core.rating_direction_enum not null,
  overall_score smallint not null,
  communication_score smallint not null,
  service_quality_score smallint null,
  professionalism_score smallint null,
  handoff_quality_score smallint null,
  fairness_score smallint null,
  comment_text text null,
  status core.rating_status_enum not null default 'submitted',
  submitted_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_ratings__coverage_matches
    foreign key (coverage_match_id) references core.coverage_matches(id) on delete cascade,
  constraint uq_ratings__match_reviewer_direction
    unique (coverage_match_id, reviewer_user_id, direction),
  constraint chk_ratings__overall_score check (overall_score between 1 and 5),
  constraint chk_ratings__communication_score check (communication_score between 1 and 5),
  constraint chk_ratings__service_quality_score check (service_quality_score is null or service_quality_score between 1 and 5),
  constraint chk_ratings__professionalism_score check (professionalism_score is null or professionalism_score between 1 and 5),
  constraint chk_ratings__handoff_quality_score check (handoff_quality_score is null or handoff_quality_score between 1 and 5),
  constraint chk_ratings__fairness_score check (fairness_score is null or fairness_score between 1 and 5),
  constraint chk_ratings__direction_specific_fields
    check (
      (
        direction = 'requester_to_provider' and
        service_quality_score is not null and
        professionalism_score is not null
      ) or
      (
        direction = 'provider_to_requester' and
        handoff_quality_score is not null and
        fairness_score is not null
      )
    )
);
```

## `core.rating_disputes`

`opened_by_user_id` and `assigned_to_user_id` are logical references to `auth.users(id)`.

```sql
create table core.rating_disputes (
  id uuid primary key default gen_random_uuid(),
  rating_id uuid not null,
  opened_by_user_id uuid not null,
  reason_code core.report_reason_code_enum not null,
  description text null,
  status core.dispute_status_enum not null,
  assigned_to_user_id uuid null,
  resolution_code text null,
  resolution_notes text null,
  resolved_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_rating_disputes__ratings
    foreign key (rating_id) references core.ratings(id) on delete cascade
);
```

Indexes:

```sql
create unique index uq_rating_disputes__one_open_per_rating
  on core.rating_disputes(rating_id)
  where status in ('open', 'under_review');
```

## `core.reputation_summaries`

`user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.reputation_summaries (
  user_id uuid primary key,
  coverage_score numeric(5,2) not null,
  provisional boolean not null default true,
  provider_rating_count integer not null default 0,
  requester_rating_count integer not null default 0,
  total_completed_matches integer not null default 0,
  visible_badge_count integer not null default 0,
  last_recalculated_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_reputation_summaries__counts_non_negative
    check (
      provider_rating_count >= 0 and
      requester_rating_count >= 0 and
      total_completed_matches >= 0 and
      visible_badge_count >= 0
    )
);
```

## `core.tier_definitions`

```sql
create table core.tier_definitions (
  code text primary key,
  name text not null,
  sort_order integer not null,
  min_coverage_score numeric(5,2) not null,
  min_completed_matches integer not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_tier_definitions__sort_order unique (sort_order)
);
```

## `core.user_tier_assignments`

`user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.user_tier_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  tier_code text not null,
  status text not null,
  awarded_at timestamptz not null,
  frozen_at timestamptz null,
  demoted_at timestamptz null,
  reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_user_tier_assignments__tier_definitions
    foreign key (tier_code) references core.tier_definitions(code)
);
```

Indexes:

```sql
create unique index uq_user_tier_assignments__active_per_user
  on core.user_tier_assignments(user_id)
  where status = 'active';
```

## `core.community_channels`

```sql
create table core.community_channels (
  id uuid primary key default gen_random_uuid(),
  chapter_id uuid not null,
  type core.channel_type_enum not null,
  name text not null,
  description text null,
  is_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_community_channels__chapters
    foreign key (chapter_id) references core.chapters(id) on delete cascade,
  constraint uq_community_channels__chapter_type
    unique (chapter_id, type)
);
```

## `core.community_threads`

`created_by_user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.community_threads (
  id uuid primary key default gen_random_uuid(),
  community_channel_id uuid not null,
  chapter_id uuid not null,
  created_by_user_id uuid not null,
  title text not null,
  status core.thread_status_enum not null default 'active',
  is_pinned boolean not null default false,
  pinned_at timestamptz null,
  last_activity_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint fk_community_threads__community_channels
    foreign key (community_channel_id) references core.community_channels(id) on delete cascade,
  constraint fk_community_threads__chapters
    foreign key (chapter_id) references core.chapters(id)
);
```

Indexes:

```sql
create index idx_community_threads__chapter_last_activity
  on core.community_threads(chapter_id, last_activity_at desc);

create index idx_community_threads__channel_status
  on core.community_threads(community_channel_id, status);
```

## `core.community_posts`

`author_user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.community_posts (
  id uuid primary key default gen_random_uuid(),
  community_thread_id uuid not null,
  author_user_id uuid not null,
  reply_to_post_id uuid null,
  body_markdown text not null,
  body_text_search tsvector null,
  pii_flag text not null default 'none',
  status text not null default 'active',
  edited_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint fk_community_posts__community_threads
    foreign key (community_thread_id) references core.community_threads(id) on delete cascade,
  constraint fk_community_posts__reply_to_post
    foreign key (reply_to_post_id) references core.community_posts(id) on delete set null,
  constraint chk_community_posts__body_not_blank
    check (length(trim(body_markdown)) > 0)
);
```

Indexes:

```sql
create index idx_community_posts__thread_created_at
  on core.community_posts(community_thread_id, created_at);

create index idx_community_posts__body_text_search
  on core.community_posts using gin(body_text_search);
```

## `core.content_reports`

`reported_by_user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.content_reports (
  id uuid primary key default gen_random_uuid(),
  target_type text not null,
  target_id uuid not null,
  chapter_id uuid not null,
  reported_by_user_id uuid not null,
  reason_code core.report_reason_code_enum not null,
  notes text null,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_content_reports__chapters
    foreign key (chapter_id) references core.chapters(id)
);
```

Indexes:

```sql
create index idx_content_reports__target
  on core.content_reports(target_type, target_id);
```

## `core.moderation_cases`

`assigned_to_user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.moderation_cases (
  id uuid primary key default gen_random_uuid(),
  content_report_id uuid not null,
  target_type text not null,
  target_id uuid not null,
  chapter_id uuid not null,
  status core.moderation_case_status_enum not null,
  assigned_to_user_id uuid null,
  resolution_code text null,
  resolution_notes text null,
  closed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_moderation_cases__content_reports
    foreign key (content_report_id) references core.content_reports(id) on delete cascade,
  constraint fk_moderation_cases__chapters
    foreign key (chapter_id) references core.chapters(id)
);
```

## `core.moderation_actions`

`actor_user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  moderation_case_id uuid not null,
  actor_user_id uuid not null,
  action_type text not null,
  reason text null,
  created_at timestamptz not null default now(),
  constraint fk_moderation_actions__moderation_cases
    foreign key (moderation_case_id) references core.moderation_cases(id) on delete cascade
);
```

## `core.prep_modules`

```sql
create table core.prep_modules (
  id uuid primary key default gen_random_uuid(),
  slug text not null,
  title text not null,
  description text null,
  topic_code text not null,
  difficulty core.difficulty_level_enum null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_prep_modules__slug unique (slug)
);
```

## `core.prep_lessons`

```sql
create table core.prep_lessons (
  id uuid primary key default gen_random_uuid(),
  prep_module_id uuid not null,
  title text not null,
  order_index integer not null,
  estimated_minutes integer null,
  body_markdown text null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_prep_lessons__prep_modules
    foreign key (prep_module_id) references core.prep_modules(id) on delete cascade,
  constraint uq_prep_lessons__module_order
    unique (prep_module_id, order_index),
  constraint chk_prep_lessons__estimated_minutes
    check (estimated_minutes is null or estimated_minutes > 0)
);
```

## `core.prep_questions`

```sql
create table core.prep_questions (
  id uuid primary key default gen_random_uuid(),
  prep_module_id uuid not null,
  prep_lesson_id uuid null,
  question_type core.question_type_enum not null,
  difficulty core.difficulty_level_enum not null,
  stem_markdown text not null,
  explanation_markdown text not null,
  provenance_type text not null,
  provenance_notes text null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_prep_questions__prep_modules
    foreign key (prep_module_id) references core.prep_modules(id) on delete cascade,
  constraint fk_prep_questions__prep_lessons
    foreign key (prep_lesson_id) references core.prep_lessons(id) on delete set null
);
```

## `core.prep_question_options`

```sql
create table core.prep_question_options (
  id uuid primary key default gen_random_uuid(),
  prep_question_id uuid not null,
  label text not null,
  order_index integer not null,
  is_correct boolean not null,
  rationale_markdown text null,
  created_at timestamptz not null default now(),
  constraint fk_prep_question_options__prep_questions
    foreign key (prep_question_id) references core.prep_questions(id) on delete cascade,
  constraint uq_prep_question_options__question_order
    unique (prep_question_id, order_index)
);
```

## `core.curriculum_mappings`

```sql
create table core.curriculum_mappings (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  topic_code text not null,
  objective_code text null,
  weight numeric(5,2) null,
  created_at timestamptz not null default now(),
  constraint chk_curriculum_mappings__weight
    check (weight is null or weight >= 0)
);
```

Indexes:

```sql
create index idx_curriculum_mappings__entity
  on core.curriculum_mappings(entity_type, entity_id);
```

## `core.learner_progress`

`user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.learner_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  prep_module_id uuid not null,
  status core.progress_status_enum not null,
  mastery_score numeric(5,2) not null default 0,
  correct_count integer not null default 0,
  incorrect_count integer not null default 0,
  last_activity_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_learner_progress__prep_modules
    foreign key (prep_module_id) references core.prep_modules(id) on delete cascade,
  constraint uq_learner_progress__user_module
    unique (user_id, prep_module_id),
  constraint chk_learner_progress__counts_non_negative
    check (correct_count >= 0 and incorrect_count >= 0)
);
```

## `core.drill_sessions`

`user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.drill_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  mode core.drill_mode_enum not null,
  prep_module_id uuid null,
  started_at timestamptz not null,
  completed_at timestamptz null,
  total_questions integer not null default 0,
  correct_answers integer not null default 0,
  score_percent numeric(5,2) null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_drill_sessions__prep_modules
    foreign key (prep_module_id) references core.prep_modules(id) on delete set null,
  constraint chk_drill_sessions__time_window
    check (completed_at is null or completed_at >= started_at),
  constraint chk_drill_sessions__counts
    check (
      total_questions >= 0 and
      correct_answers >= 0 and
      correct_answers <= total_questions
    )
);
```

## `core.drill_answers`

```sql
create table core.drill_answers (
  id uuid primary key default gen_random_uuid(),
  drill_session_id uuid not null,
  prep_question_id uuid not null,
  selected_option_ids uuid[] not null,
  is_correct boolean not null,
  response_ms integer null,
  answered_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint fk_drill_answers__drill_sessions
    foreign key (drill_session_id) references core.drill_sessions(id) on delete cascade,
  constraint fk_drill_answers__prep_questions
    foreign key (prep_question_id) references core.prep_questions(id),
  constraint chk_drill_answers__response_ms
    check (response_ms is null or response_ms >= 0)
);
```

## `core.review_items`

`user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.review_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  prep_question_id uuid not null,
  source_drill_session_id uuid null,
  due_at timestamptz not null,
  ease_factor numeric(4,2) not null,
  interval_days integer not null,
  repetition_count integer not null default 0,
  last_outcome core.review_outcome_enum null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_review_items__prep_questions
    foreign key (prep_question_id) references core.prep_questions(id),
  constraint fk_review_items__source_drill_sessions
    foreign key (source_drill_session_id) references core.drill_sessions(id) on delete set null,
  constraint uq_review_items__user_question unique (user_id, prep_question_id),
  constraint chk_review_items__interval_days check (interval_days >= 0)
);
```

## `core.learning_badge_definitions`

```sql
create table core.learning_badge_definitions (
  code text primary key,
  name text not null,
  description text null,
  rule_type text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

## `core.user_learning_badges`

`user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.user_learning_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  badge_code text not null,
  awarded_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint fk_user_learning_badges__learning_badge_definitions
    foreign key (badge_code) references core.learning_badge_definitions(code),
  constraint uq_user_learning_badges__user_badge unique (user_id, badge_code)
);
```

## `core.notification_intents`

`user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.notification_intents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  event_code text not null,
  channel core.notification_channel_enum not null,
  priority core.notification_priority_enum not null default 'normal',
  status core.notification_status_enum not null default 'pending',
  dedupe_key text null,
  payload jsonb not null,
  scheduled_for timestamptz null,
  sent_at timestamptz null,
  failure_reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

Indexes:

```sql
create unique index uq_notification_intents__dedupe_key
  on core.notification_intents(dedupe_key)
  where dedupe_key is not null;

create index idx_notification_intents__status_scheduled_for
  on core.notification_intents(status, scheduled_for);
```

## `core.audit_events`

`actor_user_id` is a logical reference to `auth.users(id)`.

```sql
create table core.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid null,
  actor_type text not null,
  chapter_id uuid null,
  entity_type text not null,
  entity_id uuid not null,
  action text not null,
  request_id text null,
  ip_address inet null,
  before_state jsonb null,
  after_state jsonb null,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint fk_audit_events__chapters
    foreign key (chapter_id) references core.chapters(id) on delete set null
);
```

Indexes:

```sql
create index idx_audit_events__entity
  on core.audit_events(entity_type, entity_id, occurred_at desc);

create index idx_audit_events__chapter_occurred_at
  on core.audit_events(chapter_id, occurred_at desc);
```

---

# Media Schema

## `media.upload_intents`

`actor_user_id` is a logical reference to `auth.users(id)`.  
`target_id` is a logical reference to a Core entity selected by `target_type`.

```sql
create table media.upload_intents (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null,
  purpose media.upload_purpose_enum not null,
  target_type media.attachment_target_type_enum not null,
  target_id uuid not null,
  mime_whitelist text[] not null,
  max_bytes bigint not null,
  status text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_upload_intents__max_bytes check (max_bytes > 0)
);
```

Indexes:

```sql
create index idx_upload_intents__target
  on media.upload_intents(target_type, target_id, status);
```

## `media.media_objects`

`uploaded_by_user_id` is a logical reference to `auth.users(id)`.

```sql
create table media.media_objects (
  id uuid primary key default gen_random_uuid(),
  upload_intent_id uuid not null,
  storage_key text not null,
  bucket_name text not null,
  mime_type text not null,
  size_bytes bigint not null,
  checksum_sha256 text not null,
  width_px integer null,
  height_px integer null,
  captured_at timestamptz null,
  uploaded_by_user_id uuid not null,
  privacy_class media.media_privacy_class_enum not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint fk_media_objects__upload_intents
    foreign key (upload_intent_id) references media.upload_intents(id),
  constraint uq_media_objects__storage_key unique (storage_key),
  constraint chk_media_objects__size_bytes check (size_bytes > 0),
  constraint chk_media_objects__dimensions
    check (
      (width_px is null and height_px is null) or
      (width_px is not null and height_px is not null and width_px > 0 and height_px > 0)
    )
);
```

## `media.media_attachments`

`target_id` is a logical reference to a Core entity selected by `target_type`.

```sql
create table media.media_attachments (
  id uuid primary key default gen_random_uuid(),
  media_object_id uuid not null,
  target_type media.attachment_target_type_enum not null,
  target_id uuid not null,
  usage_code text not null,
  sort_order integer null,
  created_at timestamptz not null default now(),
  constraint fk_media_attachments__media_objects
    foreign key (media_object_id) references media.media_objects(id) on delete cascade
);
```

Indexes:

```sql
create index idx_media_attachments__target
  on media.media_attachments(target_type, target_id);

create unique index uq_media_attachments__media_target_usage
  on media.media_attachments(media_object_id, target_type, target_id, usage_code);
```

## `media.media_access_logs`

`viewer_user_id` is a logical reference to `auth.users(id)`.

```sql
create table media.media_access_logs (
  id uuid primary key default gen_random_uuid(),
  media_object_id uuid not null,
  viewer_user_id uuid null,
  access_type text not null,
  request_id text null,
  accessed_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint fk_media_access_logs__media_objects
    foreign key (media_object_id) references media.media_objects(id) on delete cascade
);
```

Indexes:

```sql
create index idx_media_access_logs__media_object_accessed_at
  on media.media_access_logs(media_object_id, accessed_at desc);
```

---

# Foreign Key Strategy Summary

## Physical FKs to keep

Use physical foreign keys for relationships within the same service schema, including:

- `auth.identities.user_id -> auth.users.id`
- `auth.sessions.user_id -> auth.users.id`
- `auth.global_role_permissions.global_role_code -> auth.global_roles.code`
- `auth.global_role_permissions.permission_code -> auth.permissions.code`
- `auth.user_global_role_assignments.user_id -> auth.users.id`
- `auth.user_global_role_assignments.assigned_by_user_id -> auth.users.id`
- `auth.user_global_role_assignments.global_role_code -> auth.global_roles.code`
- `core.chapter_memberships.chapter_id -> core.chapters.id`
- `core.coverage_candidates.coverage_request_id -> core.coverage_requests.id`
- `core.coverage_matches.coverage_candidate_id -> core.coverage_candidates.id`
- `core.coverage_dossiers.coverage_match_id -> core.coverage_matches.id`
- `core.dossier_stops.coverage_dossier_id -> core.coverage_dossiers.id`
- `core.ratings.coverage_match_id -> core.coverage_matches.id`
- `core.community_posts.community_thread_id -> core.community_threads.id`
- `core.prep_question_options.prep_question_id -> core.prep_questions.id`
- `media.media_objects.upload_intent_id -> media.upload_intents.id`
- `media.media_attachments.media_object_id -> media.media_objects.id`

## Logical references only

Do not create DB-level foreign keys for:

- `core.*.user_id -> auth.users.id`
- `auth.invites.chapter_id -> core.chapters.id`
- `core.chapter_role_permissions.permission_code -> auth.permissions.code`
- `media.upload_intents.target_id -> core polymorphic target`
- `media.media_attachments.target_id -> core polymorphic target`

These should be enforced by:

- API validation
- service authorization checks
- consistency jobs where useful

---

# Suggested Migration Order

1. Bootstrap
   - create schemas
   - create extensions
   - create enum types

2. Auth tables
   - `auth.users`
   - `auth.identities`
   - `auth.password_credentials`
   - `auth.sessions`
   - `auth.email_verification_tokens`
   - `auth.password_reset_tokens`
   - `auth.invites`
   - `auth.permissions`
   - `auth.global_roles`
   - `auth.global_role_permissions`
   - `auth.user_global_role_assignments`

3. Core foundations
   - `core.chapters`
   - `core.chapter_policies`
   - `core.chapter_memberships`
   - `core.chapter_role_assignments`
   - `core.chapter_role_permissions`
   - `core.member_profiles`
   - `core.profile_service_areas`
   - `core.profile_specialties`
   - `core.profile_certifications`
   - `core.notification_preferences`

4. Media foundations
   - `media.upload_intents`
   - `media.media_objects`
   - `media.media_attachments`
   - `media.media_access_logs`

5. Coverage domain
   - `core.coverage_requests`
   - `core.coverage_candidates`
   - `core.coverage_matches`
   - `core.coverage_dossiers`
   - `core.dossier_stops`
   - `core.coverage_execution_events`
   - `core.coverage_exceptions`

6. Ratings and trust
   - `core.ratings`
   - `core.rating_disputes`
   - `core.reputation_summaries`
   - `core.tier_definitions`
   - `core.user_tier_assignments`

7. Community
   - `core.community_channels`
   - `core.community_threads`
   - `core.community_posts`
   - `core.content_reports`
   - `core.moderation_cases`
   - `core.moderation_actions`

8. Prep Lab
   - `core.prep_modules`
   - `core.prep_lessons`
   - `core.prep_questions`
   - `core.prep_question_options`
   - `core.curriculum_mappings`
   - `core.learner_progress`
   - `core.drill_sessions`
   - `core.drill_answers`
   - `core.review_items`
   - `core.learning_badge_definitions`
   - `core.user_learning_badges`

9. Cross-cutting
   - `core.notification_intents`
   - `core.audit_events`

---

# Open Decisions Before Writing Migrations

- whether to use one Postgres database with service schemas or separate DBs from day one
- whether `postgis` is in MVP or deferred
- whether chapter role codes should remain fixed enums or later become table-driven custom chapter roles
- whether global permissions should be embedded directly in gateway-trusted claims or resolved lazily for some admin flows
- whether chapter-scoped authorization should always resolve from Core state or allow a short-lived cached permission snapshot
- whether `status text` fields in `core.coverage_exceptions`, `core.user_tier_assignments`, `core.content_reports`, `media.upload_intents`, and `media.media_access_logs` should become stricter enums in v1
- whether to materialize `core.reputation_summaries` synchronously or via background jobs
- whether to partition `core.audit_events` and `media.media_access_logs` once production volume is known

---

# Recommendation

The first migration pass should prioritize:

- all enum types
- auth foundations
- chapter + membership foundations
- profile tables
- coverage tables

That gives the team enough schema to build:

- login and onboarding
- chapter membership
- member profiles
- the initial CoverageMatch flow

without overcommitting early to later community or learning details.
