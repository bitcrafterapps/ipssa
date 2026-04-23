-- 006_community_learning_and_ops.sql
-- Community, Prep Lab, notifications, and audit tables.

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
