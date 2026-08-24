CREATE TABLE "error_occurrences" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"measurement_subject_id" uuid NOT NULL,
	"schema_version" text NOT NULL,
	"correlation_id" uuid NOT NULL,
	"operation_code" text NOT NULL,
	"surface_code" text NOT NULL,
	"locale" text NOT NULL,
	"error_category" text NOT NULL,
	"severity" text NOT NULL,
	"retryable" boolean NOT NULL,
	"occurred_at" timestamp with time zone NOT NULL,
	"mutation_digest" text,
	CONSTRAINT "error_occurrences_schema_check" CHECK ("error_occurrences"."schema_version" = 'redacted-error-occurrence-v1'),
	CONSTRAINT "error_occurrences_surface_check" CHECK ("error_occurrences"."surface_code" IN ('assessment', 'result', 'lesson_practice', 'private_evidence')),
	CONSTRAINT "error_occurrences_operation_check" CHECK (("error_occurrences"."surface_code" = 'assessment' AND "error_occurrences"."operation_code" = 'assessment_response_saved') OR ("error_occurrences"."surface_code" = 'result' AND "error_occurrences"."operation_code" = 'result_generated') OR ("error_occurrences"."surface_code" = 'lesson_practice' AND "error_occurrences"."operation_code" IN ('lesson_started', 'lesson_practice_saved', 'lesson_practice_evaluated', 'lesson_practice_retry_started')) OR ("error_occurrences"."surface_code" = 'private_evidence' AND "error_occurrences"."operation_code" IN ('private_evidence_started', 'private_evidence_saved', 'private_evidence_marked_ready', 'private_evidence_withdrawn'))),
	CONSTRAINT "error_occurrences_locale_check" CHECK ("error_occurrences"."locale" IN ('th', 'en')),
	CONSTRAINT "error_occurrences_category_check" CHECK ("error_occurrences"."error_category" IN ('unexpected_database', 'unexpected_identity', 'unexpected_domain', 'unexpected_internal')),
	CONSTRAINT "error_occurrences_severity_check" CHECK ("error_occurrences"."severity" IN ('warning', 'error')),
	CONSTRAINT "error_occurrences_digest_check" CHECK ("error_occurrences"."mutation_digest" IS NULL OR "error_occurrences"."mutation_digest" ~ '^[0-9a-f]{64}$')
);
--> statement-breakpoint
CREATE TABLE "measurement_subjects" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"consent_record_id" uuid NOT NULL,
	"subject_schema_version" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "measurement_subjects_id_user_unique" UNIQUE("id","user_id"),
	CONSTRAINT "measurement_subjects_schema_check" CHECK ("measurement_subjects"."subject_schema_version" = 'measurement-subject-v1')
);
--> statement-breakpoint
CREATE TABLE "product_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"measurement_subject_id" uuid NOT NULL,
	"schema_version" text NOT NULL,
	"event_class" text NOT NULL,
	"surface_code" text NOT NULL,
	"operation_code" text NOT NULL,
	"action_digest" text NOT NULL,
	"occurred_at" timestamp with time zone NOT NULL,
	CONSTRAINT "product_events_schema_check" CHECK ("product_events"."schema_version" = 'product-measurement-v1'),
	CONSTRAINT "product_events_class_check" CHECK ("product_events"."event_class" IN ('activation_completed', 'meaningful_return_completed')),
	CONSTRAINT "product_events_surface_check" CHECK ("product_events"."surface_code" IN ('assessment', 'result', 'lesson_practice', 'private_evidence')),
	CONSTRAINT "product_events_operation_check" CHECK (("product_events"."surface_code" = 'assessment' AND "product_events"."operation_code" = 'assessment_response_saved') OR ("product_events"."surface_code" = 'result' AND "product_events"."operation_code" = 'result_generated') OR ("product_events"."surface_code" = 'lesson_practice' AND "product_events"."operation_code" IN ('lesson_started', 'lesson_practice_saved', 'lesson_practice_evaluated', 'lesson_practice_retry_started')) OR ("product_events"."surface_code" = 'private_evidence' AND "product_events"."operation_code" IN ('private_evidence_started', 'private_evidence_saved', 'private_evidence_marked_ready', 'private_evidence_withdrawn'))),
	CONSTRAINT "product_events_digest_check" CHECK ("product_events"."action_digest" ~ '^[0-9a-f]{64}$')
);
--> statement-breakpoint
ALTER TABLE "error_occurrences" ADD CONSTRAINT "error_occurrences_measurement_subject_id_measurement_subjects_id_fk" FOREIGN KEY ("measurement_subject_id") REFERENCES "public"."measurement_subjects"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "measurement_subjects" ADD CONSTRAINT "measurement_subjects_user_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_accounts"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "measurement_subjects" ADD CONSTRAINT "measurement_subjects_consent_owner_fk" FOREIGN KEY ("consent_record_id","user_id") REFERENCES "public"."consent_records"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "product_events" ADD CONSTRAINT "product_events_measurement_subject_id_measurement_subjects_id_fk" FOREIGN KEY ("measurement_subject_id") REFERENCES "public"."measurement_subjects"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
CREATE UNIQUE INDEX "error_occurrences_correlation_unique" ON "error_occurrences" USING btree ("correlation_id");--> statement-breakpoint
CREATE INDEX "error_occurrences_subject_occurred_idx" ON "error_occurrences" USING btree ("measurement_subject_id","occurred_at");--> statement-breakpoint
CREATE UNIQUE INDEX "measurement_subjects_owner_consent_unique" ON "measurement_subjects" USING btree ("user_id","consent_record_id");--> statement-breakpoint
CREATE INDEX "measurement_subjects_owner_created_idx" ON "measurement_subjects" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "product_events_subject_action_unique" ON "product_events" USING btree ("measurement_subject_id","action_digest");--> statement-breakpoint
CREATE INDEX "product_events_subject_occurred_idx" ON "product_events" USING btree ("measurement_subject_id","occurred_at");
--> statement-breakpoint
CREATE FUNCTION "rise_pals_private"."is_current_measurement_consent"(
  candidate_consent_id uuid,
  candidate_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM consent_records AS candidate
    WHERE candidate.id = candidate_consent_id
      AND candidate.user_id = candidate_user_id
      AND candidate.purpose_code = 'measurement-monitoring'
      AND candidate.notice_version = 'alpha-measurement-monitoring-v1'
      AND candidate.decision = 'granted'
      AND candidate.proof_digest = '36fda7d28f3db1120c8f9ab8211e038cb1579b6eb3e1f3b942d080e7c4735a78'
      AND NOT EXISTS (
        SELECT 1
        FROM consent_records AS newer
        WHERE newer.user_id = candidate.user_id
          AND newer.purpose_code = candidate.purpose_code
          AND (newer.occurred_at, newer.id) > (candidate.occurred_at, candidate.id)
      )
  );
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."is_current_measurement_consent"(uuid, uuid) FROM PUBLIC;
--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."is_current_measurement_consent"(uuid, uuid)
  TO "rise_pals_app", "rise_pals_owner";
--> statement-breakpoint
ALTER TABLE "measurement_subjects" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "measurement_subjects" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "product_events" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "product_events" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "error_occurrences" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "error_occurrences" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint
CREATE POLICY "measurement_subjects_owner_select_policy" ON "measurement_subjects"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."is_current_measurement_consent"("consent_record_id", "user_id")
  );
--> statement-breakpoint
CREATE POLICY "measurement_subjects_owner_insert_policy" ON "measurement_subjects"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."is_current_measurement_consent"("consent_record_id", "user_id")
  );
--> statement-breakpoint
CREATE POLICY "product_events_owner_select_policy" ON "product_events"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (EXISTS (
    SELECT 1 FROM measurement_subjects AS subject
    WHERE subject.id = "product_events"."measurement_subject_id"
      AND subject.user_id = "rise_pals_private"."current_app_user_id"()
      AND "rise_pals_private"."is_current_measurement_consent"(
        subject.consent_record_id,
        subject.user_id
      )
  ));
--> statement-breakpoint
CREATE POLICY "product_events_owner_insert_policy" ON "product_events"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (EXISTS (
    SELECT 1 FROM measurement_subjects AS subject
    WHERE subject.id = "product_events"."measurement_subject_id"
      AND subject.user_id = "rise_pals_private"."current_app_user_id"()
      AND "rise_pals_private"."is_current_measurement_consent"(
        subject.consent_record_id,
        subject.user_id
      )
  ));
--> statement-breakpoint
CREATE POLICY "error_occurrences_owner_select_policy" ON "error_occurrences"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (EXISTS (
    SELECT 1 FROM measurement_subjects AS subject
    WHERE subject.id = "error_occurrences"."measurement_subject_id"
      AND subject.user_id = "rise_pals_private"."current_app_user_id"()
      AND "rise_pals_private"."is_current_measurement_consent"(
        subject.consent_record_id,
        subject.user_id
      )
  ));
--> statement-breakpoint
CREATE POLICY "error_occurrences_owner_insert_policy" ON "error_occurrences"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (EXISTS (
    SELECT 1 FROM measurement_subjects AS subject
    WHERE subject.id = "error_occurrences"."measurement_subject_id"
      AND subject.user_id = "rise_pals_private"."current_app_user_id"()
      AND "rise_pals_private"."is_current_measurement_consent"(
        subject.consent_record_id,
        subject.user_id
      )
  ));
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "measurement_subjects", "product_events", "error_occurrences"
  TO "rise_pals_app";
--> statement-breakpoint
CREATE FUNCTION "rise_pals_private"."reject_measurement_history_mutation"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
BEGIN
  RAISE EXCEPTION 'measurement and monitoring history is append-only' USING ERRCODE = '55000';
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."reject_measurement_history_mutation"() FROM PUBLIC;
--> statement-breakpoint
CREATE TRIGGER "measurement_subjects_append_only"
  BEFORE UPDATE OR DELETE ON "measurement_subjects"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."reject_measurement_history_mutation"();
--> statement-breakpoint
CREATE TRIGGER "product_events_append_only"
  BEFORE UPDATE OR DELETE ON "product_events"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."reject_measurement_history_mutation"();
--> statement-breakpoint
CREATE TRIGGER "error_occurrences_append_only"
  BEFORE UPDATE OR DELETE ON "error_occurrences"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."reject_measurement_history_mutation"();
