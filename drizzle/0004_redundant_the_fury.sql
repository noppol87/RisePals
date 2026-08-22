CREATE TYPE "public"."learning_progress_event_kind" AS ENUM('lesson_started', 'practice_evaluated', 'practice_demonstrated');--> statement-breakpoint
CREATE TYPE "public"."lesson_attempt_status" AS ENUM('in_progress', 'demonstrated');--> statement-breakpoint
CREATE TYPE "public"."practice_attempt_status" AS ENUM('draft', 'evaluated');--> statement-breakpoint
CREATE TABLE "learning_progress_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"lesson_attempt_id" uuid NOT NULL,
	"practice_attempt_id" uuid,
	"event_kind" "learning_progress_event_kind" NOT NULL,
	"event_schema_version" text NOT NULL,
	"source_mutation_id" uuid NOT NULL,
	"occurred_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "learning_progress_events_schema_check" CHECK ("learning_progress_events"."event_schema_version" = 'learning-progress-event-v1'),
	CONSTRAINT "learning_progress_events_relationship_check" CHECK (("learning_progress_events"."event_kind" = 'lesson_started' AND "learning_progress_events"."practice_attempt_id" IS NULL) OR ("learning_progress_events"."event_kind" IN ('practice_evaluated', 'practice_demonstrated') AND "learning_progress_events"."practice_attempt_id" IS NOT NULL))
);
--> statement-breakpoint
CREATE TABLE "lesson_attempts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"consent_record_id" uuid NOT NULL,
	"lesson_key" text NOT NULL,
	"lesson_version_id" text NOT NULL,
	"lesson_version" text NOT NULL,
	"lesson_digest" text NOT NULL,
	"practice_id" text NOT NULL,
	"practice_version" text NOT NULL,
	"rubric_version_id" text NOT NULL,
	"rubric_version" text NOT NULL,
	"evaluation_contract_version_id" text NOT NULL,
	"start_mutation_id" uuid NOT NULL,
	"status" "lesson_attempt_status" DEFAULT 'in_progress' NOT NULL,
	"started_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_meaningful_activity_at" timestamp with time zone DEFAULT now() NOT NULL,
	"demonstrated_at" timestamp with time zone,
	CONSTRAINT "lesson_attempts_id_user_unique" UNIQUE("id","user_id"),
	CONSTRAINT "lesson_attempts_identity_check" CHECK ("lesson_attempts"."lesson_key" = 'source-verification-practice' AND "lesson_attempts"."lesson_version_id" = 'lesson-source-verification-practice-v1' AND "lesson_attempts"."lesson_version" = '1.0.0' AND "lesson_attempts"."lesson_digest" = '51903ea9e6053a1102b4d60ad072c9a1dcde26a90d6a0ca7ae36cba8a6995e91'),
	CONSTRAINT "lesson_attempts_compatibility_check" CHECK ("lesson_attempts"."practice_id" = 'source-verification-decision-v1' AND "lesson_attempts"."practice_version" = '1.0.0' AND "lesson_attempts"."rubric_version_id" = 'source-verification-rubric-v1' AND "lesson_attempts"."rubric_version" = '1.0.0' AND "lesson_attempts"."evaluation_contract_version_id" = 'source-verification-evaluation-v1'),
	CONSTRAINT "lesson_attempts_status_timestamp_check" CHECK (("lesson_attempts"."status" = 'in_progress' AND "lesson_attempts"."demonstrated_at" IS NULL) OR ("lesson_attempts"."status" = 'demonstrated' AND "lesson_attempts"."demonstrated_at" IS NOT NULL)),
	CONSTRAINT "lesson_attempts_activity_time_check" CHECK ("lesson_attempts"."last_meaningful_activity_at" >= "lesson_attempts"."started_at" AND ("lesson_attempts"."demonstrated_at" IS NULL OR "lesson_attempts"."demonstrated_at" >= "lesson_attempts"."started_at"))
);
--> statement-breakpoint
CREATE TABLE "practice_attempts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"lesson_attempt_id" uuid NOT NULL,
	"revision" integer NOT NULL,
	"supersedes_practice_attempt_id" uuid,
	"status" "practice_attempt_status" NOT NULL,
	"response_payload" jsonb NOT NULL,
	"practice_id" text NOT NULL,
	"practice_version" text NOT NULL,
	"rubric_version_id" text NOT NULL,
	"rubric_version" text NOT NULL,
	"evaluation_contract_version_id" text NOT NULL,
	"criterion_results" jsonb,
	"demonstrated" boolean,
	"client_mutation_id" uuid NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "practice_attempts_id_owner_lesson_unique" UNIQUE("id","user_id","lesson_attempt_id"),
	CONSTRAINT "practice_attempts_revision_positive" CHECK ("practice_attempts"."revision" > 0),
	CONSTRAINT "practice_attempts_supersession_shape_check" CHECK (("practice_attempts"."revision" = 1 AND "practice_attempts"."supersedes_practice_attempt_id" IS NULL) OR ("practice_attempts"."revision" > 1 AND "practice_attempts"."supersedes_practice_attempt_id" IS NOT NULL)),
	CONSTRAINT "practice_attempts_response_json_check" CHECK (rise_pals_private.is_versioned_json_object("response_payload")),
	CONSTRAINT "practice_attempts_compatibility_check" CHECK ("practice_attempts"."practice_id" = 'source-verification-decision-v1' AND "practice_attempts"."practice_version" = '1.0.0' AND "practice_attempts"."rubric_version_id" = 'source-verification-rubric-v1' AND "practice_attempts"."rubric_version" = '1.0.0' AND "practice_attempts"."evaluation_contract_version_id" = 'source-verification-evaluation-v1'),
	CONSTRAINT "practice_attempts_evaluation_shape_check" CHECK (("practice_attempts"."status" = 'draft' AND "practice_attempts"."criterion_results" IS NULL AND "practice_attempts"."demonstrated" IS NULL) OR ("practice_attempts"."status" = 'evaluated' AND "practice_attempts"."criterion_results" IS NOT NULL AND "practice_attempts"."demonstrated" IS NOT NULL AND rise_pals_private.is_versioned_json_object("practice_attempts"."criterion_results")))
);
--> statement-breakpoint
ALTER TABLE "learning_progress_events" ADD CONSTRAINT "learning_progress_events_lesson_owner_fk" FOREIGN KEY ("lesson_attempt_id","user_id") REFERENCES "public"."lesson_attempts"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "learning_progress_events" ADD CONSTRAINT "learning_progress_events_practice_owner_lesson_fk" FOREIGN KEY ("practice_attempt_id","user_id","lesson_attempt_id") REFERENCES "public"."practice_attempts"("id","user_id","lesson_attempt_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "lesson_attempts" ADD CONSTRAINT "lesson_attempts_user_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_accounts"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "lesson_attempts" ADD CONSTRAINT "lesson_attempts_consent_owner_fk" FOREIGN KEY ("consent_record_id","user_id") REFERENCES "public"."consent_records"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "practice_attempts" ADD CONSTRAINT "practice_attempts_lesson_owner_fk" FOREIGN KEY ("lesson_attempt_id","user_id") REFERENCES "public"."lesson_attempts"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "practice_attempts" ADD CONSTRAINT "practice_attempts_supersedes_owner_lesson_fk" FOREIGN KEY ("supersedes_practice_attempt_id","user_id","lesson_attempt_id") REFERENCES "public"."practice_attempts"("id","user_id","lesson_attempt_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
CREATE UNIQUE INDEX "learning_progress_events_source_unique" ON "learning_progress_events" USING btree ("lesson_attempt_id","event_kind","source_mutation_id");--> statement-breakpoint
CREATE UNIQUE INDEX "learning_progress_events_one_started_per_lesson" ON "learning_progress_events" USING btree ("lesson_attempt_id","event_kind") WHERE "learning_progress_events"."event_kind" = 'lesson_started';--> statement-breakpoint
CREATE UNIQUE INDEX "learning_progress_events_practice_kind_unique" ON "learning_progress_events" USING btree ("practice_attempt_id","event_kind") WHERE "learning_progress_events"."practice_attempt_id" IS NOT NULL;--> statement-breakpoint
CREATE INDEX "learning_progress_events_owner_occurred_idx" ON "learning_progress_events" USING btree ("user_id","occurred_at");--> statement-breakpoint
CREATE UNIQUE INDEX "lesson_attempts_owner_lesson_identity_unique" ON "lesson_attempts" USING btree ("user_id","lesson_key","lesson_version");--> statement-breakpoint
CREATE UNIQUE INDEX "lesson_attempts_owner_start_mutation_unique" ON "lesson_attempts" USING btree ("user_id","start_mutation_id");--> statement-breakpoint
CREATE INDEX "lesson_attempts_user_activity_idx" ON "lesson_attempts" USING btree ("user_id","last_meaningful_activity_at");--> statement-breakpoint
CREATE UNIQUE INDEX "practice_attempts_lesson_revision_unique" ON "practice_attempts" USING btree ("lesson_attempt_id","revision");--> statement-breakpoint
CREATE UNIQUE INDEX "practice_attempts_lesson_mutation_unique" ON "practice_attempts" USING btree ("lesson_attempt_id","client_mutation_id");--> statement-breakpoint
CREATE INDEX "practice_attempts_owner_created_idx" ON "practice_attempts" USING btree ("user_id","created_at");
--> statement-breakpoint
ALTER TABLE "lesson_attempts" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "lesson_attempts" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "practice_attempts" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "practice_attempts" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "learning_progress_events" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "learning_progress_events" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint

CREATE POLICY "lesson_attempts_owner_select_policy" ON "lesson_attempts"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "lesson_attempts_owner_insert_policy" ON "lesson_attempts"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "lesson_attempts_owner_update_policy" ON "lesson_attempts"
  FOR UPDATE TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  )
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "practice_attempts_owner_select_policy" ON "practice_attempts"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "practice_attempts_owner_insert_policy" ON "practice_attempts"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "learning_progress_events_owner_select_policy" ON "learning_progress_events"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "learning_progress_events_owner_insert_policy" ON "learning_progress_events"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint

GRANT USAGE ON TYPE "lesson_attempt_status", "practice_attempt_status", "learning_progress_event_kind"
  TO "rise_pals_app";
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "lesson_attempts" TO "rise_pals_app";
--> statement-breakpoint
GRANT UPDATE ("status", "last_meaningful_activity_at", "demonstrated_at")
  ON TABLE "lesson_attempts" TO "rise_pals_app";
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "practice_attempts" TO "rise_pals_app";
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "learning_progress_events" TO "rise_pals_app";
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."source_verification_option_meets"(
  target_criterion_id text,
  target_option_id text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
STRICT
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
  SELECT CASE
    WHEN target_criterion_id = 'evidence-traceability'
      AND target_option_id = 'trace-claim-to-source-map' THEN true
    WHEN target_criterion_id = 'evidence-traceability'
      AND target_option_id IN ('trace-trust-ai-link-list', 'trace-remove-source-notes') THEN false
    WHEN target_criterion_id = 'claim-source-fit'
      AND target_option_id = 'fit-narrow-to-supported-teams' THEN true
    WHEN target_criterion_id = 'claim-source-fit'
      AND target_option_id IN ('fit-keep-all-team-claim', 'fit-convert-to-broad-average') THEN false
    WHEN target_criterion_id = 'safe-next-action'
      AND target_option_id = 'safe-hold-and-resolve-gaps' THEN true
    WHEN target_criterion_id = 'safe-next-action'
      AND target_option_id IN ('safe-publish-with-small-note', 'safe-ask-ai-for-confidence') THEN false
    ELSE NULL
  END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."source_verification_option_meets"(text, text)
  FROM PUBLIC;
--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."source_verification_option_meets"(text, text)
  TO "rise_pals_app";
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."assert_source_verification_practice_payload"(
  target_payload jsonb,
  target_status practice_attempt_status,
  target_results jsonb,
  target_demonstrated boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  selection_count integer;
  criterion_count integer;
  ordered_ranks integer[];
  sorted_ranks integer[];
  result_count integer;
  expected_demonstrated boolean;
BEGIN
  IF jsonb_typeof(target_payload) <> 'object'
    OR target_payload->>'schemaVersion' <> 'source-verification-practice-response-v1'
    OR jsonb_typeof(target_payload->'selections') <> 'array'
    OR (SELECT count(*) FROM jsonb_object_keys(target_payload)) <> 2 THEN
    RAISE EXCEPTION 'Practice response payload is invalid.';
  END IF;

  SELECT count(*)::integer,
         count(DISTINCT selection->>'criterionId')::integer,
         array_agg(
           CASE selection->>'criterionId'
             WHEN 'evidence-traceability' THEN 1
             WHEN 'claim-source-fit' THEN 2
             WHEN 'safe-next-action' THEN 3
           END
           ORDER BY ordinal
         ),
         array_agg(
           CASE selection->>'criterionId'
             WHEN 'evidence-traceability' THEN 1
             WHEN 'claim-source-fit' THEN 2
             WHEN 'safe-next-action' THEN 3
           END
           ORDER BY CASE selection->>'criterionId'
             WHEN 'evidence-traceability' THEN 1
             WHEN 'claim-source-fit' THEN 2
             WHEN 'safe-next-action' THEN 3
           END
         )
    INTO selection_count, criterion_count, ordered_ranks, sorted_ranks
  FROM jsonb_array_elements(target_payload->'selections') WITH ORDINALITY AS entry(selection, ordinal);

  IF selection_count > 3 OR selection_count <> criterion_count
    OR ordered_ranks IS DISTINCT FROM sorted_ranks
    OR EXISTS (
      SELECT 1
      FROM jsonb_array_elements(target_payload->'selections') AS entry(selection)
      WHERE jsonb_typeof(selection) <> 'object'
        OR (SELECT count(*) FROM jsonb_object_keys(selection)) <> 2
        OR jsonb_typeof(selection->'criterionId') <> 'string'
        OR jsonb_typeof(selection->'optionId') <> 'string'
        OR "rise_pals_private"."source_verification_option_meets"(
          selection->>'criterionId', selection->>'optionId'
        ) IS NULL
    ) THEN
    RAISE EXCEPTION 'Practice response selections are invalid.';
  END IF;

  IF target_status = 'draft' THEN
    IF target_results IS NOT NULL OR target_demonstrated IS NOT NULL THEN
      RAISE EXCEPTION 'Draft practice state cannot contain evaluation output.';
    END IF;
    RETURN;
  END IF;

  IF selection_count <> 3
    OR ordered_ranks <> ARRAY[1, 2, 3]
    OR jsonb_typeof(target_results) <> 'object'
    OR target_results->>'schemaVersion' <> 'source-verification-evaluation-v1'
    OR jsonb_typeof(target_results->'criteria') <> 'array'
    OR (SELECT count(*) FROM jsonb_object_keys(target_results)) <> 2 THEN
    RAISE EXCEPTION 'Evaluated practice requires the exact complete response and result.';
  END IF;

  SELECT count(*)::integer,
         bool_and(result->>'status' = 'met')
    INTO result_count, expected_demonstrated
  FROM jsonb_array_elements(target_results->'criteria') WITH ORDINALITY AS result_entry(result, ordinal)
  JOIN jsonb_array_elements(target_payload->'selections') WITH ORDINALITY AS selection_entry(selection, selection_ordinal)
    ON selection->>'criterionId' = result->>'criterionId'
  WHERE jsonb_typeof(result) = 'object'
    AND (SELECT count(*) FROM jsonb_object_keys(result)) = 3
    AND jsonb_typeof(result->'criterionId') = 'string'
    AND jsonb_typeof(result->'selectedOptionId') = 'string'
    AND jsonb_typeof(result->'status') = 'string'
    AND result->>'selectedOptionId' = selection->>'optionId'
    AND result->>'status' = CASE
      WHEN "rise_pals_private"."source_verification_option_meets"(
        selection->>'criterionId', selection->>'optionId'
      ) THEN 'met'
      ELSE 'not-met'
    END
    AND ordinal = selection_ordinal;

  IF result_count <> 3 OR target_demonstrated IS DISTINCT FROM expected_demonstrated THEN
    RAISE EXCEPTION 'Practice evaluation output does not match the canonical rubric.';
  END IF;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."assert_source_verification_practice_payload"(
  jsonb, practice_attempt_status, jsonb, boolean
) FROM PUBLIC;
--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."assert_source_verification_practice_payload"(
  jsonb, practice_attempt_status, jsonb, boolean
) TO "rise_pals_app";
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_lesson_attempt"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  current_consent_id uuid;
  activity_time timestamptz;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Lesson attempt history is immutable.';
  END IF;

  PERFORM "rise_pals_private"."assert_current_service_grant"(NEW.user_id);
  SELECT id INTO current_consent_id
  FROM consent_records
  WHERE user_id = NEW.user_id
    AND purpose_code = 'service-profile-learning-state'
    AND notice_version = 'alpha-privacy-v1'
  ORDER BY occurred_at DESC, id DESC
  LIMIT 1;

  IF current_consent_id IS NULL OR current_consent_id <> NEW.consent_record_id THEN
    RAISE EXCEPTION 'Lesson attempt requires the exact current consent receipt.';
  END IF;

  activity_time := clock_timestamp();
  IF TG_OP = 'INSERT' THEN
    NEW.status := 'in_progress';
    NEW.started_at := activity_time;
    NEW.last_meaningful_activity_at := activity_time;
    NEW.demonstrated_at := NULL;
    RETURN NEW;
  END IF;

  IF OLD.status = 'demonstrated'
    OR NEW.id IS DISTINCT FROM OLD.id
    OR NEW.user_id IS DISTINCT FROM OLD.user_id
    OR NEW.consent_record_id IS DISTINCT FROM OLD.consent_record_id
    OR NEW.lesson_key IS DISTINCT FROM OLD.lesson_key
    OR NEW.lesson_version_id IS DISTINCT FROM OLD.lesson_version_id
    OR NEW.lesson_version IS DISTINCT FROM OLD.lesson_version
    OR NEW.lesson_digest IS DISTINCT FROM OLD.lesson_digest
    OR NEW.practice_id IS DISTINCT FROM OLD.practice_id
    OR NEW.practice_version IS DISTINCT FROM OLD.practice_version
    OR NEW.rubric_version_id IS DISTINCT FROM OLD.rubric_version_id
    OR NEW.rubric_version IS DISTINCT FROM OLD.rubric_version
    OR NEW.evaluation_contract_version_id IS DISTINCT FROM OLD.evaluation_contract_version_id
    OR NEW.start_mutation_id IS DISTINCT FROM OLD.start_mutation_id
    OR NEW.started_at IS DISTINCT FROM OLD.started_at
    OR NEW.status NOT IN ('in_progress', 'demonstrated')
    OR (NEW.status = 'in_progress' AND NEW.demonstrated_at IS NOT NULL)
    OR (NEW.status = 'demonstrated' AND OLD.status <> 'in_progress') THEN
    RAISE EXCEPTION 'Lesson attempt transition is invalid.';
  END IF;

  NEW.last_meaningful_activity_at := activity_time;
  IF NEW.status = 'demonstrated' THEN
    NEW.demonstrated_at := activity_time;
  END IF;
  RETURN NEW;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_lesson_attempt"() FROM PUBLIC;
--> statement-breakpoint
CREATE TRIGGER "lesson_attempts_guard"
  BEFORE INSERT OR UPDATE OR DELETE ON "lesson_attempts"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_lesson_attempt"();
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_practice_attempt"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  parent lesson_attempts%ROWTYPE;
  prior_id uuid;
  prior_revision integer;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'Practice attempt history is immutable.';
  END IF;

  PERFORM "rise_pals_private"."assert_current_service_grant"(NEW.user_id);
  SELECT * INTO parent
  FROM lesson_attempts
  WHERE id = NEW.lesson_attempt_id AND user_id = NEW.user_id
  FOR UPDATE;

  IF NOT FOUND OR parent.status <> 'in_progress' THEN
    RAISE EXCEPTION 'Practice attempt requires an active owner lesson attempt.';
  END IF;
  IF NEW.practice_id <> parent.practice_id
    OR NEW.practice_version <> parent.practice_version
    OR NEW.rubric_version_id <> parent.rubric_version_id
    OR NEW.rubric_version <> parent.rubric_version
    OR NEW.evaluation_contract_version_id <> parent.evaluation_contract_version_id THEN
    RAISE EXCEPTION 'Practice compatibility metadata does not match the lesson attempt.';
  END IF;

  SELECT id, revision INTO prior_id, prior_revision
  FROM practice_attempts
  WHERE lesson_attempt_id = NEW.lesson_attempt_id AND user_id = NEW.user_id
  ORDER BY revision DESC
  LIMIT 1;

  IF prior_id IS NULL THEN
    IF NEW.revision <> 1 OR NEW.supersedes_practice_attempt_id IS NOT NULL THEN
      RAISE EXCEPTION 'The first practice revision has invalid provenance.';
    END IF;
  ELSIF NEW.revision <> prior_revision + 1
    OR NEW.supersedes_practice_attempt_id IS DISTINCT FROM prior_id THEN
    RAISE EXCEPTION 'Practice revision must append to the current owner revision.';
  END IF;

  PERFORM "rise_pals_private"."assert_source_verification_practice_payload"(
    NEW.response_payload,
    NEW.status,
    NEW.criterion_results,
    NEW.demonstrated
  );
  NEW.created_at := clock_timestamp();
  RETURN NEW;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_practice_attempt"() FROM PUBLIC;
--> statement-breakpoint
CREATE TRIGGER "practice_attempts_guard"
  BEFORE INSERT OR UPDATE OR DELETE ON "practice_attempts"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_practice_attempt"();
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_learning_progress_event"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  parent lesson_attempts%ROWTYPE;
  practice practice_attempts%ROWTYPE;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'Learning progress events are immutable.';
  END IF;

  PERFORM "rise_pals_private"."assert_current_service_grant"(NEW.user_id);
  SELECT * INTO parent
  FROM lesson_attempts
  WHERE id = NEW.lesson_attempt_id AND user_id = NEW.user_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Progress event requires an owner lesson attempt.';
  END IF;

  IF NEW.event_kind = 'lesson_started' THEN
    IF NEW.practice_attempt_id IS NOT NULL
      OR NEW.source_mutation_id <> parent.start_mutation_id THEN
      RAISE EXCEPTION 'Lesson-started event provenance is invalid.';
    END IF;
  ELSE
    SELECT * INTO practice
    FROM practice_attempts
    WHERE id = NEW.practice_attempt_id
      AND user_id = NEW.user_id
      AND lesson_attempt_id = NEW.lesson_attempt_id;
    IF NOT FOUND OR practice.status <> 'evaluated'
      OR NEW.source_mutation_id <> practice.client_mutation_id
      OR (NEW.event_kind = 'practice_demonstrated' AND practice.demonstrated IS NOT true) THEN
      RAISE EXCEPTION 'Practice progress event provenance is invalid.';
    END IF;
  END IF;

  NEW.occurred_at := clock_timestamp();
  RETURN NEW;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_learning_progress_event"() FROM PUBLIC;
--> statement-breakpoint
CREATE TRIGGER "learning_progress_events_guard"
  BEFORE INSERT OR UPDATE OR DELETE ON "learning_progress_events"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_learning_progress_event"();
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."assert_learning_progress_complete"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  target_lesson_id uuid;
  lesson lesson_attempts%ROWTYPE;
  started_count integer;
  evaluated_count integer;
  evaluated_event_count integer;
  demonstrated_count integer;
  demonstrated_event_count integer;
BEGIN
  IF TG_TABLE_NAME = 'lesson_attempts' THEN
    IF TG_OP = 'DELETE' THEN
      target_lesson_id := OLD.id;
    ELSE
      target_lesson_id := NEW.id;
    END IF;
  ELSE
    IF TG_OP = 'DELETE' THEN
      target_lesson_id := OLD.lesson_attempt_id;
    ELSE
      target_lesson_id := NEW.lesson_attempt_id;
    END IF;
  END IF;

  SELECT * INTO lesson FROM lesson_attempts WHERE id = target_lesson_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT count(*)::integer INTO started_count
  FROM learning_progress_events
  WHERE lesson_attempt_id = target_lesson_id
    AND event_kind = 'lesson_started'
    AND practice_attempt_id IS NULL
    AND source_mutation_id = lesson.start_mutation_id;

  SELECT count(*)::integer INTO evaluated_count
  FROM practice_attempts
  WHERE lesson_attempt_id = target_lesson_id AND status = 'evaluated';
  SELECT count(*)::integer INTO evaluated_event_count
  FROM learning_progress_events
  WHERE lesson_attempt_id = target_lesson_id AND event_kind = 'practice_evaluated';
  SELECT count(*)::integer INTO demonstrated_count
  FROM practice_attempts
  WHERE lesson_attempt_id = target_lesson_id AND status = 'evaluated' AND demonstrated;
  SELECT count(*)::integer INTO demonstrated_event_count
  FROM learning_progress_events
  WHERE lesson_attempt_id = target_lesson_id AND event_kind = 'practice_demonstrated';

  IF started_count <> 1
    OR evaluated_count <> evaluated_event_count
    OR demonstrated_count <> demonstrated_event_count
    OR EXISTS (
      SELECT 1 FROM practice_attempts AS practice
      WHERE practice.lesson_attempt_id = target_lesson_id
        AND practice.status = 'evaluated'
        AND NOT EXISTS (
          SELECT 1 FROM learning_progress_events AS event
          WHERE event.practice_attempt_id = practice.id
            AND event.event_kind = 'practice_evaluated'
            AND event.source_mutation_id = practice.client_mutation_id
        )
    )
    OR EXISTS (
      SELECT 1 FROM practice_attempts AS practice
      WHERE practice.lesson_attempt_id = target_lesson_id
        AND practice.status = 'evaluated'
        AND practice.demonstrated
        AND NOT EXISTS (
          SELECT 1 FROM learning_progress_events AS event
          WHERE event.practice_attempt_id = practice.id
            AND event.event_kind = 'practice_demonstrated'
            AND event.source_mutation_id = practice.client_mutation_id
        )
    )
    OR (lesson.status = 'in_progress' AND demonstrated_count <> 0)
    OR (lesson.status = 'demonstrated' AND demonstrated_count <> 1) THEN
    RAISE EXCEPTION 'Learning attempts and meaningful progress events must commit atomically.';
  END IF;
  RETURN NULL;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."assert_learning_progress_complete"() FROM PUBLIC;
--> statement-breakpoint
CREATE CONSTRAINT TRIGGER "lesson_attempts_progress_complete"
  AFTER INSERT OR UPDATE OR DELETE ON "lesson_attempts"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_learning_progress_complete"();
--> statement-breakpoint
CREATE CONSTRAINT TRIGGER "practice_attempts_progress_complete"
  AFTER INSERT OR UPDATE OR DELETE ON "practice_attempts"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_learning_progress_complete"();
--> statement-breakpoint
CREATE CONSTRAINT TRIGGER "learning_progress_events_progress_complete"
  AFTER INSERT OR UPDATE OR DELETE ON "learning_progress_events"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_learning_progress_complete"();
