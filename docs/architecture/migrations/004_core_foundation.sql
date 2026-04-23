-- 004_core_foundation.sql
-- Core platform primitives: chapters, memberships, chapter-scoped RBAC, profiles, and profile metadata.

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
