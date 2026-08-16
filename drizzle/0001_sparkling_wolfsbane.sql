CREATE TABLE "user_profiles" (
	"user_id" uuid PRIMARY KEY NOT NULL,
	"preferred_locale" text NOT NULL,
	"timezone" text NOT NULL,
	"role_family" text NOT NULL,
	"function" text NOT NULL,
	"experience_band" text NOT NULL,
	"goals" text[] NOT NULL,
	"onboarding_completed_at" timestamp with time zone NOT NULL,
	"profile_schema_version" text NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "user_profiles_locale_check" CHECK ("user_profiles"."preferred_locale" IN ('th', 'en')),
	CONSTRAINT "user_profiles_timezone_check" CHECK ("user_profiles"."timezone" IN ('Asia/Bangkok', 'Europe/Berlin', 'UTC')),
	CONSTRAINT "user_profiles_role_family_check" CHECK ("user_profiles"."role_family" IN ('individual-contributor', 'people-manager', 'business-owner', 'student-transitioner', 'other')),
	CONSTRAINT "user_profiles_function_check" CHECK ("user_profiles"."function" IN ('operations', 'technology-data', 'sales-marketing', 'people-support', 'finance-risk', 'other')),
	CONSTRAINT "user_profiles_experience_band_check" CHECK ("user_profiles"."experience_band" IN ('early', 'mid', 'senior', 'other')),
	CONSTRAINT "user_profiles_goals_check" CHECK (cardinality("user_profiles"."goals") BETWEEN 1 AND 3 AND "user_profiles"."goals" <@ ARRAY['adapt-to-change', 'improve-judgement', 'communicate-impact', 'build-evidence', 'other']::text[]),
	CONSTRAINT "user_profiles_schema_version_check" CHECK ("user_profiles"."profile_schema_version" = 'profile-v1')
);
--> statement-breakpoint
ALTER TABLE "user_profiles" ADD CONSTRAINT "user_profiles_user_id_user_accounts_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user_accounts"("id") ON DELETE restrict ON UPDATE restrict;--> statement-breakpoint

ALTER TABLE "user_profiles" ENABLE ROW LEVEL SECURITY;--> statement-breakpoint
ALTER TABLE "user_profiles" FORCE ROW LEVEL SECURITY;--> statement-breakpoint

CREATE POLICY "user_profiles_owner_select_policy" ON "user_profiles"
  FOR SELECT TO "rise_pals_app", "rise_pals_owner"
  USING ("user_id" = "rise_pals_private"."current_app_user_id"());--> statement-breakpoint
CREATE POLICY "user_profiles_owner_insert_policy" ON "user_profiles"
  FOR INSERT TO "rise_pals_app", "rise_pals_owner"
  WITH CHECK ("user_id" = "rise_pals_private"."current_app_user_id"());--> statement-breakpoint
CREATE POLICY "user_profiles_owner_update_policy" ON "user_profiles"
  FOR UPDATE TO "rise_pals_app", "rise_pals_owner"
  USING ("user_id" = "rise_pals_private"."current_app_user_id"())
  WITH CHECK ("user_id" = "rise_pals_private"."current_app_user_id"());--> statement-breakpoint

GRANT SELECT, INSERT, UPDATE ON TABLE "user_profiles" TO "rise_pals_app";--> statement-breakpoint

GRANT USAGE, CREATE ON SCHEMA "rise_pals_private" TO "rise_pals_identity_resolver";--> statement-breakpoint
GRANT USAGE ON SCHEMA "public" TO "rise_pals_identity_resolver";--> statement-breakpoint
GRANT USAGE ON TYPE "public"."account_status" TO "rise_pals_identity_resolver";--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."current_app_user_id"() TO "rise_pals_identity_resolver";--> statement-breakpoint
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "public"."user_accounts" TO "rise_pals_identity_resolver";--> statement-breakpoint
GRANT SELECT, INSERT, UPDATE ON TABLE "public"."external_identities" TO "rise_pals_identity_resolver";--> statement-breakpoint

CREATE POLICY "user_accounts_identity_resolver_policy" ON "user_accounts"
  FOR ALL TO "rise_pals_identity_resolver"
  USING ("id" = "rise_pals_private"."current_app_user_id"())
  WITH CHECK ("id" = "rise_pals_private"."current_app_user_id"());--> statement-breakpoint
CREATE POLICY "external_identities_identity_resolver_select_policy" ON "external_identities"
  FOR SELECT TO "rise_pals_identity_resolver"
  USING (
    "provider" = 'clerk'
    AND "provider_subject" ~ '^user_[A-Za-z0-9]{8,128}$'
  );--> statement-breakpoint
CREATE POLICY "external_identities_identity_resolver_insert_policy" ON "external_identities"
  FOR INSERT TO "rise_pals_identity_resolver"
  WITH CHECK (
    "provider" = 'clerk'
    AND "provider_subject" ~ '^user_[A-Za-z0-9]{8,128}$'
    AND "user_id" = "rise_pals_private"."current_app_user_id"()
  );--> statement-breakpoint
CREATE POLICY "external_identities_identity_resolver_update_policy" ON "external_identities"
  FOR UPDATE TO "rise_pals_identity_resolver"
  USING (
    "provider" = 'clerk'
    AND "provider_subject" ~ '^user_[A-Za-z0-9]{8,128}$'
    AND "user_id" = "rise_pals_private"."current_app_user_id"()
  )
  WITH CHECK (
    "provider" = 'clerk'
    AND "provider_subject" ~ '^user_[A-Za-z0-9]{8,128}$'
    AND "user_id" = "rise_pals_private"."current_app_user_id"()
  );--> statement-breakpoint

CREATE FUNCTION "rise_pals_private"."resolve_or_provision_clerk_identity"(
  validated_provider text,
  validated_subject text
)
RETURNS TABLE(user_id uuid, status public.account_status)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  resolved_user_id uuid;
  resolved_status public.account_status;
  candidate_user_id uuid;
  inserted_user_id uuid;
BEGIN
  IF validated_provider <> 'clerk' THEN
    RAISE EXCEPTION 'unsupported identity provider' USING ERRCODE = '22023';
  END IF;

  IF validated_subject !~ '^user_[A-Za-z0-9]{8,128}$' THEN
    RAISE EXCEPTION 'invalid provider subject' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(validated_provider || ':' || validated_subject, 0)
  );

  SELECT identity.user_id
  INTO resolved_user_id
  FROM public.external_identities AS identity
  WHERE identity.provider = validated_provider
    AND identity.provider_subject = validated_subject;

  IF resolved_user_id IS NOT NULL THEN
    PERFORM pg_catalog.set_config('app.current_user_id', resolved_user_id::text, true);
    SELECT account.status INTO resolved_status
    FROM public.user_accounts AS account
    WHERE account.id = resolved_user_id;
  END IF;

  IF resolved_user_id IS NULL THEN
    candidate_user_id := pg_catalog.gen_random_uuid();
    PERFORM pg_catalog.set_config('app.current_user_id', candidate_user_id::text, true);

    INSERT INTO public.user_accounts (id)
    VALUES (candidate_user_id)
    RETURNING user_accounts.status INTO resolved_status;

    INSERT INTO public.external_identities (user_id, provider, provider_subject)
    VALUES (candidate_user_id, validated_provider, validated_subject)
    ON CONFLICT (provider, provider_subject) DO NOTHING
    RETURNING external_identities.user_id INTO inserted_user_id;

    IF inserted_user_id IS NULL THEN
      DELETE FROM public.user_accounts WHERE id = candidate_user_id;

      SELECT identity.user_id
      INTO resolved_user_id
      FROM public.external_identities AS identity
      WHERE identity.provider = validated_provider
        AND identity.provider_subject = validated_subject;

      IF resolved_user_id IS NULL THEN
        RAISE EXCEPTION 'identity resolution conflict could not be resolved'
          USING ERRCODE = '40001';
      END IF;

      PERFORM pg_catalog.set_config('app.current_user_id', resolved_user_id::text, true);
      SELECT account.status INTO resolved_status
      FROM public.user_accounts AS account
      WHERE account.id = resolved_user_id;
    ELSE
      resolved_user_id := candidate_user_id;
    END IF;
  ELSE
    PERFORM pg_catalog.set_config('app.current_user_id', resolved_user_id::text, true);
    UPDATE public.external_identities
    SET last_authenticated_at = pg_catalog.now()
    WHERE provider = validated_provider AND provider_subject = validated_subject;
    UPDATE public.user_accounts
    SET last_seen_at = pg_catalog.now(), updated_at = pg_catalog.now()
    WHERE id = resolved_user_id;
  END IF;

  RETURN QUERY SELECT resolved_user_id, resolved_status;
END;
$$;--> statement-breakpoint
REVOKE ALL ON FUNCTION "rise_pals_private"."resolve_or_provision_clerk_identity"(text, text) FROM PUBLIC;--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."resolve_or_provision_clerk_identity"(text, text) TO "rise_pals_app";--> statement-breakpoint
ALTER FUNCTION "rise_pals_private"."resolve_or_provision_clerk_identity"(text, text) OWNER TO "rise_pals_identity_resolver";--> statement-breakpoint
REVOKE CREATE ON SCHEMA "rise_pals_private" FROM "rise_pals_identity_resolver";
