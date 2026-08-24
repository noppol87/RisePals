ALTER TABLE "user_accounts" ADD COLUMN "deletion_request_id" uuid;--> statement-breakpoint
ALTER TABLE "user_accounts" ADD COLUMN "deletion_requested_at" timestamp with time zone;--> statement-breakpoint
ALTER TABLE "user_accounts" ADD CONSTRAINT "user_accounts_deletion_request_id_unique" UNIQUE("deletion_request_id");--> statement-breakpoint
ALTER TABLE "user_accounts" ADD CONSTRAINT "user_accounts_deletion_request_state_check" CHECK (("user_accounts"."status" IN ('deletion_pending', 'deleted') AND "user_accounts"."deletion_request_id" IS NOT NULL AND "user_accounts"."deletion_requested_at" IS NOT NULL) OR ("user_accounts"."status" NOT IN ('deletion_pending', 'deleted') AND "user_accounts"."deletion_request_id" IS NULL AND "user_accounts"."deletion_requested_at" IS NULL));
--> statement-breakpoint

REVOKE DELETE ON TABLE "public"."user_accounts", "public"."external_identities" FROM "rise_pals_app";
REVOKE DELETE ON TABLE "public"."user_accounts" FROM "rise_pals_identity_resolver";
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_account_erasure_state"()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public, rise_pals_private
AS $$
BEGIN
  IF current_user = 'rise_pals_privacy_operator' THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Account tombstones cannot be deleted outside the privacy maintenance boundary.'
      USING ERRCODE = '42501';
  END IF;

  IF NEW.status IN ('deletion_pending', 'deleted')
     OR NEW.deletion_request_id IS NOT NULL
     OR NEW.deletion_requested_at IS NOT NULL
     OR NEW.deleted_at IS NOT NULL THEN
    RAISE EXCEPTION 'Account erasure lifecycle is operator-only.'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_account_erasure_state"() FROM PUBLIC;
--> statement-breakpoint
CREATE TRIGGER "user_accounts_erasure_guard"
  BEFORE UPDATE OR DELETE ON "public"."user_accounts"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_account_erasure_state"();
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public, rise_pals_private
AS $$
BEGIN
  IF current_user <> 'rise_pals_privacy_operator'
     OR rise_pals_private.current_app_user_id() IS NULL THEN
    RAISE EXCEPTION 'Private history is immutable outside the privacy maintenance boundary.'
      USING ERRCODE = '42501';
  END IF;

  RETURN OLD;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"() FROM PUBLIC;
--> statement-breakpoint

DROP TRIGGER "consent_records_append_only" ON "public"."consent_records";
CREATE TRIGGER "consent_records_append_only"
  BEFORE UPDATE ON "public"."consent_records"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."reject_consent_mutation"();
CREATE TRIGGER "consent_records_privacy_delete"
  BEFORE DELETE ON "public"."consent_records"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
--> statement-breakpoint

DROP TRIGGER "assessment_sessions_guard" ON "public"."assessment_sessions";
CREATE TRIGGER "assessment_sessions_guard"
  BEFORE INSERT OR UPDATE ON "public"."assessment_sessions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_assessment_session"();
CREATE TRIGGER "assessment_sessions_privacy_delete"
  BEFORE DELETE ON "public"."assessment_sessions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "assessment_responses_guard" ON "public"."assessment_responses";
CREATE TRIGGER "assessment_responses_guard"
  BEFORE INSERT OR UPDATE ON "public"."assessment_responses"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_assessment_response"();
CREATE TRIGGER "assessment_responses_privacy_delete"
  BEFORE DELETE ON "public"."assessment_responses"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "assessment_responses_exactly_one_active" ON "public"."assessment_responses";
CREATE CONSTRAINT TRIGGER "assessment_responses_exactly_one_active"
  AFTER INSERT OR UPDATE ON "public"."assessment_responses"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_one_active_assessment_response"();
--> statement-breakpoint

DROP TRIGGER "scoring_runs_immutable" ON "public"."scoring_runs";
CREATE TRIGGER "scoring_runs_immutable"
  BEFORE UPDATE ON "public"."scoring_runs"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_derived_history_immutable"();
CREATE TRIGGER "scoring_runs_privacy_delete"
  BEFORE DELETE ON "public"."scoring_runs"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "competency_scores_immutable" ON "public"."competency_scores";
CREATE TRIGGER "competency_scores_immutable"
  BEFORE UPDATE ON "public"."competency_scores"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_derived_history_immutable"();
CREATE TRIGGER "competency_scores_privacy_delete"
  BEFORE DELETE ON "public"."competency_scores"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "multiplier_observations_immutable" ON "public"."multiplier_observations";
CREATE TRIGGER "multiplier_observations_immutable"
  BEFORE UPDATE ON "public"."multiplier_observations"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_derived_history_immutable"();
CREATE TRIGGER "multiplier_observations_privacy_delete"
  BEFORE DELETE ON "public"."multiplier_observations"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "score_explanations_immutable" ON "public"."score_explanations";
CREATE TRIGGER "score_explanations_immutable"
  BEFORE UPDATE ON "public"."score_explanations"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_derived_history_immutable"();
CREATE TRIGGER "score_explanations_privacy_delete"
  BEFORE DELETE ON "public"."score_explanations"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "priority_recommendations_immutable" ON "public"."priority_recommendations";
CREATE TRIGGER "priority_recommendations_immutable"
  BEFORE UPDATE ON "public"."priority_recommendations"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_derived_history_immutable"();
CREATE TRIGGER "priority_recommendations_privacy_delete"
  BEFORE DELETE ON "public"."priority_recommendations"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
--> statement-breakpoint

DROP TRIGGER "lesson_attempts_guard" ON "public"."lesson_attempts";
CREATE TRIGGER "lesson_attempts_guard"
  BEFORE INSERT OR UPDATE ON "public"."lesson_attempts"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_lesson_attempt"();
CREATE TRIGGER "lesson_attempts_privacy_delete"
  BEFORE DELETE ON "public"."lesson_attempts"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "practice_attempts_guard" ON "public"."practice_attempts";
CREATE TRIGGER "practice_attempts_guard"
  BEFORE INSERT OR UPDATE ON "public"."practice_attempts"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_practice_attempt"();
CREATE TRIGGER "practice_attempts_privacy_delete"
  BEFORE DELETE ON "public"."practice_attempts"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "learning_progress_events_guard" ON "public"."learning_progress_events";
CREATE TRIGGER "learning_progress_events_guard"
  BEFORE INSERT OR UPDATE ON "public"."learning_progress_events"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_learning_progress_event"();
CREATE TRIGGER "learning_progress_events_privacy_delete"
  BEFORE DELETE ON "public"."learning_progress_events"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "lesson_attempts_progress_complete" ON "public"."lesson_attempts";
CREATE CONSTRAINT TRIGGER "lesson_attempts_progress_complete"
  AFTER INSERT OR UPDATE ON "public"."lesson_attempts"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_learning_progress_complete"();
DROP TRIGGER "practice_attempts_progress_complete" ON "public"."practice_attempts";
CREATE CONSTRAINT TRIGGER "practice_attempts_progress_complete"
  AFTER INSERT OR UPDATE ON "public"."practice_attempts"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_learning_progress_complete"();
DROP TRIGGER "learning_progress_events_progress_complete" ON "public"."learning_progress_events";
CREATE CONSTRAINT TRIGGER "learning_progress_events_progress_complete"
  AFTER INSERT OR UPDATE ON "public"."learning_progress_events"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_learning_progress_complete"();
--> statement-breakpoint

DROP TRIGGER "evidence_artifacts_guard" ON "public"."evidence_artifacts";
CREATE TRIGGER "evidence_artifacts_guard"
  BEFORE INSERT OR UPDATE ON "public"."evidence_artifacts"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_evidence_artifact"();
CREATE TRIGGER "evidence_artifacts_privacy_delete"
  BEFORE DELETE ON "public"."evidence_artifacts"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "evidence_artifact_revisions_guard" ON "public"."evidence_artifact_revisions";
CREATE TRIGGER "evidence_artifact_revisions_guard"
  BEFORE INSERT OR UPDATE ON "public"."evidence_artifact_revisions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_evidence_artifact_revision"();
CREATE TRIGGER "evidence_artifact_revisions_privacy_delete"
  BEFORE DELETE ON "public"."evidence_artifact_revisions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "evidence_competency_links_guard" ON "public"."evidence_competency_links";
CREATE TRIGGER "evidence_competency_links_guard"
  BEFORE INSERT OR UPDATE ON "public"."evidence_competency_links"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_evidence_competency_link"();
CREATE TRIGGER "evidence_competency_links_privacy_delete"
  BEFORE DELETE ON "public"."evidence_competency_links"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "evidence_artifacts_competency_complete" ON "public"."evidence_artifacts";
CREATE CONSTRAINT TRIGGER "evidence_artifacts_competency_complete"
  AFTER INSERT OR UPDATE ON "public"."evidence_artifacts"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_evidence_competency_link_complete"();
DROP TRIGGER "evidence_competency_links_complete" ON "public"."evidence_competency_links";
CREATE CONSTRAINT TRIGGER "evidence_competency_links_complete"
  AFTER INSERT OR UPDATE ON "public"."evidence_competency_links"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_evidence_competency_link_complete"();
--> statement-breakpoint

DROP TRIGGER "measurement_subjects_append_only" ON "public"."measurement_subjects";
CREATE TRIGGER "measurement_subjects_append_only"
  BEFORE UPDATE ON "public"."measurement_subjects"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."reject_measurement_history_mutation"();
CREATE TRIGGER "measurement_subjects_privacy_delete"
  BEFORE DELETE ON "public"."measurement_subjects"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "product_events_append_only" ON "public"."product_events";
CREATE TRIGGER "product_events_append_only"
  BEFORE UPDATE ON "public"."product_events"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."reject_measurement_history_mutation"();
CREATE TRIGGER "product_events_privacy_delete"
  BEFORE DELETE ON "public"."product_events"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
DROP TRIGGER "error_occurrences_append_only" ON "public"."error_occurrences";
CREATE TRIGGER "error_occurrences_append_only"
  BEFORE UPDATE ON "public"."error_occurrences"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."reject_measurement_history_mutation"();
CREATE TRIGGER "error_occurrences_privacy_delete"
  BEFORE DELETE ON "public"."error_occurrences"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."permit_privacy_erasure_delete"();
--> statement-breakpoint

GRANT USAGE, CREATE ON SCHEMA "rise_pals_private" TO "rise_pals_privacy_operator";
GRANT USAGE ON SCHEMA "public" TO "rise_pals_privacy_operator";
GRANT EXECUTE ON FUNCTION "rise_pals_private"."current_app_user_id"() TO "rise_pals_privacy_operator";
GRANT SELECT ON TABLE "public"."user_accounts" TO "rise_pals_privacy_operator";
GRANT UPDATE ("status", "updated_at", "last_seen_at", "deletion_request_id", "deletion_requested_at", "deleted_at") ON TABLE "public"."user_accounts" TO "rise_pals_privacy_operator";
GRANT SELECT, DELETE ON TABLE
  "public"."external_identities",
  "public"."consent_records",
  "public"."user_profiles",
  "public"."assessment_sessions",
  "public"."assessment_responses",
  "public"."scoring_runs",
  "public"."competency_scores",
  "public"."multiplier_observations",
  "public"."score_explanations",
  "public"."priority_recommendations",
  "public"."lesson_attempts",
  "public"."practice_attempts",
  "public"."learning_progress_events",
  "public"."evidence_artifacts",
  "public"."evidence_artifact_revisions",
  "public"."evidence_competency_links",
  "public"."measurement_subjects",
  "public"."product_events",
  "public"."error_occurrences"
TO "rise_pals_privacy_operator";
--> statement-breakpoint

CREATE POLICY "user_accounts_privacy_select_policy" ON "public"."user_accounts"
  FOR SELECT TO "rise_pals_privacy_operator"
  USING (id = rise_pals_private.current_app_user_id());
CREATE POLICY "user_accounts_privacy_update_policy" ON "public"."user_accounts"
  FOR UPDATE TO "rise_pals_privacy_operator"
  USING (id = rise_pals_private.current_app_user_id())
  WITH CHECK (id = rise_pals_private.current_app_user_id());
CREATE POLICY "external_identities_privacy_policy" ON "public"."external_identities"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "consent_records_privacy_policy" ON "public"."consent_records"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "user_profiles_privacy_policy" ON "public"."user_profiles"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "assessment_sessions_privacy_policy" ON "public"."assessment_sessions"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "assessment_responses_privacy_policy" ON "public"."assessment_responses"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (EXISTS (
    SELECT 1 FROM public.assessment_sessions AS owner_session
    WHERE owner_session.id = assessment_responses.session_id
      AND owner_session.user_id = rise_pals_private.current_app_user_id()
  ));
CREATE POLICY "scoring_runs_privacy_policy" ON "public"."scoring_runs"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "competency_scores_privacy_policy" ON "public"."competency_scores"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "multiplier_observations_privacy_policy" ON "public"."multiplier_observations"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "score_explanations_privacy_policy" ON "public"."score_explanations"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "priority_recommendations_privacy_policy" ON "public"."priority_recommendations"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "lesson_attempts_privacy_policy" ON "public"."lesson_attempts"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "practice_attempts_privacy_policy" ON "public"."practice_attempts"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "learning_progress_events_privacy_policy" ON "public"."learning_progress_events"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "evidence_artifacts_privacy_policy" ON "public"."evidence_artifacts"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "evidence_artifact_revisions_privacy_policy" ON "public"."evidence_artifact_revisions"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "evidence_competency_links_privacy_policy" ON "public"."evidence_competency_links"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "measurement_subjects_privacy_policy" ON "public"."measurement_subjects"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (user_id = rise_pals_private.current_app_user_id());
CREATE POLICY "product_events_privacy_policy" ON "public"."product_events"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (EXISTS (
    SELECT 1 FROM public.measurement_subjects AS owner_subject
    WHERE owner_subject.id = product_events.measurement_subject_id
      AND owner_subject.user_id = rise_pals_private.current_app_user_id()
  ));
CREATE POLICY "error_occurrences_privacy_policy" ON "public"."error_occurrences"
  FOR ALL TO "rise_pals_privacy_operator"
  USING (EXISTS (
    SELECT 1 FROM public.measurement_subjects AS owner_subject
    WHERE owner_subject.id = error_occurrences.measurement_subject_id
      AND owner_subject.user_id = rise_pals_private.current_app_user_id()
  ));
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."request_owner_erasure"(
  target_owner_id uuid,
  target_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, rise_pals_private
AS $$
DECLARE
  account_row public.user_accounts%ROWTYPE;
BEGIN
  IF target_owner_id IS NULL OR target_request_id IS NULL
     OR rise_pals_private.current_app_user_id() IS DISTINCT FROM target_owner_id THEN
    RAISE EXCEPTION 'Invalid owner-erasure request context.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO account_row
  FROM public.user_accounts
  WHERE id = target_owner_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Owner account is unavailable.' USING ERRCODE = 'P0002';
  END IF;

  IF account_row.status IN ('deletion_pending', 'deleted') THEN
    IF account_row.deletion_request_id IS DISTINCT FROM target_request_id THEN
      RAISE EXCEPTION 'Deletion request conflicts with the existing request.' USING ERRCODE = '23505';
    END IF;

    RETURN jsonb_build_object(
      'contractVersion', 'rise-pals-alpha-erasure-v1@1.0.0',
      'state', account_row.status,
      'replayed', true
    );
  END IF;

  UPDATE public.user_accounts
  SET status = 'deletion_pending',
      deletion_request_id = target_request_id,
      deletion_requested_at = clock_timestamp(),
      updated_at = clock_timestamp()
  WHERE id = target_owner_id;

  RETURN jsonb_build_object(
    'contractVersion', 'rise-pals-alpha-erasure-v1@1.0.0',
    'state', 'deletion_pending',
    'replayed', false
  );
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."request_owner_erasure"(uuid, uuid) FROM PUBLIC;
ALTER FUNCTION "rise_pals_private"."request_owner_erasure"(uuid, uuid) OWNER TO "rise_pals_privacy_operator";
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."erase_owner_private_data"(
  target_owner_id uuid,
  target_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, rise_pals_private
AS $$
DECLARE
  account_row public.user_accounts%ROWTYPE;
  affected integer;
  total_deleted integer := 0;
BEGIN
  IF target_owner_id IS NULL OR target_request_id IS NULL
     OR rise_pals_private.current_app_user_id() IS DISTINCT FROM target_owner_id THEN
    RAISE EXCEPTION 'Invalid owner-erasure execution context.' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO account_row
  FROM public.user_accounts
  WHERE id = target_owner_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Owner account is unavailable.' USING ERRCODE = 'P0002';
  END IF;

  IF account_row.deletion_request_id IS DISTINCT FROM target_request_id THEN
    RAISE EXCEPTION 'Deletion request does not match the pending request.' USING ERRCODE = '23505';
  END IF;

  IF account_row.status = 'deleted' THEN
    RETURN jsonb_build_object(
      'contractVersion', 'rise-pals-alpha-erasure-v1@1.0.0',
      'state', 'deleted',
      'replayed', true,
      'deletedRows', 0
    );
  END IF;

  IF account_row.status <> 'deletion_pending' THEN
    RAISE EXCEPTION 'Owner account is not pending deletion.' USING ERRCODE = '55000';
  END IF;

  DELETE FROM public.error_occurrences
  WHERE measurement_subject_id IN (
    SELECT id FROM public.measurement_subjects WHERE user_id = target_owner_id
  );
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.product_events
  WHERE measurement_subject_id IN (
    SELECT id FROM public.measurement_subjects WHERE user_id = target_owner_id
  );
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.measurement_subjects WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;

  DELETE FROM public.priority_recommendations WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.score_explanations WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.multiplier_observations WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.competency_scores WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.scoring_runs WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;

  DELETE FROM public.assessment_responses
  WHERE session_id IN (
    SELECT id FROM public.assessment_sessions WHERE user_id = target_owner_id
  );
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.assessment_sessions WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;

  DELETE FROM public.evidence_competency_links WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.evidence_artifact_revisions WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.evidence_artifacts WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;

  DELETE FROM public.learning_progress_events WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.practice_attempts WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.lesson_attempts WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;

  DELETE FROM public.user_profiles WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.consent_records WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;
  DELETE FROM public.external_identities WHERE user_id = target_owner_id;
  GET DIAGNOSTICS affected = ROW_COUNT; total_deleted := total_deleted + affected;

  UPDATE public.user_accounts
  SET status = 'deleted',
      last_seen_at = NULL,
      deleted_at = clock_timestamp(),
      updated_at = clock_timestamp()
  WHERE id = target_owner_id;

  RETURN jsonb_build_object(
    'contractVersion', 'rise-pals-alpha-erasure-v1@1.0.0',
    'state', 'deleted',
    'replayed', false,
    'deletedRows', total_deleted
  );
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."erase_owner_private_data"(uuid, uuid) FROM PUBLIC;
ALTER FUNCTION "rise_pals_private"."erase_owner_private_data"(uuid, uuid) OWNER TO "rise_pals_privacy_operator";
REVOKE CREATE ON SCHEMA "rise_pals_private" FROM "rise_pals_privacy_operator";
