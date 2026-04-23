-- 002_enums.sql
-- Shared enum types used by auth, core, and media schemas.

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
