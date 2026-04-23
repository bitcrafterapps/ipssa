-- 007_updated_at_triggers.sql
-- Attach the shared updated_at trigger to mutable tables that include updated_at.

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
