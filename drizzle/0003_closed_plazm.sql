CREATE TABLE "competency_scores" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"scoring_run_id" uuid NOT NULL,
	"framework_version_id" uuid NOT NULL,
	"competency_version_id" uuid NOT NULL,
	"target_kind" "competency_kind" NOT NULL,
	"earned_points" integer NOT NULL,
	"available_points" integer NOT NULL,
	"evidence_count" integer NOT NULL,
	"normalized_basis_points" integer NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "competency_scores_core_kind_check" CHECK ("competency_scores"."target_kind" = 'core'),
	CONSTRAINT "competency_scores_points_check" CHECK ("competency_scores"."available_points" > 0 AND "competency_scores"."earned_points" BETWEEN 0 AND "competency_scores"."available_points" AND "competency_scores"."evidence_count" > 0),
	CONSTRAINT "competency_scores_basis_points_check" CHECK ("competency_scores"."normalized_basis_points" = floor(("competency_scores"."earned_points"::numeric * 10000) / "competency_scores"."available_points")::integer)
);
--> statement-breakpoint
CREATE TABLE "multiplier_observations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"scoring_run_id" uuid NOT NULL,
	"framework_version_id" uuid NOT NULL,
	"competency_version_id" uuid NOT NULL,
	"target_kind" "competency_kind" NOT NULL,
	"earned_rubric_points" integer NOT NULL,
	"available_rubric_points" integer NOT NULL,
	"evidence_count" integer NOT NULL,
	"limitation_code" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "multiplier_observations_kind_check" CHECK ("multiplier_observations"."target_kind" = 'multiplier'),
	CONSTRAINT "multiplier_observations_points_check" CHECK ("multiplier_observations"."available_rubric_points" > 0 AND "multiplier_observations"."earned_rubric_points" BETWEEN 0 AND "multiplier_observations"."available_rubric_points" AND "multiplier_observations"."evidence_count" = 1),
	CONSTRAINT "multiplier_observations_limitation_check" CHECK ("multiplier_observations"."limitation_code" = 'single-scenario-not-behavior-pattern')
);
--> statement-breakpoint
CREATE TABLE "priority_recommendations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"scoring_run_id" uuid NOT NULL,
	"framework_version_id" uuid NOT NULL,
	"competency_version_id" uuid NOT NULL,
	"target_kind" "competency_kind" NOT NULL,
	"rank" integer NOT NULL,
	"reason_code" text NOT NULL,
	"supporting_item_keys" text[] NOT NULL,
	"next_action" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "priority_recommendations_core_kind_check" CHECK ("priority_recommendations"."target_kind" = 'core'),
	CONSTRAINT "priority_recommendations_rank_check" CHECK ("priority_recommendations"."rank" = 1),
	CONSTRAINT "priority_recommendations_reason_check" CHECK ("priority_recommendations"."reason_code" = 'unique-lowest-assessed-core-signal'),
	CONSTRAINT "priority_recommendations_items_check" CHECK (cardinality("priority_recommendations"."supporting_item_keys") > 0),
	CONSTRAINT "priority_recommendations_action_check" CHECK (jsonb_typeof("priority_recommendations"."next_action") = 'object' AND "priority_recommendations"."next_action"->>'kind' IN ('prototype-lesson', 'practice-unavailable'))
);
--> statement-breakpoint
CREATE TABLE "score_explanations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"scoring_run_id" uuid NOT NULL,
	"framework_version_id" uuid NOT NULL,
	"target_kind" text NOT NULL,
	"target_competency_kind" "competency_kind",
	"competency_version_id" uuid,
	"explanation_code" text NOT NULL,
	"message_params" jsonb NOT NULL,
	"supporting_item_keys" text[] NOT NULL,
	"limitation_codes" text[] NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "score_explanations_target_shape_check" CHECK (("score_explanations"."target_kind" = 'run' AND "score_explanations"."competency_version_id" IS NULL AND "score_explanations"."target_competency_kind" IS NULL AND "score_explanations"."explanation_code" = 'synthetic-partial-result-limitation') OR ("score_explanations"."target_kind" = 'core' AND "score_explanations"."competency_version_id" IS NOT NULL AND "score_explanations"."target_competency_kind" = 'core' AND "score_explanations"."explanation_code" = 'assessed-core-raw-signal') OR ("score_explanations"."target_kind" = 'multiplier' AND "score_explanations"."competency_version_id" IS NOT NULL AND "score_explanations"."target_competency_kind" = 'multiplier' AND "score_explanations"."explanation_code" = 'single-scenario-multiplier-observation') OR ("score_explanations"."target_kind" = 'priority' AND (("score_explanations"."competency_version_id" IS NOT NULL AND "score_explanations"."target_competency_kind" = 'core' AND "score_explanations"."explanation_code" = 'unique-lowest-assessed-core-signal') OR ("score_explanations"."competency_version_id" IS NULL AND "score_explanations"."target_competency_kind" IS NULL AND "score_explanations"."explanation_code" = 'no-distinct-priority')))),
	CONSTRAINT "score_explanations_params_check" CHECK (jsonb_typeof("score_explanations"."message_params") = 'object' AND "score_explanations"."message_params" = '{"schemaVersion":"persisted-result-explanation-params-v1"}'::jsonb),
	CONSTRAINT "score_explanations_limitations_check" CHECK (cardinality("score_explanations"."limitation_codes") > 0)
);
--> statement-breakpoint
CREATE TABLE "scoring_runs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"assessment_session_id" uuid NOT NULL,
	"assessment_version_id" uuid NOT NULL,
	"framework_version_id" uuid NOT NULL,
	"scoring_model_version_id" uuid NOT NULL,
	"run_number" integer NOT NULL,
	"run_kind" text NOT NULL,
	"supersedes_scoring_run_id" uuid,
	"client_mutation_id" uuid NOT NULL,
	"input_digest" text NOT NULL,
	"output_digest" text NOT NULL,
	"result_policy_key" text NOT NULL,
	"result_policy_version" text NOT NULL,
	"result_policy_digest" text NOT NULL,
	"computed_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "scoring_runs_id_user_unique" UNIQUE("id","user_id"),
	CONSTRAINT "scoring_runs_id_session_unique" UNIQUE("id","assessment_session_id"),
	CONSTRAINT "scoring_runs_id_framework_unique" UNIQUE("id","framework_version_id"),
	CONSTRAINT "scoring_runs_number_positive" CHECK ("scoring_runs"."run_number" > 0),
	CONSTRAINT "scoring_runs_kind_check" CHECK ("scoring_runs"."run_kind" IN ('normal', 'rescore')),
	CONSTRAINT "scoring_runs_supersession_shape_check" CHECK (("scoring_runs"."run_number" = 1 AND "scoring_runs"."run_kind" = 'normal' AND "scoring_runs"."supersedes_scoring_run_id" IS NULL) OR ("scoring_runs"."run_number" > 1 AND "scoring_runs"."run_kind" = 'rescore' AND "scoring_runs"."supersedes_scoring_run_id" IS NOT NULL)),
	CONSTRAINT "scoring_runs_input_digest_check" CHECK ("scoring_runs"."input_digest" ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "scoring_runs_output_digest_check" CHECK ("scoring_runs"."output_digest" ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "scoring_runs_policy_check" CHECK (
		"scoring_runs"."result_policy_key" = 'persisted-synthetic-priority-v1' -- gitleaks:allow -- public policy identity
		AND "scoring_runs"."result_policy_version" = '1.0.0'
		AND "scoring_runs"."result_policy_digest" = '10f2ab076828d50b228ff53d57332527dfe9d1b2769c4b57bd0476dd3c263157'
	)
);
--> statement-breakpoint
ALTER TABLE "competency_scores" ADD CONSTRAINT "competency_scores_run_owner_fk" FOREIGN KEY ("scoring_run_id","user_id") REFERENCES "public"."scoring_runs"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "competency_scores" ADD CONSTRAINT "competency_scores_run_framework_fk" FOREIGN KEY ("scoring_run_id","framework_version_id") REFERENCES "public"."scoring_runs"("id","framework_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "competency_scores" ADD CONSTRAINT "competency_scores_target_framework_kind_fk" FOREIGN KEY ("competency_version_id","framework_version_id","target_kind") REFERENCES "public"."competency_versions"("id","framework_version_id","kind") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "multiplier_observations" ADD CONSTRAINT "multiplier_observations_run_owner_fk" FOREIGN KEY ("scoring_run_id","user_id") REFERENCES "public"."scoring_runs"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "multiplier_observations" ADD CONSTRAINT "multiplier_observations_run_framework_fk" FOREIGN KEY ("scoring_run_id","framework_version_id") REFERENCES "public"."scoring_runs"("id","framework_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "multiplier_observations" ADD CONSTRAINT "multiplier_observations_target_framework_kind_fk" FOREIGN KEY ("competency_version_id","framework_version_id","target_kind") REFERENCES "public"."competency_versions"("id","framework_version_id","kind") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "priority_recommendations" ADD CONSTRAINT "priority_recommendations_run_owner_fk" FOREIGN KEY ("scoring_run_id","user_id") REFERENCES "public"."scoring_runs"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "priority_recommendations" ADD CONSTRAINT "priority_recommendations_run_framework_fk" FOREIGN KEY ("scoring_run_id","framework_version_id") REFERENCES "public"."scoring_runs"("id","framework_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "priority_recommendations" ADD CONSTRAINT "priority_recommendations_target_framework_kind_fk" FOREIGN KEY ("competency_version_id","framework_version_id","target_kind") REFERENCES "public"."competency_versions"("id","framework_version_id","kind") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "score_explanations" ADD CONSTRAINT "score_explanations_run_owner_fk" FOREIGN KEY ("scoring_run_id","user_id") REFERENCES "public"."scoring_runs"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "score_explanations" ADD CONSTRAINT "score_explanations_run_framework_fk" FOREIGN KEY ("scoring_run_id","framework_version_id") REFERENCES "public"."scoring_runs"("id","framework_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "score_explanations" ADD CONSTRAINT "score_explanations_target_framework_kind_fk" FOREIGN KEY ("competency_version_id","framework_version_id","target_competency_kind") REFERENCES "public"."competency_versions"("id","framework_version_id","kind") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "scoring_runs" ADD CONSTRAINT "scoring_runs_session_owner_fk" FOREIGN KEY ("assessment_session_id","user_id") REFERENCES "public"."assessment_sessions"("id","user_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "scoring_runs" ADD CONSTRAINT "scoring_runs_session_assessment_fk" FOREIGN KEY ("assessment_session_id","assessment_version_id") REFERENCES "public"."assessment_sessions"("id","assessment_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "scoring_runs" ADD CONSTRAINT "scoring_runs_assessment_framework_fk" FOREIGN KEY ("assessment_version_id","framework_version_id") REFERENCES "public"."assessment_versions"("id","framework_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "scoring_runs" ADD CONSTRAINT "scoring_runs_scoring_framework_fk" FOREIGN KEY ("scoring_model_version_id","framework_version_id") REFERENCES "public"."scoring_model_versions"("id","framework_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "scoring_runs" ADD CONSTRAINT "scoring_runs_supersedes_session_fk" FOREIGN KEY ("supersedes_scoring_run_id","assessment_session_id") REFERENCES "public"."scoring_runs"("id","assessment_session_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
CREATE UNIQUE INDEX "competency_scores_run_competency_unique" ON "competency_scores" USING btree ("scoring_run_id","competency_version_id");--> statement-breakpoint
CREATE UNIQUE INDEX "multiplier_observations_run_competency_unique" ON "multiplier_observations" USING btree ("scoring_run_id","competency_version_id");--> statement-breakpoint
CREATE UNIQUE INDEX "priority_recommendations_one_per_run" ON "priority_recommendations" USING btree ("scoring_run_id");--> statement-breakpoint
CREATE UNIQUE INDEX "score_explanations_run_target_unique" ON "score_explanations" USING btree ("scoring_run_id","target_kind","competency_version_id");--> statement-breakpoint
CREATE UNIQUE INDEX "scoring_runs_session_number_unique" ON "scoring_runs" USING btree ("assessment_session_id","run_number");--> statement-breakpoint
CREATE UNIQUE INDEX "scoring_runs_session_mutation_unique" ON "scoring_runs" USING btree ("assessment_session_id","client_mutation_id");--> statement-breakpoint
CREATE INDEX "scoring_runs_user_computed_idx" ON "scoring_runs" USING btree ("user_id","computed_at");
--> statement-breakpoint
CREATE UNIQUE INDEX "score_explanations_one_run_level_per_run"
  ON "score_explanations" ("scoring_run_id")
  WHERE "target_kind" = 'run';
--> statement-breakpoint
CREATE UNIQUE INDEX "score_explanations_one_priority_per_run"
  ON "score_explanations" ("scoring_run_id")
  WHERE "target_kind" = 'priority';
--> statement-breakpoint

ALTER TABLE "scoring_runs" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "scoring_runs" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "competency_scores" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "competency_scores" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "multiplier_observations" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "multiplier_observations" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "score_explanations" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "score_explanations" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "priority_recommendations" ENABLE ROW LEVEL SECURITY;
--> statement-breakpoint
ALTER TABLE "priority_recommendations" FORCE ROW LEVEL SECURITY;
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."has_current_service_grant"(target_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
  SELECT target_user_id = "rise_pals_private"."current_app_user_id"()
    AND EXISTS (
      SELECT 1 FROM user_accounts
      WHERE id = target_user_id AND status = 'active'
    )
    AND COALESCE((
      SELECT decision = 'granted'::consent_decision
      FROM consent_records
      WHERE user_id = target_user_id
        AND purpose_code = 'service-profile-learning-state'
        AND notice_version = 'alpha-privacy-v1'
      ORDER BY occurred_at DESC, id DESC
      LIMIT 1
    ), false);
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."has_current_service_grant"(uuid) FROM PUBLIC;
--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."has_current_service_grant"(uuid)
  TO "rise_pals_app";
--> statement-breakpoint

CREATE POLICY "scoring_runs_owner_select_policy" ON "scoring_runs"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "scoring_runs_owner_insert_policy" ON "scoring_runs"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "competency_scores_owner_select_policy" ON "competency_scores"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "competency_scores_owner_insert_policy" ON "competency_scores"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "multiplier_observations_owner_select_policy" ON "multiplier_observations"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "multiplier_observations_owner_insert_policy" ON "multiplier_observations"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "score_explanations_owner_select_policy" ON "score_explanations"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "score_explanations_owner_insert_policy" ON "score_explanations"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "priority_recommendations_owner_select_policy" ON "priority_recommendations"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint
CREATE POLICY "priority_recommendations_owner_insert_policy" ON "priority_recommendations"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK (
    "user_id" = "rise_pals_private"."current_app_user_id"()
    AND "rise_pals_private"."has_current_service_grant"("user_id")
  );
--> statement-breakpoint

GRANT SELECT, INSERT ON TABLE "scoring_runs" TO "rise_pals_app";
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "competency_scores" TO "rise_pals_app";
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "multiplier_observations" TO "rise_pals_app";
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "score_explanations" TO "rise_pals_app";
--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "priority_recommendations" TO "rise_pals_app";
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_scoring_run_insert"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  previous_run scoring_runs%ROWTYPE;
  required_count integer;
  active_count integer;
BEGIN
  PERFORM "rise_pals_private"."assert_current_service_grant"(NEW.user_id);

  IF NOT EXISTS (
    SELECT 1
    FROM assessment_sessions AS session
    JOIN assessment_versions AS assessment
      ON assessment.id = session.assessment_version_id
    WHERE session.id = NEW.assessment_session_id
      AND session.user_id = NEW.user_id
      AND session.status = 'submitted'
      AND assessment.id = NEW.assessment_version_id
      AND assessment.framework_version_id = NEW.framework_version_id
      AND assessment.scoring_model_version_id = NEW.scoring_model_version_id
      AND assessment.status = 'published'
  ) THEN
    RAISE EXCEPTION 'submitted compatible assessment evidence is required for scoring'
      USING ERRCODE = '23514';
  END IF;

  SELECT count(*) FILTER (WHERE item.required), count(response.id)
  INTO required_count, active_count
  FROM assessment_item_versions AS item
  LEFT JOIN assessment_responses AS response
    ON response.assessment_item_version_id = item.id
   AND response.session_id = NEW.assessment_session_id
   AND response.is_active
  WHERE item.assessment_version_id = NEW.assessment_version_id;

  IF required_count <> 6 OR active_count <> required_count THEN
    RAISE EXCEPTION 'complete active assessment evidence is required for scoring'
      USING ERRCODE = '23514';
  END IF;

  SELECT * INTO previous_run
  FROM scoring_runs
  WHERE assessment_session_id = NEW.assessment_session_id
  ORDER BY run_number DESC
  LIMIT 1;

  IF NEW.run_number = 1 THEN
    IF FOUND THEN
      RAISE EXCEPTION 'the initial scoring run already exists' USING ERRCODE = '23505';
    END IF;
  ELSIF NOT FOUND
    OR previous_run.id IS DISTINCT FROM NEW.supersedes_scoring_run_id
    OR previous_run.run_number + 1 <> NEW.run_number THEN
    RAISE EXCEPTION 're-score provenance must extend the current immutable run chain'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_scoring_run_insert"() FROM PUBLIC;
--> statement-breakpoint
CREATE TRIGGER "scoring_runs_insert_guard"
  BEFORE INSERT ON "scoring_runs"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_scoring_run_insert"();
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_derived_history_immutable"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
BEGIN
  RAISE EXCEPTION 'completed derived assessment history is immutable'
    USING ERRCODE = '55000';
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_derived_history_immutable"() FROM PUBLIC;
--> statement-breakpoint
CREATE TRIGGER "scoring_runs_immutable"
  BEFORE UPDATE OR DELETE ON "scoring_runs"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_derived_history_immutable"();
--> statement-breakpoint
CREATE TRIGGER "competency_scores_immutable"
  BEFORE UPDATE OR DELETE ON "competency_scores"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_derived_history_immutable"();
--> statement-breakpoint
CREATE TRIGGER "multiplier_observations_immutable"
  BEFORE UPDATE OR DELETE ON "multiplier_observations"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_derived_history_immutable"();
--> statement-breakpoint
CREATE TRIGGER "score_explanations_immutable"
  BEFORE UPDATE OR DELETE ON "score_explanations"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_derived_history_immutable"();
--> statement-breakpoint
CREATE TRIGGER "priority_recommendations_immutable"
  BEFORE UPDATE OR DELETE ON "priority_recommendations"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_derived_history_immutable"();
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."synthetic_option_rubric_points"(option_id text)
RETURNS integer
LANGUAGE sql
IMMUTABLE
STRICT
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
  SELECT CASE option_id
    WHEN 'verify-ai-summary-source-use-draft' THEN 0
    WHEN 'verify-ai-summary-source-check-claims' THEN 2
    WHEN 'verify-ai-summary-source-discard-all' THEN 1
    WHEN 'test-process-assumption-roll-out' THEN 0
    WHEN 'test-process-assumption-define-evidence' THEN 2
    WHEN 'test-process-assumption-wait-perfect' THEN 1
    WHEN 'map-downstream-impact-change-local' THEN 0
    WHEN 'map-downstream-impact-map-test' THEN 2
    WHEN 'map-downstream-impact-ask-separately' THEN 1
    WHEN 'trace-recurring-bottleneck-remind-final-team' THEN 0
    WHEN 'trace-recurring-bottleneck-trace-flow' THEN 2
    WHEN 'trace-recurring-bottleneck-add-status' THEN 1
    WHEN 'own-shared-outcome-complete-task' THEN 0
    WHEN 'own-shared-outcome-coordinate-fix' THEN 2
    WHEN 'own-shared-outcome-fix-own-copy' THEN 1
    WHEN 'move-with-safe-urgency-rush-all' THEN 0
    WHEN 'move-with-safe-urgency-small-step' THEN 2
    WHEN 'move-with-safe-urgency-wait-certainty' THEN 1
    ELSE NULL
  END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."synthetic_option_rubric_points"(text) FROM PUBLIC;
--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."synthetic_option_rubric_points"(text)
  TO "rise_pals_app";
--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."assert_scoring_run_complete"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  target_run_id uuid;
  core_count integer;
  multiplier_count integer;
  explanation_count integer;
  recommendation_count integer;
  lowest_count integer;
  lowest_competency_id uuid;
  priority_competency_id uuid;
  priority_explanation_code text;
BEGIN
  IF TG_TABLE_NAME = 'scoring_runs' THEN
    target_run_id := NEW.id;
  ELSE
    target_run_id := NEW.scoring_run_id;
  END IF;

  SELECT count(*) INTO core_count
  FROM competency_scores WHERE scoring_run_id = target_run_id;
  SELECT count(*) INTO multiplier_count
  FROM multiplier_observations WHERE scoring_run_id = target_run_id;
  SELECT count(*) INTO explanation_count
  FROM score_explanations WHERE scoring_run_id = target_run_id;
  SELECT count(*) INTO recommendation_count
  FROM priority_recommendations WHERE scoring_run_id = target_run_id;

  IF core_count <> 2 OR multiplier_count <> 2 OR explanation_count <> 6
    OR recommendation_count NOT IN (0, 1) THEN
    RAISE EXCEPTION 'a completed scoring run requires the exact synthetic result shape'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM competency_scores AS score
    JOIN scoring_runs AS run ON run.id = score.scoring_run_id
    JOIN competency_versions AS competency ON competency.id = score.competency_version_id
    WHERE score.scoring_run_id = target_run_id
      AND (
        competency.kind <> 'core'
        OR competency.competency_key NOT IN (
          'critical-thinking-fact-checking', 'systematic-thinking'
        )
        OR score.evidence_count <> 2
        OR score.available_points <> 4
      )
  ) THEN
    RAISE EXCEPTION 'core scores must contain only complete assessed-core evidence'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    WITH expected AS (
      SELECT mapping.competency_version_id,
             mapping.target_kind,
             count(*)::integer AS evidence_count,
             sum("rise_pals_private"."synthetic_option_rubric_points"(
               response.response_payload->>'selectedOptionId'
             ))::integer AS earned_points,
             (count(*) * 2)::integer AS available_points
      FROM scoring_runs AS run
      JOIN assessment_responses AS response
        ON response.session_id = run.assessment_session_id AND response.is_active
      JOIN assessment_item_competencies AS mapping
        ON mapping.assessment_item_version_id = response.assessment_item_version_id
      WHERE run.id = target_run_id
      GROUP BY mapping.competency_version_id, mapping.target_kind
    ), persisted AS (
      SELECT competency_version_id, 'core'::competency_kind AS target_kind,
             evidence_count, earned_points, available_points
      FROM competency_scores WHERE scoring_run_id = target_run_id
      UNION ALL
      SELECT competency_version_id, 'multiplier'::competency_kind AS target_kind,
             evidence_count, earned_rubric_points, available_rubric_points
      FROM multiplier_observations WHERE scoring_run_id = target_run_id
    )
    SELECT 1
    FROM expected
    FULL JOIN persisted USING (competency_version_id, target_kind)
    WHERE expected.competency_version_id IS NULL
       OR persisted.competency_version_id IS NULL
       OR expected.evidence_count IS DISTINCT FROM persisted.evidence_count
       OR expected.earned_points IS DISTINCT FROM persisted.earned_points
       OR expected.available_points IS DISTINCT FROM persisted.available_points
  ) THEN
    RAISE EXCEPTION 'derived points must reproduce the exact submitted option evidence'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM multiplier_observations AS observation
    JOIN competency_versions AS competency ON competency.id = observation.competency_version_id
    WHERE observation.scoring_run_id = target_run_id
      AND (
        competency.kind <> 'multiplier'
        OR competency.competency_key NOT IN ('ownership-thinking', 'sense-of-urgency')
        OR observation.evidence_count <> 1
        OR observation.available_rubric_points <> 2
      )
  ) THEN
    RAISE EXCEPTION 'multiplier observations must remain separate single-scenario evidence'
      USING ERRCODE = '23514';
  END IF;

  WITH candidates AS (
    SELECT competency_version_id, earned_points, available_points
    FROM competency_scores
    WHERE scoring_run_id = target_run_id
  ), lowest AS (
    SELECT candidate.competency_version_id
    FROM candidates AS candidate
    WHERE NOT EXISTS (
      SELECT 1
      FROM candidates AS other
      WHERE other.earned_points::bigint * candidate.available_points::bigint
          < candidate.earned_points::bigint * other.available_points::bigint
    )
  )
  SELECT count(*)::integer, (array_agg(competency_version_id))[1]
  INTO lowest_count, lowest_competency_id
  FROM lowest;

  SELECT competency_version_id INTO priority_competency_id
  FROM priority_recommendations
  WHERE scoring_run_id = target_run_id;
  SELECT explanation_code INTO priority_explanation_code
  FROM score_explanations
  WHERE scoring_run_id = target_run_id AND target_kind = 'priority';

  IF lowest_count = 1 THEN
    IF recommendation_count <> 1
      OR priority_competency_id IS DISTINCT FROM lowest_competency_id
      OR priority_explanation_code IS DISTINCT FROM 'unique-lowest-assessed-core-signal' THEN
      RAISE EXCEPTION 'a unique lowest assessed core requires one matching recommendation'
        USING ERRCODE = '23514';
    END IF;
  ELSIF recommendation_count <> 0
    OR priority_explanation_code IS DISTINCT FROM 'no-distinct-priority' THEN
    RAISE EXCEPTION 'a tied assessed-core ratio must not force a recommendation'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM score_explanations AS explanation
    LEFT JOIN competency_versions AS competency
      ON competency.id = explanation.competency_version_id
    WHERE explanation.scoring_run_id = target_run_id
      AND (
        explanation.supporting_item_keys <> CASE
          WHEN explanation.target_kind = 'run' THEN ARRAY[
            'verify-ai-summary-source', 'test-process-assumption',
            'map-downstream-impact', 'trace-recurring-bottleneck',
            'own-shared-outcome', 'move-with-safe-urgency'
          ]::text[]
          WHEN explanation.target_kind = 'core'
            AND competency.competency_key = 'critical-thinking-fact-checking'
            THEN ARRAY['verify-ai-summary-source', 'test-process-assumption']::text[]
          WHEN explanation.target_kind = 'core'
            AND competency.competency_key = 'systematic-thinking'
            THEN ARRAY['map-downstream-impact', 'trace-recurring-bottleneck']::text[]
          WHEN explanation.target_kind = 'multiplier'
            AND competency.competency_key = 'ownership-thinking'
            THEN ARRAY['own-shared-outcome']::text[]
          WHEN explanation.target_kind = 'multiplier'
            AND competency.competency_key = 'sense-of-urgency'
            THEN ARRAY['move-with-safe-urgency']::text[]
          WHEN explanation.target_kind = 'priority'
            AND explanation.explanation_code = 'no-distinct-priority'
            THEN ARRAY[]::text[]
          WHEN explanation.target_kind = 'priority'
            AND competency.competency_key = 'critical-thinking-fact-checking'
            THEN ARRAY['verify-ai-summary-source', 'test-process-assumption']::text[]
          WHEN explanation.target_kind = 'priority'
            AND competency.competency_key = 'systematic-thinking'
            THEN ARRAY['map-downstream-impact', 'trace-recurring-bottleneck']::text[]
          ELSE NULL
        END
      )
  ) THEN
    RAISE EXCEPTION 'score explanation item traces must match the exact assessment target'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM priority_recommendations AS recommendation
    JOIN competency_versions AS competency ON competency.id = recommendation.competency_version_id
    WHERE recommendation.scoring_run_id = target_run_id
      AND (
        recommendation.supporting_item_keys <> CASE competency.competency_key
          WHEN 'critical-thinking-fact-checking'
            THEN ARRAY['verify-ai-summary-source', 'test-process-assumption']::text[]
          WHEN 'systematic-thinking'
            THEN ARRAY['map-downstream-impact', 'trace-recurring-bottleneck']::text[]
          ELSE NULL
        END
        OR recommendation.next_action <> CASE competency.competency_key
          WHEN 'critical-thinking-fact-checking' THEN
            '{"kind":"prototype-lesson","lessonVersionId":"lesson-source-verification-practice-v1","lessonVersion":"1.0.0"}'::jsonb
          WHEN 'systematic-thinking' THEN '{"kind":"practice-unavailable"}'::jsonb
          ELSE NULL
        END
      )
  ) THEN
    RAISE EXCEPTION 'priority action must match the exact bounded competency contract'
      USING ERRCODE = '23514';
  END IF;

  RETURN NULL;
END;
$$;
--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."assert_scoring_run_complete"() FROM PUBLIC;
--> statement-breakpoint
CREATE CONSTRAINT TRIGGER "scoring_runs_complete_shape"
  AFTER INSERT ON "scoring_runs"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_scoring_run_complete"();
--> statement-breakpoint
CREATE CONSTRAINT TRIGGER "competency_scores_complete_shape"
  AFTER INSERT ON "competency_scores"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_scoring_run_complete"();
--> statement-breakpoint
CREATE CONSTRAINT TRIGGER "multiplier_observations_complete_shape"
  AFTER INSERT ON "multiplier_observations"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_scoring_run_complete"();
--> statement-breakpoint
CREATE CONSTRAINT TRIGGER "score_explanations_complete_shape"
  AFTER INSERT ON "score_explanations"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_scoring_run_complete"();
--> statement-breakpoint
CREATE CONSTRAINT TRIGGER "priority_recommendations_complete_shape"
  AFTER INSERT ON "priority_recommendations"
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."assert_scoring_run_complete"();
