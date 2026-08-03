CREATE SCHEMA "rise_pals_private";--> statement-breakpoint
REVOKE ALL ON SCHEMA "rise_pals_private" FROM PUBLIC;--> statement-breakpoint
CREATE FUNCTION "rise_pals_private"."is_versioned_json_object"(value jsonb)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT coalesce(
    jsonb_typeof(value) = 'object'
      AND jsonb_typeof(value -> 'schemaVersion') = 'string'
      AND length(btrim(value ->> 'schemaVersion')) > 0,
    false
  );
$$;--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."is_versioned_json_object"(jsonb) FROM PUBLIC;--> statement-breakpoint
CREATE TYPE "public"."account_status" AS ENUM('active', 'suspended', 'deletion_pending', 'deleted');--> statement-breakpoint
CREATE TYPE "public"."assessment_item_type" AS ENUM('scenario_choice', 'self_reflection');--> statement-breakpoint
CREATE TYPE "public"."competency_kind" AS ENUM('core', 'multiplier');--> statement-breakpoint
CREATE TYPE "public"."consent_decision" AS ENUM('granted', 'declined', 'withdrawn');--> statement-breakpoint
CREATE TYPE "public"."publication_status" AS ENUM('draft', 'published', 'retired');--> statement-breakpoint
CREATE TYPE "public"."scoring_method" AS ENUM('deterministic_rubric');--> statement-breakpoint
CREATE TABLE "assessment_item_competencies" (
	"assessment_item_version_id" uuid NOT NULL,
	"competency_version_id" uuid NOT NULL,
	"framework_version_id" uuid NOT NULL,
	"target_kind" "competency_kind" NOT NULL,
	"contribution_direction" integer DEFAULT 1 NOT NULL,
	"rationale_key" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "assessment_item_competencies_pk" PRIMARY KEY("assessment_item_version_id","competency_version_id"),
	CONSTRAINT "assessment_item_competencies_direction_check" CHECK ("assessment_item_competencies"."contribution_direction" IN (-1, 1)),
	CONSTRAINT "assessment_item_competencies_rationale_not_blank" CHECK (btrim("assessment_item_competencies"."rationale_key") <> '')
);
--> statement-breakpoint
CREATE TABLE "assessment_item_versions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"assessment_version_id" uuid NOT NULL,
	"framework_version_id" uuid NOT NULL,
	"item_key" text NOT NULL,
	"item_type" "assessment_item_type" NOT NULL,
	"prompt_i18n" jsonb NOT NULL,
	"response_schema" jsonb NOT NULL,
	"display_order" integer NOT NULL,
	"required" boolean DEFAULT true NOT NULL,
	"content_digest" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "assessment_item_versions_id_framework_unique" UNIQUE("id","framework_version_id"),
	CONSTRAINT "assessment_item_versions_key_not_blank" CHECK (btrim("assessment_item_versions"."item_key") <> ''),
	CONSTRAINT "assessment_item_versions_order_positive" CHECK ("assessment_item_versions"."display_order" > 0),
	CONSTRAINT "assessment_item_versions_prompt_json_check" CHECK (rise_pals_private.is_versioned_json_object("prompt_i18n")),
	CONSTRAINT "assessment_item_versions_response_json_check" CHECK (rise_pals_private.is_versioned_json_object("response_schema")),
	CONSTRAINT "assessment_item_versions_digest_check" CHECK ("assessment_item_versions"."content_digest" ~ '^[0-9a-f]{64}$')
);
--> statement-breakpoint
CREATE TABLE "assessment_versions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"assessment_key" text NOT NULL,
	"version" text NOT NULL,
	"framework_version_id" uuid NOT NULL,
	"scoring_model_version_id" uuid NOT NULL,
	"status" "publication_status" DEFAULT 'draft' NOT NULL,
	"estimated_minutes" integer NOT NULL,
	"published_at" timestamp with time zone,
	"content_digest" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "assessment_versions_id_framework_unique" UNIQUE("id","framework_version_id"),
	CONSTRAINT "assessment_versions_key_not_blank" CHECK (btrim("assessment_versions"."assessment_key") <> ''),
	CONSTRAINT "assessment_versions_version_not_blank" CHECK (btrim("assessment_versions"."version") <> ''),
	CONSTRAINT "assessment_versions_estimated_minutes_check" CHECK ("assessment_versions"."estimated_minutes" BETWEEN 1 AND 240),
	CONSTRAINT "assessment_versions_digest_check" CHECK ("assessment_versions"."content_digest" ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "assessment_versions_publication_timestamp_check" CHECK (("assessment_versions"."status" = 'draft' AND "assessment_versions"."published_at" IS NULL) OR ("assessment_versions"."status" <> 'draft' AND "assessment_versions"."published_at" IS NOT NULL))
);
--> statement-breakpoint
CREATE TABLE "competency_versions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"framework_version_id" uuid NOT NULL,
	"competency_key" text NOT NULL,
	"kind" "competency_kind" NOT NULL,
	"weight_basis_points" integer,
	"display_order" integer NOT NULL,
	"definition_i18n" jsonb NOT NULL,
	"behavior_anchors" jsonb NOT NULL,
	"content_digest" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "competency_versions_id_framework_unique" UNIQUE("id","framework_version_id"),
	CONSTRAINT "competency_versions_id_framework_kind_unique" UNIQUE("id","framework_version_id","kind"),
	CONSTRAINT "competency_versions_key_not_blank" CHECK (btrim("competency_versions"."competency_key") <> ''),
	CONSTRAINT "competency_versions_order_positive" CHECK ("competency_versions"."display_order" > 0),
	CONSTRAINT "competency_versions_weight_kind_check" CHECK (("competency_versions"."kind" = 'core' AND "competency_versions"."weight_basis_points" BETWEEN 1 AND 10000) OR ("competency_versions"."kind" = 'multiplier' AND "competency_versions"."weight_basis_points" IS NULL)),
	CONSTRAINT "competency_versions_definition_json_check" CHECK (rise_pals_private.is_versioned_json_object("definition_i18n")),
	CONSTRAINT "competency_versions_anchors_json_check" CHECK (rise_pals_private.is_versioned_json_object("behavior_anchors")),
	CONSTRAINT "competency_versions_digest_check" CHECK ("competency_versions"."content_digest" ~ '^[0-9a-f]{64}$')
);
--> statement-breakpoint
CREATE TABLE "consent_records" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"purpose_code" text NOT NULL,
	"notice_version" text NOT NULL,
	"decision" "consent_decision" NOT NULL,
	"occurred_at" timestamp with time zone DEFAULT now() NOT NULL,
	"locale" text NOT NULL,
	"source_surface" text NOT NULL,
	"proof_digest" text NOT NULL,
	CONSTRAINT "consent_records_purpose_not_blank" CHECK (btrim("consent_records"."purpose_code") <> ''),
	CONSTRAINT "consent_records_notice_not_blank" CHECK (btrim("consent_records"."notice_version") <> ''),
	CONSTRAINT "consent_records_locale_check" CHECK ("consent_records"."locale" ~ '^[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$'),
	CONSTRAINT "consent_records_surface_not_blank" CHECK (btrim("consent_records"."source_surface") <> ''),
	CONSTRAINT "consent_records_digest_check" CHECK ("consent_records"."proof_digest" ~ '^[0-9a-f]{64}$')
);
--> statement-breakpoint
CREATE TABLE "external_identities" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"provider" text NOT NULL,
	"provider_subject" text NOT NULL,
	"email_normalized" text,
	"email_verified_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_authenticated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "external_identities_provider_not_blank" CHECK (btrim("external_identities"."provider") <> ''),
	CONSTRAINT "external_identities_subject_not_blank" CHECK (btrim("external_identities"."provider_subject") <> '')
);
--> statement-breakpoint
CREATE TABLE "framework_versions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"framework_key" text NOT NULL,
	"version" text NOT NULL,
	"status" "publication_status" DEFAULT 'draft' NOT NULL,
	"scoring_disclaimer_key" text NOT NULL,
	"published_at" timestamp with time zone,
	"content_digest" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "framework_versions_id_key_unique" UNIQUE("id","framework_key"),
	CONSTRAINT "framework_versions_key_not_blank" CHECK (btrim("framework_versions"."framework_key") <> ''),
	CONSTRAINT "framework_versions_version_not_blank" CHECK (btrim("framework_versions"."version") <> ''),
	CONSTRAINT "framework_versions_disclaimer_not_blank" CHECK (btrim("framework_versions"."scoring_disclaimer_key") <> ''),
	CONSTRAINT "framework_versions_digest_check" CHECK ("framework_versions"."content_digest" ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "framework_versions_publication_timestamp_check" CHECK (("framework_versions"."status" = 'draft' AND "framework_versions"."published_at" IS NULL) OR ("framework_versions"."status" <> 'draft' AND "framework_versions"."published_at" IS NOT NULL))
);
--> statement-breakpoint
CREATE TABLE "scoring_model_versions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"framework_version_id" uuid NOT NULL,
	"model_key" text NOT NULL,
	"version" text NOT NULL,
	"method" "scoring_method" NOT NULL,
	"configuration" jsonb NOT NULL,
	"limitations_i18n" jsonb NOT NULL,
	"status" "publication_status" DEFAULT 'draft' NOT NULL,
	"published_at" timestamp with time zone,
	"content_digest" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "scoring_model_versions_id_framework_unique" UNIQUE("id","framework_version_id"),
	CONSTRAINT "scoring_model_versions_key_not_blank" CHECK (btrim("scoring_model_versions"."model_key") <> ''),
	CONSTRAINT "scoring_model_versions_version_not_blank" CHECK (btrim("scoring_model_versions"."version") <> ''),
	CONSTRAINT "scoring_model_versions_configuration_json_check" CHECK (rise_pals_private.is_versioned_json_object("configuration")),
	CONSTRAINT "scoring_model_versions_limitations_json_check" CHECK (rise_pals_private.is_versioned_json_object("limitations_i18n")),
	CONSTRAINT "scoring_model_versions_digest_check" CHECK ("scoring_model_versions"."content_digest" ~ '^[0-9a-f]{64}$'),
	CONSTRAINT "scoring_model_versions_publication_timestamp_check" CHECK (("scoring_model_versions"."status" = 'draft' AND "scoring_model_versions"."published_at" IS NULL) OR ("scoring_model_versions"."status" <> 'draft' AND "scoring_model_versions"."published_at" IS NOT NULL))
);
--> statement-breakpoint
CREATE TABLE "user_accounts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"status" "account_status" DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"last_seen_at" timestamp with time zone,
	"deleted_at" timestamp with time zone,
	CONSTRAINT "user_accounts_deleted_state_check" CHECK (("user_accounts"."status" = 'deleted' AND "user_accounts"."deleted_at" IS NOT NULL) OR ("user_accounts"."status" <> 'deleted' AND "user_accounts"."deleted_at" IS NULL))
);
--> statement-breakpoint
ALTER TABLE "assessment_item_competencies" ADD CONSTRAINT "assessment_item_competencies_item_framework_fk" FOREIGN KEY ("assessment_item_version_id","framework_version_id") REFERENCES "public"."assessment_item_versions"("id","framework_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "assessment_item_competencies" ADD CONSTRAINT "assessment_item_competencies_target_framework_kind_fk" FOREIGN KEY ("competency_version_id","framework_version_id","target_kind") REFERENCES "public"."competency_versions"("id","framework_version_id","kind") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "assessment_item_versions" ADD CONSTRAINT "assessment_item_versions_assessment_framework_fk" FOREIGN KEY ("assessment_version_id","framework_version_id") REFERENCES "public"."assessment_versions"("id","framework_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "assessment_versions" ADD CONSTRAINT "assessment_versions_framework_fk" FOREIGN KEY ("framework_version_id") REFERENCES "public"."framework_versions"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "assessment_versions" ADD CONSTRAINT "assessment_versions_scoring_framework_fk" FOREIGN KEY ("scoring_model_version_id","framework_version_id") REFERENCES "public"."scoring_model_versions"("id","framework_version_id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "competency_versions" ADD CONSTRAINT "competency_versions_framework_version_id_framework_versions_id_fk" FOREIGN KEY ("framework_version_id") REFERENCES "public"."framework_versions"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "consent_records" ADD CONSTRAINT "consent_records_user_id_user_accounts_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_accounts"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "external_identities" ADD CONSTRAINT "external_identities_user_id_user_accounts_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_accounts"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
ALTER TABLE "scoring_model_versions" ADD CONSTRAINT "scoring_model_versions_framework_version_id_framework_versions_id_fk" FOREIGN KEY ("framework_version_id") REFERENCES "public"."framework_versions"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint
CREATE INDEX "assessment_item_competencies_competency_idx" ON "assessment_item_competencies" USING btree ("competency_version_id");--> statement-breakpoint
CREATE UNIQUE INDEX "assessment_item_versions_assessment_key_unique" ON "assessment_item_versions" USING btree ("assessment_version_id","item_key");--> statement-breakpoint
CREATE UNIQUE INDEX "assessment_item_versions_assessment_order_unique" ON "assessment_item_versions" USING btree ("assessment_version_id","display_order");--> statement-breakpoint
CREATE UNIQUE INDEX "assessment_versions_business_version_unique" ON "assessment_versions" USING btree ("assessment_key","version");--> statement-breakpoint
CREATE UNIQUE INDEX "competency_versions_framework_key_unique" ON "competency_versions" USING btree ("framework_version_id","competency_key");--> statement-breakpoint
CREATE UNIQUE INDEX "competency_versions_framework_kind_order_unique" ON "competency_versions" USING btree ("framework_version_id","kind","display_order");--> statement-breakpoint
CREATE INDEX "consent_records_user_occurred_idx" ON "consent_records" USING btree ("user_id","occurred_at");--> statement-breakpoint
CREATE UNIQUE INDEX "external_identities_provider_subject_unique" ON "external_identities" USING btree ("provider","provider_subject");--> statement-breakpoint
CREATE INDEX "external_identities_user_created_idx" ON "external_identities" USING btree ("user_id","created_at");--> statement-breakpoint
CREATE UNIQUE INDEX "framework_versions_business_version_unique" ON "framework_versions" USING btree ("framework_key","version");--> statement-breakpoint
CREATE UNIQUE INDEX "scoring_model_versions_business_version_unique" ON "scoring_model_versions" USING btree ("model_key","version");--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."current_app_user_id"()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
  SELECT nullif(current_setting('app.current_user_id', true), '')::uuid;
$$;--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."current_app_user_id"() FROM PUBLIC;--> statement-breakpoint
GRANT USAGE ON SCHEMA "rise_pals_private" TO "rise_pals_app";--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."current_app_user_id"() TO "rise_pals_app";--> statement-breakpoint

ALTER TABLE "user_accounts" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "user_accounts" FORCE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "external_identities" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "external_identities" FORCE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "consent_records" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "consent_records" FORCE ROW LEVEL SECURITY;--> statement-breakpoint

CREATE POLICY "user_accounts_owner_policy" ON "user_accounts"
  FOR ALL TO "rise_pals_app", "rise_pals_owner"
  USING ("id" = "rise_pals_private"."current_app_user_id"())
  WITH CHECK ("id" = "rise_pals_private"."current_app_user_id"());--> statement-breakpoint
CREATE POLICY "external_identities_owner_policy" ON "external_identities"
  FOR ALL TO "rise_pals_app", "rise_pals_owner"
  USING ("user_id" = "rise_pals_private"."current_app_user_id"())
  WITH CHECK ("user_id" = "rise_pals_private"."current_app_user_id"());--> statement-breakpoint
CREATE POLICY "consent_records_owner_select_policy" ON "consent_records"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING ("user_id" = "rise_pals_private"."current_app_user_id"());--> statement-breakpoint
CREATE POLICY "consent_records_owner_insert_policy" ON "consent_records"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK ("user_id" = "rise_pals_private"."current_app_user_id"());--> statement-breakpoint
CREATE POLICY "consent_records_migration_owner_update_policy" ON "consent_records"
  FOR UPDATE TO "rise_pals_owner"
  USING ("user_id" = "rise_pals_private"."current_app_user_id"())
  WITH CHECK ("user_id" = "rise_pals_private"."current_app_user_id"());--> statement-breakpoint
CREATE POLICY "consent_records_migration_owner_delete_policy" ON "consent_records"
  FOR DELETE TO "rise_pals_owner"
  USING ("user_id" = "rise_pals_private"."current_app_user_id"());--> statement-breakpoint

GRANT USAGE ON SCHEMA "public" TO "rise_pals_app";--> statement-breakpoint
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "user_accounts", "external_identities" TO "rise_pals_app";--> statement-breakpoint
GRANT SELECT, INSERT ON TABLE "consent_records" TO "rise_pals_app";--> statement-breakpoint
GRANT SELECT ON TABLE "framework_versions", "competency_versions", "scoring_model_versions", "assessment_versions", "assessment_item_versions", "assessment_item_competencies" TO "rise_pals_app";--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."reject_consent_mutation"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog
AS $$
BEGIN
  RAISE EXCEPTION 'consent records are append-only' USING ERRCODE = '55000';
END;
$$;--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."reject_consent_mutation"() FROM PUBLIC;--> statement-breakpoint
CREATE TRIGGER "consent_records_append_only"
  BEFORE UPDATE OR DELETE ON "consent_records"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."reject_consent_mutation"();--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."reject_published_version_mutation"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF OLD.status = 'published' THEN
    RAISE EXCEPTION 'published version rows are immutable' USING ERRCODE = '55000';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."reject_published_version_mutation"() FROM PUBLIC;--> statement-breakpoint
CREATE TRIGGER "framework_versions_published_immutable"
  BEFORE UPDATE OR DELETE ON "framework_versions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."reject_published_version_mutation"();--> statement-breakpoint
CREATE TRIGGER "scoring_model_versions_published_immutable"
  BEFORE UPDATE OR DELETE ON "scoring_model_versions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."reject_published_version_mutation"();--> statement-breakpoint
CREATE TRIGGER "assessment_versions_published_immutable"
  BEFORE UPDATE OR DELETE ON "assessment_versions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."reject_published_version_mutation"();--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."assert_canonical_framework"(target_framework_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  target_status publication_status;
  actual_count integer;
  core_count integer;
  multiplier_count integer;
  core_weight_sum integer;
BEGIN
  SELECT status INTO target_status
  FROM framework_versions
  WHERE id = target_framework_id;

  IF target_status IS DISTINCT FROM 'published' THEN
    RETURN;
  END IF;

  SELECT
    count(*),
    count(*) FILTER (WHERE kind = 'core'),
    count(*) FILTER (WHERE kind = 'multiplier'),
    coalesce(sum(weight_basis_points) FILTER (WHERE kind = 'core'), 0)
  INTO actual_count, core_count, multiplier_count, core_weight_sum
  FROM competency_versions
  WHERE framework_version_id = target_framework_id;

  IF actual_count <> 10 OR core_count <> 8 OR multiplier_count <> 2 OR core_weight_sum <> 10000 THEN
    RAISE EXCEPTION 'published Rise Pals framework must contain the canonical 8+2 competencies and 10000 core basis points'
      USING ERRCODE = '23514';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM (
      SELECT competency_key, kind, weight_basis_points, display_order
      FROM competency_versions
      WHERE framework_version_id = target_framework_id
    ) AS actual
    FULL JOIN (
      VALUES
        ('critical-thinking-fact-checking', 'core'::competency_kind, 2000, 1),
        ('systematic-thinking', 'core'::competency_kind, 1500, 2),
        ('growth-mindset', 'core'::competency_kind, 1500, 3),
        ('emotional-intelligence', 'core'::competency_kind, 1000, 4),
        ('resilience-adaptability', 'core'::competency_kind, 1000, 5),
        ('curiosity', 'core'::competency_kind, 1000, 6),
        ('ethical-judgement-governance', 'core'::competency_kind, 1000, 7),
        ('strategic-storytelling-framing', 'core'::competency_kind, 1000, 8),
        ('ownership-thinking', 'multiplier'::competency_kind, NULL::integer, 1),
        ('sense-of-urgency', 'multiplier'::competency_kind, NULL::integer, 2)
    ) AS expected(competency_key, kind, weight_basis_points, display_order)
      USING (competency_key)
    WHERE actual.competency_key IS NULL
       OR expected.competency_key IS NULL
       OR actual.kind IS DISTINCT FROM expected.kind
       OR actual.weight_basis_points IS DISTINCT FROM expected.weight_basis_points
       OR actual.display_order IS DISTINCT FROM expected.display_order
  ) THEN
    RAISE EXCEPTION 'published Rise Pals framework competency metadata must match the canonical registry'
      USING ERRCODE = '23514';
  END IF;
END;
$$;--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."assert_canonical_framework"(uuid) FROM PUBLIC;--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."validate_framework_publication"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
BEGIN
  PERFORM rise_pals_private.assert_canonical_framework(NEW.id);
  RETURN NEW;
END;
$$;--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."validate_framework_publication"() FROM PUBLIC;--> statement-breakpoint
CREATE TRIGGER "framework_versions_validate_publication"
  AFTER INSERT OR UPDATE OF status ON "framework_versions"
  FOR EACH ROW WHEN (NEW.status = 'published')
  EXECUTE FUNCTION "rise_pals_private"."validate_framework_publication"();--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_framework_competency_mutation"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  parent_id uuid := CASE WHEN TG_OP = 'DELETE' THEN OLD.framework_version_id ELSE NEW.framework_version_id END;
  parent_status publication_status;
BEGIN
  SELECT status INTO parent_status FROM framework_versions WHERE id = parent_id;
  IF parent_status = 'published' THEN
    RAISE EXCEPTION 'competencies belonging to a published framework are immutable' USING ERRCODE = '55000';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_framework_competency_mutation"() FROM PUBLIC;--> statement-breakpoint
CREATE TRIGGER "competency_versions_published_parent_immutable"
  BEFORE INSERT OR UPDATE OR DELETE ON "competency_versions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_framework_competency_mutation"();--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."validate_scoring_model_publication"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NEW.status = 'published' AND NOT EXISTS (
    SELECT 1 FROM framework_versions
    WHERE id = NEW.framework_version_id AND status = 'published'
  ) THEN
    RAISE EXCEPTION 'a scoring model can be published only against a published framework'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."validate_scoring_model_publication"() FROM PUBLIC;--> statement-breakpoint
CREATE TRIGGER "scoring_model_versions_validate_publication"
  BEFORE INSERT OR UPDATE OF status ON "scoring_model_versions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."validate_scoring_model_publication"();--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."validate_assessment_publication"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF NEW.status = 'published' AND NOT EXISTS (
    SELECT 1
    FROM framework_versions AS framework
    JOIN scoring_model_versions AS scoring
      ON scoring.id = NEW.scoring_model_version_id
     AND scoring.framework_version_id = framework.id
    WHERE framework.id = NEW.framework_version_id
      AND framework.status = 'published'
      AND scoring.status = 'published'
  ) THEN
    RAISE EXCEPTION 'an assessment can be published only against published framework and scoring versions'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."validate_assessment_publication"() FROM PUBLIC;--> statement-breakpoint
CREATE TRIGGER "assessment_versions_validate_publication"
  BEFORE INSERT OR UPDATE OF status ON "assessment_versions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."validate_assessment_publication"();--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."guard_assessment_child_mutation"()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, public
AS $$
DECLARE
  assessment_id uuid;
  parent_status publication_status;
BEGIN
  IF TG_TABLE_NAME = 'assessment_item_versions' THEN
    assessment_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.assessment_version_id ELSE NEW.assessment_version_id END;
  ELSE
    SELECT item.assessment_version_id INTO assessment_id
    FROM assessment_item_versions AS item
    WHERE item.id = CASE
      WHEN TG_OP = 'DELETE' THEN OLD.assessment_item_version_id
      ELSE NEW.assessment_item_version_id
    END;
  END IF;

  SELECT status INTO parent_status FROM assessment_versions WHERE id = assessment_id;
  IF parent_status = 'published' THEN
    RAISE EXCEPTION 'items and mappings belonging to a published assessment are immutable'
      USING ERRCODE = '55000';
  END IF;
  RETURN CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END;
END;
$$;--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."guard_assessment_child_mutation"() FROM PUBLIC;--> statement-breakpoint
CREATE TRIGGER "assessment_item_versions_published_parent_immutable"
  BEFORE INSERT OR UPDATE OR DELETE ON "assessment_item_versions"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_assessment_child_mutation"();--> statement-breakpoint
CREATE TRIGGER "assessment_item_competencies_published_parent_immutable"
  BEFORE INSERT OR UPDATE OR DELETE ON "assessment_item_competencies"
  FOR EACH ROW EXECUTE FUNCTION "rise_pals_private"."guard_assessment_child_mutation"();
