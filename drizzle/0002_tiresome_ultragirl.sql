CREATE TYPE "public"."assessment_session_status" AS ENUM('in_progress', 'submitted');--> statement-breakpoint
CREATE TABLE "assessment_responses" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"session_id" uuid NOT NULL,
	"assessment_version_id" uuid NOT NULL,
	"assessment_item_version_id" uuid NOT NULL,
	"response_payload" jsonb NOT NULL,
	"revision" integer NOT NULL,
	"supersedes_response_id" uuid,
	"client_mutation_id" uuid NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "assessment_responses_id_session_unique" UNIQUE("id","session_id"),
	CONSTRAINT "assessment_responses_revision_positive" CHECK ("assessment_responses"."revision" > 0),
	CONSTRAINT "assessment_responses_supersession_shape_check" CHECK (("assessment_responses"."revision" = 1 AND "assessment_responses"."supersedes_response_id" IS NULL) OR ("assessment_responses"."revision" > 1 AND "assessment_responses"."supersedes_response_id" IS NOT NULL)),
	CONSTRAINT "assessment_responses_payload_json_check" CHECK (rise_pals_private.is_versioned_json_object("response_payload"))
);
--> statement-breakpoint
CREATE TABLE "assessment_sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"assessment_version_id" uuid NOT NULL,
	"consent_record_id" uuid NOT NULL,
	"status" "assessment_session_status" DEFAULT 'in_progress' NOT NULL,
	"last_item_version_id" uuid,
	"started_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"submitted_at" timestamp with time zone,
	CONSTRAINT "assessment_sessions_id_user_unique" UNIQUE("id","user_id"),
	CONSTRAINT "assessment_sessions_id_assessment_unique" UNIQUE("id","assessment_version_id"),
	CONSTRAINT "assessment_sessions_submission_timestamp_check" CHECK (("assessment_sessions"."status" = 'in_progress' AND "assessment_sessions"."submitted_at" IS NULL) OR ("assessment_sessions"."status" = 'submitted' AND "assessment_sessions"."submitted_at" IS NOT NULL))
);
--> statement-breakpoint
ALTER TABLE "assessment_item_versions" ADD CONSTRAINT "assessment_item_versions_id_assessment_unique" UNIQUE("id","assessment_version_id");
--> statement-breakpoint
ALTER TABLE "consent_records" ADD CONSTRAINT "consent_records_id_user_unique" UNIQUE("id","user_id");
--> statement-breakpoint
ALTER TABLE "assessment_responses" ADD CONSTRAINT "assessment_responses_session_assessment_fk" FOREIGN KEY ("session_id","assessment_version_id") REFERENCES "public"."assessment_sessions"("id","assessment_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "assessment_responses" ADD CONSTRAINT "assessment_responses_item_assessment_fk" FOREIGN KEY ("assessment_item_version_id","assessment_version_id") REFERENCES "public"."assessment_item_versions"("id","assessment_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "assessment_responses" ADD CONSTRAINT "assessment_responses_supersedes_session_fk" FOREIGN KEY ("supersedes_response_id","session_id") REFERENCES "public"."assessment_responses"("id","session_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "assessment_sessions" ADD CONSTRAINT "assessment_sessions_user_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_accounts"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "assessment_sessions" ADD CONSTRAINT "assessment_sessions_assessment_fk" FOREIGN KEY ("assessment_version_id") REFERENCES "public"."assessment_versions"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "assessment_sessions" ADD CONSTRAINT "assessment_sessions_consent_owner_fk" FOREIGN KEY ("consent_record_id","user_id") REFERENCES "public"."consent_records"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "assessment_sessions" ADD CONSTRAINT "assessment_sessions_last_item_assessment_fk" FOREIGN KEY ("last_item_version_id","assessment_version_id") REFERENCES "public"."assessment_item_versions"("id","assessment_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
CREATE UNIQUE INDEX "assessment_responses_session_mutation_unique" ON "assessment_responses" USING btree ("session_id","client_mutation_id");--> statement-breakpoint
CREATE UNIQUE INDEX "assessment_responses_one_active_per_item" ON "assessment_responses" USING btree ("session_id","assessment_item_version_id") WHERE "assessment_responses"."is_active" = true;--> statement-breakpoint
CREATE INDEX "assessment_responses_session_created_idx" ON "assessment_responses" USING btree ("session_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "assessment_sessions_one_active_per_owner_version" ON "assessment_sessions" USING btree ("user_id","assessment_version_id") WHERE "assessment_sessions"."status" = 'in_progress';--> statement-breakpoint
CREATE INDEX "assessment_sessions_user_started_idx" ON "assessment_sessions" USING btree ("user_id","started_at");
--> statement-breakpoint
CREATE UNIQUE INDEX "assessment_responses_session_item_revision_unique"
  ON "assessment_responses" ("session_id", "assessment_item_version_id", "revision");
--> statement-breakpoint
CREATE UNIQUE INDEX "assessment_responses_supersedes_unique"
  ON "assessment_responses" ("supersedes_response_id")
  WHERE "supersedes_response_id" IS NOT NULL;
--> statement-breakpoint

ALTER TABLE "assessment_sessions" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "assessment_sessions" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "assessment_responses" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "assessment_responses" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint

CREATE POLICY "assessment_sessions_owner_select_policy" ON "assessment_sessions"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING ("user_id" = "rise_pals_private"."current_app_user_id"());
--> statement-breakpoint
CREATE POLICY "assessment_sessions_owner_insert_policy" ON "assessment_sessions"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK ("user_id" = "rise_pals_private"."current_app_user_id"());
--> statement-breakpoint
CREATE POLICY "assessment_sessions_owner_update_policy" ON "assessment_sessions"
  FOR UPDATE TO "rise_pals_app", "rise_pals_owner"
  USING ("user_id" = "rise_pals_private"."current_app_user_id"())
  WITH CHECK ("user_id" = "rise_pals_private"."current_app_user_id"());
--> statement-breakpoint

CREATE POLICY "assessment_responses_owner_select_policy" ON "assessment_responses"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    EXISTS (
      SELECT 1
      FROM "assessment_sessions" AS owned_session
      WHERE owned_session."id" = "assessment_responses"."session_id"
        AND owned_session."user_id" = "rise_pals_private"."current_app_user_id"()
    )
  );
--> statement-breakpoint
CREATE POLICY "assessment_responses_owner_insert_policy" ON "assessment_responses"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM "assessment_sessions" AS owned_session
      WHERE owned_session."id" = "assessment_responses"."session_id"
        AND owned_session."user_id" = "rise_pals_private"."current_app_user_id"()
    )
  );
--> statement-breakpoint
CREATE POLICY "assessment_responses_owner_update_policy" ON "assessment_responses"
  FOR UPDATE TO "rise_pals_app", "rise_pals_owner"
  USING (
    EXISTS (
      SELECT 1
      FROM "assessment_sessions" AS owned_session
      WHERE owned_session."id" = "assessment_responses"."session_id"
        AND owned_session."user_id" = "rise_pals_private"."current_app_user_id"()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM "assessment_sessions" AS owned_session
      WHERE owned_session."id" = "assessment_responses"."session_id"
        AND owned_session."user_id" = "rise_pals_private"."current_app_user_id"()
    )
  );
--> statement-breakpoint

GRANT USAGE ON TYPE "assessment_session_status" TO "rise_pals_app";
--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."is_versioned_json_object"(jsonb)
  TO "rise_pals_app";
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "assessment_sessions" TO "rise_pals_app";
--> statement-breakpoint
GRANT UPDATE ("status", "last_item_version_id", "updated_at", "submitted_at")
  ON TABLE "assessment_sessions" TO "rise_pals_app";
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "assessment_responses" TO "rise_pals_app";
--> statement-breakpoint
GRANT UPDATE ("is_active") ON TABLE "assessment_responses" TO "rise_pals_app";
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."assert_current_service_grant"(target_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  current_decision consent_decision;
BEGIN
  IF target_user_id IS DISTINCT FROM "rise_pals_private"."current_app_user_id"() THEN
    RAISE EXCEPTION 'assessment owner does not match the authorized user'
      USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM user_accounts
    WHERE id = target_user_id AND status = 'active'
  ) THEN
    RAISE EXCEPTION 'an active account is required for assessment persistence'
      USING ERRCODE = '42501';
  END IF;

  SELECT decision
  INTO current_decision
  FROM consent_records
  WHERE user_id = target_user_id
    AND purpose_code = 'service-profile-learning-state'
    AND notice_version = 'alpha-privacy-v1'
  ORDER BY occurred_at DESC, id DESC
  LIMIT 1;

  IF current_decision IS DISTINCT FROM 'granted'::consent_decision THEN
    RAISE EXCEPTION 'current service-data consent is required for assessment persistence'
      USING ERRCODE = '42501';
  END IF;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."assert_current_service_grant"(uuid) FROM PUBLIC;
--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."assert_current_service_grant"(uuid)
  TO "rise_pals_app";
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_assessment_session"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  assessment_status publication_status;
  linked_consent consent_records%ROWTYPE;
  required_item_count integer;
  active_response_count integer;
  database_now timestamptz;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'assessment sessions cannot be deleted in this alpha contract'
      USING ERRCODE = '55000';
  END IF;

  PERFORM "rise_pals_private"."assert_current_service_grant"(NEW.user_id);
  database_now := clock_timestamp();

  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'in_progress' OR NEW.submitted_at IS NOT NULL THEN
      RAISE EXCEPTION 'assessment sessions must start in progress'
        USING ERRCODE = '23514';
    END IF;

    SELECT * INTO linked_consent
    FROM consent_records
    WHERE id = NEW.consent_record_id AND user_id = NEW.user_id;

    IF linked_consent.id IS NULL
      OR linked_consent.purpose_code <> 'service-profile-learning-state'
      OR linked_consent.notice_version <> 'alpha-privacy-v1'
      OR linked_consent.decision <> 'granted' THEN
      RAISE EXCEPTION 'assessment session requires an exact granted service consent record'
        USING ERRCODE = '23514';
    END IF;

    SELECT status INTO assessment_status
    FROM assessment_versions
    WHERE id = NEW.assessment_version_id;

    IF assessment_status IS DISTINCT FROM 'published'::publication_status THEN
      RAISE EXCEPTION 'assessment session requires an exact published assessment version'
        USING ERRCODE = '23514';
    END IF;

    IF EXISTS (
      SELECT 1 FROM assessment_sessions
      WHERE user_id = NEW.user_id
        AND assessment_version_id = NEW.assessment_version_id
    ) THEN
      RAISE EXCEPTION 'this alpha permits only one persisted session per owner and assessment version'
        USING ERRCODE = '23505';
    END IF;

    NEW.started_at := database_now;
    NEW.updated_at := database_now;
    NEW.submitted_at := NULL;
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
    OR NEW.user_id IS DISTINCT FROM OLD.user_id
    OR NEW.assessment_version_id IS DISTINCT FROM OLD.assessment_version_id
    OR NEW.consent_record_id IS DISTINCT FROM OLD.consent_record_id
    OR NEW.started_at IS DISTINCT FROM OLD.started_at THEN
    RAISE EXCEPTION 'assessment session ownership and version anchors are immutable'
      USING ERRCODE = '55000';
  END IF;

  IF OLD.status = 'submitted' THEN
    RAISE EXCEPTION 'submitted assessment sessions are immutable'
      USING ERRCODE = '55000';
  END IF;

  IF NEW.status = 'in_progress' THEN
    IF NEW.submitted_at IS NOT NULL THEN
      RAISE EXCEPTION 'in-progress sessions cannot have a submission timestamp'
        USING ERRCODE = '23514';
    END IF;
    NEW.updated_at := database_now;
    RETURN NEW;
  END IF;

  IF NEW.status <> 'submitted' THEN
    RAISE EXCEPTION 'unsupported assessment session lifecycle transition'
      USING ERRCODE = '55000';
  END IF;

  SELECT count(*) INTO required_item_count
  FROM assessment_item_versions
  WHERE assessment_version_id = OLD.assessment_version_id AND required;

  SELECT count(*) INTO active_response_count
  FROM assessment_responses AS response
  JOIN assessment_item_versions AS item
    ON item.id = response.assessment_item_version_id
   AND item.assessment_version_id = response.assessment_version_id
  WHERE response.session_id = OLD.id
    AND response.is_active
    AND item.required;

  IF required_item_count = 0 OR active_response_count <> required_item_count THEN
    RAISE EXCEPTION 'all required assessment items must have one active response before submission'
      USING ERRCODE = '23514';
  END IF;

  NEW.updated_at := database_now;
  NEW.submitted_at := database_now;
  RETURN NEW;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_assessment_session"() FROM PUBLIC;
--> statement-breakpoint
CREATE TRIGGER "assessment_sessions_guard"
  BEFORE INSERT OR UPDATE OR DELETE ON "assessment_sessions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_assessment_session"();
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_assessment_response"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  owned_session assessment_sessions%ROWTYPE;
  item_schema jsonb;
  selected_option_id text;
  prior_response assessment_responses%ROWTYPE;
  latest_revision integer;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'assessment responses are append-only and cannot be deleted'
      USING ERRCODE = '55000';
  END IF;

  SELECT * INTO owned_session
  FROM assessment_sessions
  WHERE id = COALESCE(NEW.session_id, OLD.session_id)
  FOR UPDATE;

  IF owned_session.id IS NULL THEN
    RAISE EXCEPTION 'assessment session is unavailable to the authorized owner'
      USING ERRCODE = '42501';
  END IF;

  PERFORM "rise_pals_private"."assert_current_service_grant"(owned_session.user_id);

  IF owned_session.status <> 'in_progress' THEN
    RAISE EXCEPTION 'responses cannot change after assessment submission'
      USING ERRCODE = '55000';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NOT OLD.is_active OR NEW.is_active
      OR (to_jsonb(NEW) - 'is_active') IS DISTINCT FROM (to_jsonb(OLD) - 'is_active') THEN
      RAISE EXCEPTION 'response revisions may only deactivate the current response'
        USING ERRCODE = '55000';
    END IF;
    RETURN NEW;
  END IF;

  IF NOT NEW.is_active THEN
    RAISE EXCEPTION 'new response revisions must be active'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.assessment_version_id IS DISTINCT FROM owned_session.assessment_version_id THEN
    RAISE EXCEPTION 'response assessment version does not match its session'
      USING ERRCODE = '23514';
  END IF;

  SELECT response_schema INTO item_schema
  FROM assessment_item_versions
  WHERE id = NEW.assessment_item_version_id
    AND assessment_version_id = NEW.assessment_version_id;

  IF item_schema IS NULL THEN
    RAISE EXCEPTION 'response item does not belong to the session assessment version'
      USING ERRCODE = '23514';
  END IF;

  IF jsonb_typeof(NEW.response_payload) <> 'object'
    OR (SELECT count(*) FROM jsonb_object_keys(NEW.response_payload)) <> 2
    OR NOT (NEW.response_payload ? 'schemaVersion')
    OR NOT (NEW.response_payload ? 'selectedOptionId')
    OR NEW.response_payload->>'schemaVersion' <> 'assessment-response-v1'
    OR jsonb_typeof(NEW.response_payload->'selectedOptionId') <> 'string' THEN
    RAISE EXCEPTION 'response payload must contain only the exact version and selected option ID'
      USING ERRCODE = '23514';
  END IF;

  selected_option_id := NEW.response_payload->>'selectedOptionId';
  IF item_schema->>'schemaVersion' <> 'assessment-response-options-v1'
    OR item_schema->>'type' <> 'scenario-choice'
    OR jsonb_typeof(item_schema->'optionIds') <> 'array'
    OR NOT ((item_schema->'optionIds') ? selected_option_id) THEN
    RAISE EXCEPTION 'selected option is not in the exact published item version'
      USING ERRCODE = '23514';
  END IF;

  SELECT coalesce(max(revision), 0) INTO latest_revision
  FROM assessment_responses
  WHERE session_id = NEW.session_id
    AND assessment_item_version_id = NEW.assessment_item_version_id;

  IF NEW.revision <> latest_revision + 1 THEN
    RAISE EXCEPTION 'response revision must advance exactly once'
      USING ERRCODE = '40001';
  END IF;

  IF latest_revision = 0 THEN
    IF NEW.supersedes_response_id IS NOT NULL THEN
      RAISE EXCEPTION 'the first response revision cannot supersede another response'
        USING ERRCODE = '23514';
    END IF;
  ELSE
    SELECT * INTO prior_response
    FROM assessment_responses
    WHERE id = NEW.supersedes_response_id
      AND session_id = NEW.session_id;

    IF prior_response.id IS NULL
      OR prior_response.assessment_item_version_id IS DISTINCT FROM NEW.assessment_item_version_id
      OR prior_response.revision <> latest_revision
      OR prior_response.is_active THEN
      RAISE EXCEPTION 'response revision must supersede the exact prior active revision'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  NEW.created_at := clock_timestamp();
  RETURN NEW;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_assessment_response"() FROM PUBLIC;
--> statement-breakpoint
CREATE TRIGGER "assessment_responses_guard"
  BEFORE INSERT OR UPDATE OR DELETE ON "assessment_responses"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_assessment_response"();
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."assert_one_active_assessment_response"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  target_session_id uuid;
  target_item_id uuid;
  response_count integer;
  active_count integer;
BEGIN
  target_session_id := COALESCE(NEW.session_id, OLD.session_id);
  target_item_id := COALESCE(NEW.assessment_item_version_id, OLD.assessment_item_version_id);

  SELECT count(*), count(*) FILTER (WHERE is_active)
  INTO response_count, active_count
  FROM assessment_responses
  WHERE session_id = target_session_id
    AND assessment_item_version_id = target_item_id;

  IF response_count > 0 AND active_count <> 1 THEN
    RAISE EXCEPTION 'response history must retain exactly one active revision per answered item'
      USING ERRCODE = '23514';
  END IF;

  RETURN NULL;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."assert_one_active_assessment_response"() FROM PUBLIC;
--> statement-breakpoint
CREATE CONSTRAINT TRIGGER "assessment_responses_exactly_one_active"
  AFTER INSERT OR UPDATE OR DELETE ON "assessment_responses"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_one_active_assessment_response"();
