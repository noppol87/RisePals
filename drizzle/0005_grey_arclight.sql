CREATE TYPE "public"."evidence_artifact_status" AS ENUM('draft', 'ready', 'withdrawn');--> statement-breakpoint
CREATE TABLE "evidence_artifact_revisions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"artifact_id" uuid NOT NULL,
	"revision" integer NOT NULL,
	"supersedes_revision_id" uuid,
	"artifact_contract_id" text NOT NULL,
	"artifact_contract_version" text NOT NULL,
	"source_pack_id" text NOT NULL,
	"payload" jsonb NOT NULL,
	"client_mutation_id" uuid NOT NULL,
	"mutation_intent" text NOT NULL,
	"mutation_locale" text NOT NULL,
	"mutation_expected_revision" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "evidence_artifact_revisions_id_owner_artifact_unique" UNIQUE("id","user_id","artifact_id"),
	CONSTRAINT "evidence_artifact_revisions_revision_positive" CHECK ("evidence_artifact_revisions"."revision" > 0),
	CONSTRAINT "evidence_artifact_revisions_mutation_check" CHECK ("evidence_artifact_revisions"."mutation_intent" = 'save' AND "evidence_artifact_revisions"."mutation_locale" IN ('th', 'en') AND "evidence_artifact_revisions"."mutation_expected_revision" >= 0 AND "evidence_artifact_revisions"."revision" = "evidence_artifact_revisions"."mutation_expected_revision" + 1),
	CONSTRAINT "evidence_artifact_revisions_supersession_check" CHECK (("evidence_artifact_revisions"."revision" = 1 AND "evidence_artifact_revisions"."supersedes_revision_id" IS NULL) OR ("evidence_artifact_revisions"."revision" > 1 AND "evidence_artifact_revisions"."supersedes_revision_id" IS NOT NULL)),
	CONSTRAINT "evidence_artifact_revisions_compatibility_check" CHECK ("evidence_artifact_revisions"."artifact_contract_id" = 'source-verification-note-artifact-v1' AND "evidence_artifact_revisions"."artifact_contract_version" = '1.0.0' AND "evidence_artifact_revisions"."source_pack_id" = 'bright-river-operations-synthetic-source-pack-v1'),
	CONSTRAINT "evidence_artifact_revisions_payload_json_check" CHECK (rise_pals_private.is_versioned_json_object("payload"))
);
--> statement-breakpoint
CREATE TABLE "evidence_artifacts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"consent_record_id" uuid NOT NULL,
	"source_lesson_attempt_id" uuid NOT NULL,
	"source_practice_attempt_id" uuid NOT NULL,
	"artifact_contract_id" text NOT NULL,
	"artifact_contract_version" text NOT NULL,
	"artifact_type" text NOT NULL,
	"source_proof_id" text NOT NULL,
	"source_proof_version" text NOT NULL,
	"source_lesson_key" text NOT NULL,
	"source_lesson_version" text NOT NULL,
	"source_lesson_digest" text NOT NULL,
	"source_pack_id" text NOT NULL,
	"classification" text NOT NULL,
	"validation_status" text NOT NULL,
	"start_mutation_id" uuid NOT NULL,
	"start_mutation_locale" text NOT NULL,
	"status" "evidence_artifact_status" DEFAULT 'draft' NOT NULL,
	"ready_mutation_id" uuid,
	"ready_mutation_locale" text,
	"ready_expected_revision" integer,
	"withdraw_mutation_id" uuid,
	"withdraw_mutation_locale" text,
	"withdraw_expected_revision" integer,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"ready_at" timestamp with time zone,
	"withdrawn_at" timestamp with time zone,
	CONSTRAINT "evidence_artifacts_id_user_unique" UNIQUE("id","user_id"),
	CONSTRAINT "evidence_artifacts_identity_check" CHECK ("evidence_artifacts"."artifact_contract_id" = 'source-verification-note-artifact-v1' AND "evidence_artifacts"."artifact_contract_version" = '1.0.0' AND "evidence_artifacts"."artifact_type" = 'source-verification-note' AND "evidence_artifacts"."source_proof_id" = 'source-verification-note-placeholder-v1' AND "evidence_artifacts"."source_proof_version" = '1.0.0'),
	CONSTRAINT "evidence_artifacts_source_check" CHECK ("evidence_artifacts"."source_lesson_key" = 'source-verification-practice' AND "evidence_artifacts"."source_lesson_version" = '1.0.0' AND "evidence_artifacts"."source_lesson_digest" = '51903ea9e6053a1102b4d60ad072c9a1dcde26a90d6a0ca7ae36cba8a6995e91' AND "evidence_artifacts"."source_pack_id" = 'bright-river-operations-synthetic-source-pack-v1'),
	CONSTRAINT "evidence_artifacts_classification_check" CHECK ("evidence_artifacts"."classification" = 'synthetic-private-evidence' AND "evidence_artifacts"."validation_status" = 'prototype-unvalidated'),
	CONSTRAINT "evidence_artifacts_locale_check" CHECK ("evidence_artifacts"."start_mutation_locale" IN ('th', 'en') AND ("evidence_artifacts"."ready_mutation_locale" IS NULL OR "evidence_artifacts"."ready_mutation_locale" IN ('th', 'en')) AND ("evidence_artifacts"."withdraw_mutation_locale" IS NULL OR "evidence_artifacts"."withdraw_mutation_locale" IN ('th', 'en'))),
	CONSTRAINT "evidence_artifacts_lifecycle_shape_check" CHECK (("evidence_artifacts"."status" = 'draft' AND "evidence_artifacts"."ready_mutation_id" IS NULL AND "evidence_artifacts"."ready_mutation_locale" IS NULL AND "evidence_artifacts"."ready_expected_revision" IS NULL AND "evidence_artifacts"."withdraw_mutation_id" IS NULL AND "evidence_artifacts"."withdraw_mutation_locale" IS NULL AND "evidence_artifacts"."withdraw_expected_revision" IS NULL AND "evidence_artifacts"."ready_at" IS NULL AND "evidence_artifacts"."withdrawn_at" IS NULL) OR ("evidence_artifacts"."status" = 'ready' AND "evidence_artifacts"."ready_mutation_id" IS NOT NULL AND "evidence_artifacts"."ready_mutation_locale" IS NOT NULL AND "evidence_artifacts"."ready_expected_revision" IS NOT NULL AND "evidence_artifacts"."withdraw_mutation_id" IS NULL AND "evidence_artifacts"."withdraw_mutation_locale" IS NULL AND "evidence_artifacts"."withdraw_expected_revision" IS NULL AND "evidence_artifacts"."ready_at" IS NOT NULL AND "evidence_artifacts"."withdrawn_at" IS NULL) OR ("evidence_artifacts"."status" = 'withdrawn' AND "evidence_artifacts"."withdraw_mutation_id" IS NOT NULL AND "evidence_artifacts"."withdraw_mutation_locale" IS NOT NULL AND "evidence_artifacts"."withdraw_expected_revision" IS NOT NULL AND "evidence_artifacts"."withdrawn_at" IS NOT NULL AND (("evidence_artifacts"."ready_mutation_id" IS NULL AND "evidence_artifacts"."ready_mutation_locale" IS NULL AND "evidence_artifacts"."ready_expected_revision" IS NULL AND "evidence_artifacts"."ready_at" IS NULL) OR ("evidence_artifacts"."ready_mutation_id" IS NOT NULL AND "evidence_artifacts"."ready_mutation_locale" IS NOT NULL AND "evidence_artifacts"."ready_expected_revision" IS NOT NULL AND "evidence_artifacts"."ready_at" IS NOT NULL)))),
	CONSTRAINT "evidence_artifacts_time_check" CHECK ("evidence_artifacts"."updated_at" >= "evidence_artifacts"."created_at" AND ("evidence_artifacts"."ready_at" IS NULL OR "evidence_artifacts"."ready_at" >= "evidence_artifacts"."created_at") AND ("evidence_artifacts"."withdrawn_at" IS NULL OR "evidence_artifacts"."withdrawn_at" >= "evidence_artifacts"."created_at"))
);
--> statement-breakpoint
CREATE TABLE "evidence_competency_links" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"artifact_id" uuid NOT NULL,
	"framework_version_id" uuid NOT NULL,
	"competency_version_id" uuid NOT NULL,
	"relationship_code" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "evidence_competency_links_id_user_unique" UNIQUE("id","user_id"),
	CONSTRAINT "evidence_competency_links_relationship_check" CHECK ("evidence_competency_links"."relationship_code" = 'synthetic-practice-evidence')
);
--> statement-breakpoint
ALTER TABLE "evidence_artifact_revisions" ADD CONSTRAINT "evidence_artifact_revisions_artifact_owner_fk" FOREIGN KEY ("artifact_id","user_id") REFERENCES "public"."evidence_artifacts"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "evidence_artifact_revisions" ADD CONSTRAINT "evidence_artifact_revisions_supersedes_owner_artifact_fk" FOREIGN KEY ("supersedes_revision_id","user_id","artifact_id") REFERENCES "public"."evidence_artifact_revisions"("id","user_id","artifact_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "evidence_artifacts" ADD CONSTRAINT "evidence_artifacts_user_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_accounts"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "evidence_artifacts" ADD CONSTRAINT "evidence_artifacts_consent_owner_fk" FOREIGN KEY ("consent_record_id","user_id") REFERENCES "public"."consent_records"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "evidence_artifacts" ADD CONSTRAINT "evidence_artifacts_lesson_owner_fk" FOREIGN KEY ("source_lesson_attempt_id","user_id") REFERENCES "public"."lesson_attempts"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "evidence_artifacts" ADD CONSTRAINT "evidence_artifacts_practice_owner_lesson_fk" FOREIGN KEY ("source_practice_attempt_id","user_id","source_lesson_attempt_id") REFERENCES "public"."practice_attempts"("id","user_id","lesson_attempt_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "evidence_competency_links" ADD CONSTRAINT "evidence_competency_links_artifact_owner_fk" FOREIGN KEY ("artifact_id","user_id") REFERENCES "public"."evidence_artifacts"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "evidence_competency_links" ADD CONSTRAINT "evidence_competency_links_competency_framework_fk" FOREIGN KEY ("competency_version_id","framework_version_id") REFERENCES "public"."competency_versions"("id","framework_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
CREATE UNIQUE INDEX "evidence_artifact_revisions_artifact_revision_unique" ON "evidence_artifact_revisions" USING btree ("artifact_id","revision");--> statement-breakpoint
CREATE UNIQUE INDEX "evidence_artifact_revisions_artifact_mutation_unique" ON "evidence_artifact_revisions" USING btree ("artifact_id","client_mutation_id");--> statement-breakpoint
CREATE INDEX "evidence_artifact_revisions_owner_created_idx" ON "evidence_artifact_revisions" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "evidence_artifacts_owner_source_contract_unique" ON "evidence_artifacts" USING btree ("user_id","source_practice_attempt_id","artifact_contract_id","artifact_contract_version");--> statement-breakpoint
CREATE UNIQUE INDEX "evidence_artifacts_owner_start_mutation_unique" ON "evidence_artifacts" USING btree ("user_id","start_mutation_id");--> statement-breakpoint
CREATE INDEX "evidence_artifacts_owner_updated_idx" ON "evidence_artifacts" USING btree ("user_id","updated_at");--> statement-breakpoint
CREATE UNIQUE INDEX "evidence_competency_links_artifact_unique" ON "evidence_competency_links" USING btree ("artifact_id");--> statement-breakpoint
CREATE INDEX "evidence_competency_links_owner_created_idx" ON "evidence_competency_links" USING btree ("user_id","created_at");
--> statement-breakpoint
ALTER TABLE "evidence_artifacts" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "evidence_artifacts" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "evidence_artifact_revisions" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "evidence_artifact_revisions" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "evidence_competency_links" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "evidence_competency_links" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint

CREATE POLICY "evidence_artifacts_owner_select_policy" ON "evidence_artifacts"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "evidence_artifacts_owner_insert_policy" ON "evidence_artifacts"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "evidence_artifacts_owner_update_policy" ON "evidence_artifacts"
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
CREATE POLICY "evidence_artifact_revisions_owner_select_policy" ON "evidence_artifact_revisions"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "evidence_artifact_revisions_owner_insert_policy" ON "evidence_artifact_revisions"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "evidence_competency_links_owner_select_policy" ON "evidence_competency_links"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "evidence_competency_links_owner_insert_policy" ON "evidence_competency_links"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint

GRANT USAGE ON TYPE "evidence_artifact_status" TO "rise_pals_app";
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "evidence_artifacts" TO "rise_pals_app";
--> statement-breakpoint
GRANT UPDATE (
  "status",
  "ready_mutation_id",
  "ready_mutation_locale",
  "ready_expected_revision",
  "withdraw_mutation_id",
  "withdraw_mutation_locale",
  "withdraw_expected_revision"
) ON TABLE "evidence_artifacts" TO "rise_pals_app";
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "evidence_artifact_revisions" TO "rise_pals_app";
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "evidence_competency_links" TO "rise_pals_app";
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."assert_source_verification_evidence_payload"(
  target_payload jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
DECLARE
  source_count integer;
  distinct_source_count integer;
  ordered_ranks integer[];
  sorted_ranks integer[];
BEGIN
  IF jsonb_typeof(target_payload) <> 'object'
    OR target_payload->>'schemaVersion' <> 'source-verification-note-artifact-payload-v1'
    OR (SELECT count(*) FROM jsonb_object_keys(target_payload)) <> 6
    OR NOT (target_payload ?& ARRAY[
      'schemaVersion',
      'claimId',
      'sourceReferenceIds',
      'fitCheckId',
      'correctedWordingOptionId',
      'safeNextActionOptionId'
    ]) THEN
    RAISE EXCEPTION 'Evidence payload must use the exact versioned contract.';
  END IF;

  IF NOT (
      target_payload->'claimId' = 'null'::jsonb
      OR (
        jsonb_typeof(target_payload->'claimId') = 'string'
        AND target_payload->>'claimId' = 'bright-river-ai-summary-claim-v1'
      )
    )
    OR NOT (
      target_payload->'fitCheckId' = 'null'::jsonb
      OR (
        jsonb_typeof(target_payload->'fitCheckId') = 'string'
        AND target_payload->>'fitCheckId' IN (
          'supported',
          'partially-supported-overgeneralized',
          'unsupported'
        )
      )
    )
    OR NOT (
      target_payload->'correctedWordingOptionId' = 'null'::jsonb
      OR (
        jsonb_typeof(target_payload->'correctedWordingOptionId') = 'string'
        AND target_payload->>'correctedWordingOptionId' IN (
          'fit-narrow-to-supported-teams',
          'fit-keep-all-team-claim',
          'fit-convert-to-broad-average'
        )
      )
    )
    OR NOT (
      target_payload->'safeNextActionOptionId' = 'null'::jsonb
      OR (
        jsonb_typeof(target_payload->'safeNextActionOptionId') = 'string'
        AND target_payload->>'safeNextActionOptionId' IN (
          'safe-hold-and-resolve-gaps',
          'safe-publish-with-small-note',
          'safe-ask-ai-for-confidence'
        )
      )
    ) THEN
    RAISE EXCEPTION 'Evidence payload contains an unknown controlled value.';
  END IF;

  IF jsonb_typeof(target_payload->'sourceReferenceIds') <> 'array' THEN
    RAISE EXCEPTION 'Evidence source references must be an array.';
  END IF;

  SELECT count(*)::integer,
         count(DISTINCT source_id)::integer,
         array_agg(
           CASE source_id
             WHEN 'pilot-table' THEN 1
             WHEN 'scope-note' THEN 2
             WHEN 'risk-log' THEN 3
           END
           ORDER BY ordinal
         ),
         array_agg(
           CASE source_id
             WHEN 'pilot-table' THEN 1
             WHEN 'scope-note' THEN 2
             WHEN 'risk-log' THEN 3
           END
           ORDER BY CASE source_id
             WHEN 'pilot-table' THEN 1
             WHEN 'scope-note' THEN 2
             WHEN 'risk-log' THEN 3
           END
         )
    INTO source_count, distinct_source_count, ordered_ranks, sorted_ranks
  FROM jsonb_array_elements_text(target_payload->'sourceReferenceIds')
    WITH ORDINALITY AS source_entry(source_id, ordinal);

  IF source_count > 3
    OR source_count <> distinct_source_count
    OR ordered_ranks IS DISTINCT FROM sorted_ranks
    OR EXISTS (
      SELECT 1
      FROM jsonb_array_elements(target_payload->'sourceReferenceIds') AS source_entry(source_value)
      WHERE jsonb_typeof(source_value) <> 'string'
        OR source_value #>> '{}' NOT IN ('pilot-table', 'scope-note', 'risk-log')
    ) THEN
    RAISE EXCEPTION 'Evidence source references are unknown, duplicated, or out of order.';
  END IF;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."assert_source_verification_evidence_payload"(jsonb)
  FROM PUBLIC;
--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."assert_source_verification_evidence_payload"(jsonb)
  TO "rise_pals_app";
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."is_source_verification_evidence_ready"(
  target_payload jsonb
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
BEGIN
  PERFORM "rise_pals_private"."assert_source_verification_evidence_payload"(target_payload);
  RETURN target_payload->>'claimId' = 'bright-river-ai-summary-claim-v1'
    AND target_payload->'sourceReferenceIds' = '["pilot-table","scope-note","risk-log"]'::jsonb
    AND target_payload->>'fitCheckId' = 'partially-supported-overgeneralized'
    AND target_payload->>'correctedWordingOptionId' = 'fit-narrow-to-supported-teams'
    AND target_payload->>'safeNextActionOptionId' = 'safe-hold-and-resolve-gaps';
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."is_source_verification_evidence_ready"(jsonb)
  FROM PUBLIC;
--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."is_source_verification_evidence_ready"(jsonb)
  TO "rise_pals_app";
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_evidence_artifact"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  current_consent_id uuid;
  source_lesson lesson_attempts%ROWTYPE;
  source_practice practice_attempts%ROWTYPE;
  latest_revision integer;
  latest_payload jsonb;
  lifecycle_time timestamptz;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Evidence artifact history cannot be deleted.';
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
    RAISE EXCEPTION 'Evidence artifact requires the exact current consent receipt.';
  END IF;

  IF TG_OP = 'INSERT' THEN
    SELECT * INTO source_lesson
    FROM lesson_attempts
    WHERE id = NEW.source_lesson_attempt_id AND user_id = NEW.user_id
    FOR UPDATE;
    SELECT * INTO source_practice
    FROM practice_attempts
    WHERE id = NEW.source_practice_attempt_id
      AND lesson_attempt_id = NEW.source_lesson_attempt_id
      AND user_id = NEW.user_id;

    IF source_lesson.id IS NULL
      OR source_lesson.status <> 'demonstrated'
      OR source_lesson.lesson_key <> 'source-verification-practice'
      OR source_lesson.lesson_version_id <> 'lesson-source-verification-practice-v1'
      OR source_lesson.lesson_version <> '1.0.0'
      OR source_lesson.lesson_digest <> '51903ea9e6053a1102b4d60ad072c9a1dcde26a90d6a0ca7ae36cba8a6995e91'
      OR source_lesson.practice_id <> 'source-verification-decision-v1'
      OR source_lesson.practice_version <> '1.0.0'
      OR source_lesson.rubric_version_id <> 'source-verification-rubric-v1'
      OR source_lesson.rubric_version <> '1.0.0'
      OR source_lesson.evaluation_contract_version_id <> 'source-verification-evaluation-v1'
      OR source_practice.id IS NULL
      OR source_practice.status <> 'evaluated'
      OR source_practice.demonstrated IS NOT true
      OR EXISTS (
        SELECT 1 FROM practice_attempts AS newer
        WHERE newer.lesson_attempt_id = source_practice.lesson_attempt_id
          AND newer.user_id = source_practice.user_id
          AND newer.revision > source_practice.revision
      ) THEN
      RAISE EXCEPTION 'Evidence artifact requires the exact demonstrated source practice.';
    END IF;

    lifecycle_time := clock_timestamp();
    NEW.status := 'draft';
    NEW.created_at := lifecycle_time;
    NEW.updated_at := lifecycle_time;
    NEW.ready_mutation_id := NULL;
    NEW.ready_mutation_locale := NULL;
    NEW.ready_expected_revision := NULL;
    NEW.withdraw_mutation_id := NULL;
    NEW.withdraw_mutation_locale := NULL;
    NEW.withdraw_expected_revision := NULL;
    NEW.ready_at := NULL;
    NEW.withdrawn_at := NULL;
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
    OR NEW.user_id IS DISTINCT FROM OLD.user_id
    OR NEW.consent_record_id IS DISTINCT FROM OLD.consent_record_id
    OR NEW.source_lesson_attempt_id IS DISTINCT FROM OLD.source_lesson_attempt_id
    OR NEW.source_practice_attempt_id IS DISTINCT FROM OLD.source_practice_attempt_id
    OR NEW.artifact_contract_id IS DISTINCT FROM OLD.artifact_contract_id
    OR NEW.artifact_contract_version IS DISTINCT FROM OLD.artifact_contract_version
    OR NEW.artifact_type IS DISTINCT FROM OLD.artifact_type
    OR NEW.source_proof_id IS DISTINCT FROM OLD.source_proof_id
    OR NEW.source_proof_version IS DISTINCT FROM OLD.source_proof_version
    OR NEW.source_lesson_key IS DISTINCT FROM OLD.source_lesson_key
    OR NEW.source_lesson_version IS DISTINCT FROM OLD.source_lesson_version
    OR NEW.source_lesson_digest IS DISTINCT FROM OLD.source_lesson_digest
    OR NEW.source_pack_id IS DISTINCT FROM OLD.source_pack_id
    OR NEW.classification IS DISTINCT FROM OLD.classification
    OR NEW.validation_status IS DISTINCT FROM OLD.validation_status
    OR NEW.start_mutation_id IS DISTINCT FROM OLD.start_mutation_id
    OR NEW.start_mutation_locale IS DISTINCT FROM OLD.start_mutation_locale
    OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Evidence artifact identity and provenance are immutable.';
  END IF;

  lifecycle_time := clock_timestamp();
  IF NEW.status = OLD.status THEN
    IF current_user <> 'rise_pals_owner'
      OR NEW.ready_mutation_id IS DISTINCT FROM OLD.ready_mutation_id
      OR NEW.ready_mutation_locale IS DISTINCT FROM OLD.ready_mutation_locale
      OR NEW.ready_expected_revision IS DISTINCT FROM OLD.ready_expected_revision
      OR NEW.withdraw_mutation_id IS DISTINCT FROM OLD.withdraw_mutation_id
      OR NEW.withdraw_mutation_locale IS DISTINCT FROM OLD.withdraw_mutation_locale
      OR NEW.withdraw_expected_revision IS DISTINCT FROM OLD.withdraw_expected_revision
      OR NEW.ready_at IS DISTINCT FROM OLD.ready_at
      OR NEW.withdrawn_at IS DISTINCT FROM OLD.withdrawn_at THEN
      RAISE EXCEPTION 'Evidence artifact lifecycle transition is invalid.';
    END IF;
    NEW.updated_at := lifecycle_time;
    RETURN NEW;
  END IF;

  SELECT revision, payload INTO latest_revision, latest_payload
  FROM evidence_artifact_revisions
  WHERE artifact_id = OLD.id AND user_id = OLD.user_id
  ORDER BY revision DESC
  LIMIT 1;
  latest_revision := coalesce(latest_revision, 0);

  IF OLD.status = 'draft' AND NEW.status = 'ready' THEN
    IF NEW.ready_mutation_id IS NULL
      OR NEW.ready_mutation_locale NOT IN ('th', 'en')
      OR NEW.ready_expected_revision IS DISTINCT FROM latest_revision
      OR NEW.ready_mutation_id = OLD.start_mutation_id
      OR latest_revision = 0
      OR NOT "rise_pals_private"."is_source_verification_evidence_ready"(latest_payload)
      OR NEW.withdraw_mutation_id IS NOT NULL
      OR NEW.withdraw_mutation_locale IS NOT NULL
      OR NEW.withdraw_expected_revision IS NOT NULL THEN
      RAISE EXCEPTION 'Evidence artifact is not ready under the canonical checklist.';
    END IF;
    NEW.ready_at := lifecycle_time;
    NEW.withdrawn_at := NULL;
  ELSIF OLD.status IN ('draft', 'ready') AND NEW.status = 'withdrawn' THEN
    IF NEW.withdraw_mutation_id IS NULL
      OR NEW.withdraw_mutation_locale NOT IN ('th', 'en')
      OR NEW.withdraw_expected_revision IS DISTINCT FROM latest_revision
      OR NEW.withdraw_mutation_id = OLD.start_mutation_id
      OR NEW.withdraw_mutation_id IS NOT DISTINCT FROM OLD.ready_mutation_id
      OR NEW.ready_mutation_id IS DISTINCT FROM OLD.ready_mutation_id
      OR NEW.ready_mutation_locale IS DISTINCT FROM OLD.ready_mutation_locale
      OR NEW.ready_expected_revision IS DISTINCT FROM OLD.ready_expected_revision
      OR NEW.ready_at IS DISTINCT FROM OLD.ready_at THEN
      RAISE EXCEPTION 'Evidence artifact withdrawal provenance is invalid.';
    END IF;
    NEW.withdrawn_at := lifecycle_time;
  ELSE
    RAISE EXCEPTION 'Evidence artifact lifecycle transition is invalid.';
  END IF;

  NEW.updated_at := lifecycle_time;
  RETURN NEW;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_evidence_artifact"() FROM PUBLIC;
--> statement-breakpoint
CREATE TRIGGER "evidence_artifacts_guard"
  BEFORE INSERT OR UPDATE OR DELETE ON "evidence_artifacts"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_evidence_artifact"();
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_evidence_artifact_revision"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  parent evidence_artifacts%ROWTYPE;
  prior evidence_artifact_revisions%ROWTYPE;
  current_consent_id uuid;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'Evidence artifact revisions are immutable.';
  END IF;

  PERFORM "rise_pals_private"."assert_current_service_grant"(NEW.user_id);
  SELECT * INTO parent
  FROM evidence_artifacts
  WHERE id = NEW.artifact_id AND user_id = NEW.user_id
  FOR UPDATE;
  IF parent.id IS NULL OR parent.status <> 'draft' THEN
    RAISE EXCEPTION 'Evidence revisions require an editable owner draft.';
  END IF;

  SELECT id INTO current_consent_id
  FROM consent_records
  WHERE user_id = NEW.user_id
    AND purpose_code = 'service-profile-learning-state'
    AND notice_version = 'alpha-privacy-v1'
  ORDER BY occurred_at DESC, id DESC
  LIMIT 1;
  IF current_consent_id IS NULL OR current_consent_id <> parent.consent_record_id THEN
    RAISE EXCEPTION 'Evidence revision requires the exact current consent receipt.';
  END IF;

  IF NEW.artifact_contract_id <> parent.artifact_contract_id
    OR NEW.artifact_contract_version <> parent.artifact_contract_version
    OR NEW.source_pack_id <> parent.source_pack_id THEN
    RAISE EXCEPTION 'Evidence revision compatibility does not match its artifact.';
  END IF;

  SELECT * INTO prior
  FROM evidence_artifact_revisions
  WHERE artifact_id = NEW.artifact_id AND user_id = NEW.user_id
  ORDER BY revision DESC
  LIMIT 1;
  IF prior.id IS NULL THEN
    IF NEW.revision <> 1
      OR NEW.mutation_expected_revision <> 0
      OR NEW.supersedes_revision_id IS NOT NULL THEN
      RAISE EXCEPTION 'The first evidence revision has invalid provenance.';
    END IF;
  ELSIF NEW.revision <> prior.revision + 1
    OR NEW.mutation_expected_revision <> prior.revision
    OR NEW.supersedes_revision_id IS DISTINCT FROM prior.id THEN
    RAISE EXCEPTION 'Evidence revision must append to the current owner revision.';
  END IF;

  PERFORM "rise_pals_private"."assert_source_verification_evidence_payload"(NEW.payload);
  NEW.created_at := clock_timestamp();
  UPDATE evidence_artifacts
  SET updated_at = clock_timestamp()
  WHERE id = NEW.artifact_id AND user_id = NEW.user_id;
  RETURN NEW;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_evidence_artifact_revision"() FROM PUBLIC;
--> statement-breakpoint
CREATE TRIGGER "evidence_artifact_revisions_guard"
  BEFORE INSERT OR UPDATE OR DELETE ON "evidence_artifact_revisions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_evidence_artifact_revision"();
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_evidence_competency_link"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  parent evidence_artifacts%ROWTYPE;
  framework framework_versions%ROWTYPE;
  competency competency_versions%ROWTYPE;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION 'Evidence competency links are immutable.';
  END IF;
  PERFORM "rise_pals_private"."assert_current_service_grant"(NEW.user_id);
  SELECT * INTO parent
  FROM evidence_artifacts
  WHERE id = NEW.artifact_id AND user_id = NEW.user_id
  FOR UPDATE;
  SELECT * INTO framework
  FROM framework_versions
  WHERE id = NEW.framework_version_id;
  SELECT * INTO competency
  FROM competency_versions
  WHERE id = NEW.competency_version_id
    AND framework_version_id = NEW.framework_version_id;

  IF parent.id IS NULL
    OR framework.id IS NULL
    OR framework.framework_key <> 'rise-pals-8-plus-2'
    OR framework.version <> '2.0'
    OR framework.status <> 'published'
    OR competency.id IS NULL
    OR competency.competency_key <> 'critical-thinking-fact-checking'
    OR competency.kind <> 'core'
    OR NEW.relationship_code <> 'synthetic-practice-evidence' THEN
    RAISE EXCEPTION 'Evidence competency link must use the accepted Critical Thinking version.';
  END IF;
  NEW.created_at := clock_timestamp();
  RETURN NEW;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_evidence_competency_link"() FROM PUBLIC;
--> statement-breakpoint
CREATE TRIGGER "evidence_competency_links_guard"
  BEFORE INSERT OR UPDATE OR DELETE ON "evidence_competency_links"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_evidence_competency_link"();
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."assert_evidence_competency_link_complete"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  target_artifact_id uuid;
  link_count integer;
BEGIN
  IF TG_TABLE_NAME = 'evidence_artifacts' THEN
    target_artifact_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
  ELSE
    target_artifact_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.artifact_id ELSE NEW.artifact_id END;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM evidence_artifacts WHERE id = target_artifact_id) THEN
    RETURN NULL;
  END IF;
  SELECT count(*)::integer INTO link_count
  FROM evidence_competency_links
  WHERE artifact_id = target_artifact_id;
  IF link_count <> 1 THEN
    RAISE EXCEPTION 'Every evidence artifact requires one exact competency link.';
  END IF;
  RETURN NULL;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."assert_evidence_competency_link_complete"()
  FROM PUBLIC;
--> statement-breakpoint
CREATE CONSTRAINT TRIGGER "evidence_artifacts_competency_complete"
  AFTER INSERT OR UPDATE OR DELETE ON "evidence_artifacts"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_evidence_competency_link_complete"();
--> statement-breakpoint
CREATE CONSTRAINT TRIGGER "evidence_competency_links_complete"
  AFTER INSERT OR UPDATE OR DELETE ON "evidence_competency_links"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_evidence_competency_link_complete"();
