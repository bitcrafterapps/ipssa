-- 003_auth.sql
-- Auth-owned tables, including global RBAC primitives.
-- Cross-service references remain logical UUID refs.

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
