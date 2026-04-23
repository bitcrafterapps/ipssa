-- IPSSA initial PostgreSQL DDL
-- Purpose:
--   First-pass, migration-ready schema for the IPSSA platform.
-- Notes:
--   - Uses one Postgres database with service-owned schemas: auth, core, media
--   - Keeps physical foreign keys within service-owned schemas
--   - Uses logical UUID references across service boundaries
--   - Uses portable lat/lng service-area fields instead of requiring PostGIS on day one

begin;

create extension if not exists pgcrypto;
create extension if not exists citext;
create extension if not exists pg_trgm;

create schema if not exists auth;
create schema if not exists core;
create schema if not exists media;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =========================================================
-- Enums
-- =========================================================

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

create type core.membership_status_enum as enum (
  'pending',
  'active',
  'inactive',
  'suspended',
  'removed'
);

create type core.chapter_status_enum as enum (
  'active',
  'inactive',
  'archived'
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

create type core.coverage_exception_status_enum as enum (
  'open',
  'acknowledged',
  'resolved',
  'closed'
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

create type core.user_tier_status_enum as enum (
  'active',
  'frozen',
  'demoted',
  'expired'
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

create type core.community_post_status_enum as enum (
  'active',
  'hidden',
  'removed'
);

create type core.pii_flag_enum as enum (
  'none',
  'suspected',
  'confirmed'
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

create type core.content_report_status_enum as enum (
  'open',
  'in_review',
  'resolved',
  'dismissed'
);

create type core.moderation_case_status_enum as enum (
  'open',
  'in_review',
  'actioned',
  'dismissed',
  'closed'
);

create type core.moderation_action_type_enum as enum (
  'hide',
  'remove',
  'lock',
  'warn',
  'restore',
  'escalate'
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

create type media.upload_intent_status_enum as enum (
  'pending',
  'authorized',
  'consumed',
  'expired',
  'cancelled'
);

create type media.media_access_type_enum as enum (
  'signed_url',
  'stream',
  'thumbnail'
);

-- =========================================================
-- Auth schema
-- =========================================================

create table auth.users (
  id uuid primary key default gen_random_uuid(),
  email citext not null unique,
  status auth.account_status_enum not null,
  display_name text null,
  phone_e164 text null,
  phone_verified_at timestamptz null,
  last_login_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz null,
  constraint chk_users__phone_e164
    check (phone_e164 is null or phone_e164 ~ '^\+[1-9][0-9]{7,14}$')
);

create index idx_users__status on auth.users(status);
create index idx_users__deleted_at on auth.users(deleted_at);

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

create unique index uq_identities__user_provider
  on auth.identities(user_id, provider);

create unique index uq_identities__primary_per_user
  on auth.identities(user_id)
  where is_primary = true;

create table auth.password_credentials (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique,
  password_hash text not null,
  password_algo text not null,
  password_set_at timestamptz not null,
  must_rotate boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_password_credentials__users
    foreign key (user_id) references auth.users(id) on delete cascade
);

create table auth.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  refresh_token_hash text not null unique,
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
  constraint chk_sessions__time_window
    check (expires_at > issued_at)
);

create index idx_sessions__user_id on auth.sessions(user_id);
create index idx_sessions__expires_at on auth.sessions(expires_at);
create index idx_sessions__active_window
  on auth.sessions(user_id, expires_at)
  where revoked_at is null;

create table auth.email_verification_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  token_hash text not null unique,
  status auth.token_status_enum not null,
  expires_at timestamptz not null,
  used_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint fk_email_verification_tokens__users
    foreign key (user_id) references auth.users(id) on delete cascade
);

create index idx_email_verification_tokens__user_status
  on auth.email_verification_tokens(user_id, status);

create table auth.password_reset_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  token_hash text not null unique,
  status auth.token_status_enum not null,
  expires_at timestamptz not null,
  used_at timestamptz null,
  created_at timestamptz not null default now(),
  constraint fk_password_reset_tokens__users
    foreign key (user_id) references auth.users(id) on delete cascade
);

create index idx_password_reset_tokens__user_status
  on auth.password_reset_tokens(user_id, status);

create table auth.invites (
  id uuid primary key default gen_random_uuid(),
  email citext not null,
  chapter_id uuid not null,
  invited_by_user_id uuid not null,
  suggested_chapter_role_code text not null default 'member',
  token_hash text not null unique,
  status auth.token_status_enum not null,
  expires_at timestamptz not null,
  accepted_user_id uuid null,
  accepted_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_invites__invited_by_user
    foreign key (invited_by_user_id) references auth.users(id),
  constraint fk_invites__accepted_user
    foreign key (accepted_user_id) references auth.users(id)
);

create index idx_invites__email on auth.invites(email);
create index idx_invites__chapter_id on auth.invites(chapter_id);
create index idx_invites__status_expires_at on auth.invites(status, expires_at);

create table auth.permissions (
  code text primary key,
  scope auth.permission_scope_enum not null,
  service_owner text not null,
  description text not null,
  is_system boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_permissions__scope
  on auth.permissions(scope);

create table auth.global_roles (
  code auth.global_role_code_enum primary key,
  name text not null,
  description text null,
  is_system boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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

create index idx_global_role_permissions__permission_code
  on auth.global_role_permissions(permission_code);

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

create unique index uq_user_global_role_assignments__active_role
  on auth.user_global_role_assignments(user_id, global_role_code)
  where ends_at is null;

create index idx_user_global_role_assignments__role_window
  on auth.user_global_role_assignments(global_role_code, ends_at);

-- =========================================================
-- Core schema
-- =========================================================

create table core.chapters (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  region_code text null,
  timezone text not null,
  status core.chapter_status_enum not null default 'active',
  description text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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
  constraint chk_chapter_policies__weights_in_range
    check (
      weight_proximity between 0 and 1 and
      weight_availability between 0 and 1 and
      weight_specialty between 0 and 1 and
      weight_reputation between 0 and 1
    ),
  constraint chk_chapter_policies__weight_sum
    check (
      round((weight_proximity + weight_availability + weight_specialty + weight_reputation)::numeric, 2) = 1.00
    )
);

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
    check (left_at is null or status in ('inactive', 'suspended', 'removed'))
);

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

create unique index uq_chapter_role_assignments__active_role
  on core.chapter_role_assignments(membership_id, role)
  where ends_at is null;

create table core.chapter_role_permissions (
  role core.chapter_role_enum not null,
  permission_code text not null,
  created_at timestamptz not null default now(),
  constraint uq_chapter_role_permissions__role_permission
    unique (role, permission_code)
);

create index idx_chapter_role_permissions__permission_code
  on core.chapter_role_permissions(permission_code);

create table core.member_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique,
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
  constraint chk_member_profiles__years_experience
    check (years_experience is null or years_experience >= 0),
  constraint chk_member_profiles__phone_public_e164
    check (phone_public_e164 is null or phone_public_e164 ~ '^\+[1-9][0-9]{7,14}$')
);

create table core.profile_service_areas (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  label text not null,
  center_lat numeric(9,6) null,
  center_lng numeric(9,6) null,
  radius_meters integer null,
  postal_codes text[] null,
  geometry_geojson jsonb null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_profile_service_areas__member_profiles
    foreign key (profile_id) references core.member_profiles(id) on delete cascade,
  constraint chk_profile_service_areas__radius
    check (radius_meters is null or radius_meters > 0),
  constraint chk_profile_service_areas__lat_lng_pair
    check (
      (center_lat is null and center_lng is null) or
      (center_lat is not null and center_lng is not null)
    ),
  constraint chk_profile_service_areas__lat_range
    check (center_lat is null or center_lat between -90 and 90),
  constraint chk_profile_service_areas__lng_range
    check (center_lng is null or center_lng between -180 and 180),
  constraint chk_profile_service_areas__shape_present
    check (
      radius_meters is not null or
      postal_codes is not null or
      geometry_geojson is not null or
      (center_lat is not null and center_lng is not null)
    )
);

create index idx_profile_service_areas__profile_id
  on core.profile_service_areas(profile_id);

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

create unique index uq_profile_specialties__primary_specialty
  on core.profile_specialties(profile_id)
  where is_primary = true;

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
  constraint fk_coverage_requests__requester_memberships
    foreign key (requester_membership_id) references core.chapter_memberships(id),
  constraint chk_coverage_requests__requested_stop_count
    check (requested_stop_count >= 0),
  constraint chk_coverage_requests__window
    check (window_end_at is null or window_start_at is null or window_end_at >= window_start_at)
);

create index idx_coverage_requests__chapter_status_date
  on core.coverage_requests(chapter_id, status, service_date);

create index idx_coverage_requests__requester_membership
  on core.coverage_requests(requester_membership_id);

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

create index idx_coverage_candidates__request_rank
  on core.coverage_candidates(coverage_request_id, rank_score desc);

create index idx_coverage_candidates__status
  on core.coverage_candidates(status);

create table core.coverage_matches (
  id uuid primary key default gen_random_uuid(),
  coverage_request_id uuid not null unique,
  coverage_candidate_id uuid not null unique,
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
  constraint chk_coverage_matches__completion_after_acceptance
    check (completed_at is null or completed_at >= accepted_at)
);

create table core.coverage_dossiers (
  id uuid primary key default gen_random_uuid(),
  coverage_match_id uuid not null unique,
  coverage_request_id uuid not null unique,
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
    foreign key (provider_membership_id) references core.chapter_memberships(id)
);

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

create index idx_coverage_execution_events__dossier_occurred_at
  on core.coverage_execution_events(coverage_dossier_id, occurred_at);

create table core.coverage_exceptions (
  id uuid primary key default gen_random_uuid(),
  coverage_dossier_id uuid not null,
  dossier_stop_id uuid null,
  reported_by_user_id uuid not null,
  type core.exception_type_enum not null,
  severity core.exception_severity_enum not null,
  description text not null,
  status core.coverage_exception_status_enum not null default 'open',
  resolved_by_user_id uuid null,
  resolved_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_coverage_exceptions__coverage_dossiers
    foreign key (coverage_dossier_id) references core.coverage_dossiers(id) on delete cascade,
  constraint fk_coverage_exceptions__dossier_stops
    foreign key (dossier_stop_id) references core.dossier_stops(id) on delete set null
);

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
  constraint chk_ratings__overall_score
    check (overall_score between 1 and 5),
  constraint chk_ratings__communication_score
    check (communication_score between 1 and 5),
  constraint chk_ratings__service_quality_score
    check (service_quality_score is null or service_quality_score between 1 and 5),
  constraint chk_ratings__professionalism_score
    check (professionalism_score is null or professionalism_score between 1 and 5),
  constraint chk_ratings__handoff_quality_score
    check (handoff_quality_score is null or handoff_quality_score between 1 and 5),
  constraint chk_ratings__fairness_score
    check (fairness_score is null or fairness_score between 1 and 5),
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

create index idx_ratings__reviewee_status
  on core.ratings(reviewee_user_id, status);

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

create unique index uq_rating_disputes__open_per_rating
  on core.rating_disputes(rating_id)
  where status in ('open', 'under_review');

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
  constraint chk_reputation_summaries__coverage_score_non_negative
    check (coverage_score >= 0),
  constraint chk_reputation_summaries__counts_non_negative
    check (
      provider_rating_count >= 0 and
      requester_rating_count >= 0 and
      total_completed_matches >= 0 and
      visible_badge_count >= 0
    )
);

create table core.tier_definitions (
  code text primary key,
  name text not null,
  sort_order integer not null unique,
  min_coverage_score numeric(5,2) not null,
  min_completed_matches integer not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table core.user_tier_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  tier_code text not null,
  status core.user_tier_status_enum not null,
  awarded_at timestamptz not null,
  frozen_at timestamptz null,
  demoted_at timestamptz null,
  reason text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_user_tier_assignments__tier_definitions
    foreign key (tier_code) references core.tier_definitions(code)
);

create unique index uq_user_tier_assignments__active_per_user
  on core.user_tier_assignments(user_id)
  where status = 'active';

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

create index idx_community_threads__chapter_last_activity
  on core.community_threads(chapter_id, last_activity_at desc);

create index idx_community_threads__channel_status
  on core.community_threads(community_channel_id, status);

create table core.community_posts (
  id uuid primary key default gen_random_uuid(),
  community_thread_id uuid not null,
  author_user_id uuid not null,
  reply_to_post_id uuid null,
  body_markdown text not null,
  body_text_search tsvector generated always as (
    to_tsvector('english', coalesce(body_markdown, ''))
  ) stored,
  pii_flag core.pii_flag_enum not null default 'none',
  status core.community_post_status_enum not null default 'active',
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

create index idx_community_posts__thread_created_at
  on core.community_posts(community_thread_id, created_at);

create index idx_community_posts__body_text_search
  on core.community_posts using gin(body_text_search);

create table core.content_reports (
  id uuid primary key default gen_random_uuid(),
  target_type text not null,
  target_id uuid not null,
  chapter_id uuid not null,
  reported_by_user_id uuid not null,
  reason_code core.report_reason_code_enum not null,
  notes text null,
  status core.content_report_status_enum not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint fk_content_reports__chapters
    foreign key (chapter_id) references core.chapters(id)
);

create index idx_content_reports__target
  on core.content_reports(target_type, target_id);

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

create table core.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  moderation_case_id uuid not null,
  actor_user_id uuid not null,
  action_type core.moderation_action_type_enum not null,
  reason text null,
  created_at timestamptz not null default now(),
  constraint fk_moderation_actions__moderation_cases
    foreign key (moderation_case_id) references core.moderation_cases(id) on delete cascade
);

create table core.prep_modules (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  description text null,
  topic_code text not null,
  difficulty core.difficulty_level_enum null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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

create index idx_curriculum_mappings__entity
  on core.curriculum_mappings(entity_type, entity_id);

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
  constraint chk_learner_progress__mastery_score
    check (mastery_score >= 0 and mastery_score <= 100),
  constraint chk_learner_progress__counts_non_negative
    check (correct_count >= 0 and incorrect_count >= 0)
);

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
  constraint chk_drill_answers__selected_option_ids
    check (cardinality(selected_option_ids) > 0),
  constraint chk_drill_answers__response_ms
    check (response_ms is null or response_ms >= 0)
);

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
  constraint uq_review_items__user_question
    unique (user_id, prep_question_id),
  constraint chk_review_items__ease_factor
    check (ease_factor > 0),
  constraint chk_review_items__interval_days
    check (interval_days >= 0)
);

create index idx_review_items__user_due_at
  on core.review_items(user_id, due_at);

create table core.learning_badge_definitions (
  code text primary key,
  name text not null,
  description text null,
  rule_type text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table core.user_learning_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  badge_code text not null,
  awarded_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint fk_user_learning_badges__learning_badge_definitions
    foreign key (badge_code) references core.learning_badge_definitions(code),
  constraint uq_user_learning_badges__user_badge
    unique (user_id, badge_code)
);

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

create unique index uq_notification_intents__dedupe_key
  on core.notification_intents(dedupe_key)
  where dedupe_key is not null;

create index idx_notification_intents__status_scheduled_for
  on core.notification_intents(status, scheduled_for);

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

create index idx_audit_events__entity
  on core.audit_events(entity_type, entity_id, occurred_at desc);

create index idx_audit_events__chapter_occurred_at
  on core.audit_events(chapter_id, occurred_at desc);

-- =========================================================
-- Media schema
-- =========================================================

create table media.upload_intents (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null,
  purpose media.upload_purpose_enum not null,
  target_type media.attachment_target_type_enum not null,
  target_id uuid not null,
  mime_whitelist text[] not null,
  max_bytes bigint not null,
  status media.upload_intent_status_enum not null default 'pending',
  expires_at timestamptz not null,
  consumed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint chk_upload_intents__mime_whitelist_non_empty
    check (cardinality(mime_whitelist) > 0),
  constraint chk_upload_intents__max_bytes
    check (max_bytes > 0)
);

create index idx_upload_intents__target
  on media.upload_intents(target_type, target_id, status);

create table media.media_objects (
  id uuid primary key default gen_random_uuid(),
  upload_intent_id uuid not null,
  storage_key text not null unique,
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
  constraint chk_media_objects__size_bytes
    check (size_bytes > 0),
  constraint chk_media_objects__dimensions
    check (
      (width_px is null and height_px is null) or
      (width_px is not null and height_px is not null and width_px > 0 and height_px > 0)
    )
);

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

create index idx_media_attachments__target
  on media.media_attachments(target_type, target_id);

create unique index uq_media_attachments__media_target_usage
  on media.media_attachments(media_object_id, target_type, target_id, usage_code);

create table media.media_access_logs (
  id uuid primary key default gen_random_uuid(),
  media_object_id uuid not null,
  viewer_user_id uuid null,
  access_type media.media_access_type_enum not null,
  request_id text null,
  accessed_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint fk_media_access_logs__media_objects
    foreign key (media_object_id) references media.media_objects(id) on delete cascade
);

create index idx_media_access_logs__media_object_accessed_at
  on media.media_access_logs(media_object_id, accessed_at desc);

-- =========================================================
-- Updated_at triggers
-- =========================================================

create trigger trg_users__updated_at
before update on auth.users
for each row execute function public.set_updated_at();

create trigger trg_identities__updated_at
before update on auth.identities
for each row execute function public.set_updated_at();

create trigger trg_password_credentials__updated_at
before update on auth.password_credentials
for each row execute function public.set_updated_at();

create trigger trg_sessions__updated_at
before update on auth.sessions
for each row execute function public.set_updated_at();

create trigger trg_invites__updated_at
before update on auth.invites
for each row execute function public.set_updated_at();

create trigger trg_permissions__updated_at
before update on auth.permissions
for each row execute function public.set_updated_at();

create trigger trg_global_roles__updated_at
before update on auth.global_roles
for each row execute function public.set_updated_at();

create trigger trg_user_global_role_assignments__updated_at
before update on auth.user_global_role_assignments
for each row execute function public.set_updated_at();

create trigger trg_chapters__updated_at
before update on core.chapters
for each row execute function public.set_updated_at();

create trigger trg_chapter_policies__updated_at
before update on core.chapter_policies
for each row execute function public.set_updated_at();

create trigger trg_chapter_memberships__updated_at
before update on core.chapter_memberships
for each row execute function public.set_updated_at();

create trigger trg_chapter_role_assignments__updated_at
before update on core.chapter_role_assignments
for each row execute function public.set_updated_at();

create trigger trg_member_profiles__updated_at
before update on core.member_profiles
for each row execute function public.set_updated_at();

create trigger trg_profile_service_areas__updated_at
before update on core.profile_service_areas
for each row execute function public.set_updated_at();

create trigger trg_profile_certifications__updated_at
before update on core.profile_certifications
for each row execute function public.set_updated_at();

create trigger trg_notification_preferences__updated_at
before update on core.notification_preferences
for each row execute function public.set_updated_at();

create trigger trg_coverage_requests__updated_at
before update on core.coverage_requests
for each row execute function public.set_updated_at();

create trigger trg_coverage_candidates__updated_at
before update on core.coverage_candidates
for each row execute function public.set_updated_at();

create trigger trg_coverage_matches__updated_at
before update on core.coverage_matches
for each row execute function public.set_updated_at();

create trigger trg_coverage_dossiers__updated_at
before update on core.coverage_dossiers
for each row execute function public.set_updated_at();

create trigger trg_dossier_stops__updated_at
before update on core.dossier_stops
for each row execute function public.set_updated_at();

create trigger trg_coverage_exceptions__updated_at
before update on core.coverage_exceptions
for each row execute function public.set_updated_at();

create trigger trg_ratings__updated_at
before update on core.ratings
for each row execute function public.set_updated_at();

create trigger trg_rating_disputes__updated_at
before update on core.rating_disputes
for each row execute function public.set_updated_at();

create trigger trg_reputation_summaries__updated_at
before update on core.reputation_summaries
for each row execute function public.set_updated_at();

create trigger trg_tier_definitions__updated_at
before update on core.tier_definitions
for each row execute function public.set_updated_at();

create trigger trg_user_tier_assignments__updated_at
before update on core.user_tier_assignments
for each row execute function public.set_updated_at();

create trigger trg_community_channels__updated_at
before update on core.community_channels
for each row execute function public.set_updated_at();

create trigger trg_community_threads__updated_at
before update on core.community_threads
for each row execute function public.set_updated_at();

create trigger trg_community_posts__updated_at
before update on core.community_posts
for each row execute function public.set_updated_at();

create trigger trg_content_reports__updated_at
before update on core.content_reports
for each row execute function public.set_updated_at();

create trigger trg_moderation_cases__updated_at
before update on core.moderation_cases
for each row execute function public.set_updated_at();

create trigger trg_prep_modules__updated_at
before update on core.prep_modules
for each row execute function public.set_updated_at();

create trigger trg_prep_lessons__updated_at
before update on core.prep_lessons
for each row execute function public.set_updated_at();

create trigger trg_prep_questions__updated_at
before update on core.prep_questions
for each row execute function public.set_updated_at();

create trigger trg_learner_progress__updated_at
before update on core.learner_progress
for each row execute function public.set_updated_at();

create trigger trg_drill_sessions__updated_at
before update on core.drill_sessions
for each row execute function public.set_updated_at();

create trigger trg_review_items__updated_at
before update on core.review_items
for each row execute function public.set_updated_at();

create trigger trg_learning_badge_definitions__updated_at
before update on core.learning_badge_definitions
for each row execute function public.set_updated_at();

create trigger trg_notification_intents__updated_at
before update on core.notification_intents
for each row execute function public.set_updated_at();

create trigger trg_upload_intents__updated_at
before update on media.upload_intents
for each row execute function public.set_updated_at();

create trigger trg_media_objects__updated_at
before update on media.media_objects
for each row execute function public.set_updated_at();

commit;
