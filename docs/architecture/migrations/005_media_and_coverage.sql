-- 005_media_and_coverage.sql
-- Media-owned tables plus the CoverageMatch, dossier, ratings, and trust domains.

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
