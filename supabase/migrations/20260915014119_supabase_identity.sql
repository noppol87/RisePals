-- Apply after the eight immutable Drizzle baseline migrations.
-- Run with the migration role while it temporarily holds the resolver role;
-- revoke that membership before enabling application traffic.
GRANT CREATE ON SCHEMA rise_pals_private TO rise_pals_identity_resolver;
--> statement-breakpoint
ALTER POLICY external_identities_identity_resolver_select_policy ON public.external_identities USING (((provider = 'clerk' AND provider_subject ~ '^user_[A-Za-z0-9]{8,128}$') OR
    (provider = 'supabase' AND provider_subject ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
--> statement-breakpoint
ALTER POLICY external_identities_identity_resolver_insert_policy ON public.external_identities WITH CHECK (((provider = 'clerk' AND provider_subject ~ '^user_[A-Za-z0-9]{8,128}$') OR
    (provider = 'supabase' AND provider_subject ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')) AND user_id = rise_pals_private.current_app_user_id());
--> statement-breakpoint
ALTER POLICY external_identities_identity_resolver_update_policy ON public.external_identities USING (((provider = 'clerk' AND provider_subject ~ '^user_[A-Za-z0-9]{8,128}$') OR
    (provider = 'supabase' AND provider_subject ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')) AND user_id = rise_pals_private.current_app_user_id()) WITH CHECK (((provider = 'clerk' AND provider_subject ~ '^user_[A-Za-z0-9]{8,128}$') OR
    (provider = 'supabase' AND provider_subject ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')) AND user_id = rise_pals_private.current_app_user_id());
--> statement-breakpoint
CREATE FUNCTION "rise_pals_private"."resolve_or_provision_supabase_identity"(
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
  IF validated_provider IS DISTINCT FROM 'supabase' THEN
    RAISE EXCEPTION 'unsupported identity provider' USING ERRCODE = '22023';
  END IF;

  IF validated_subject IS NULL OR validated_subject !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' THEN
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
  ELSIF resolved_status = 'active' THEN
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
REVOKE ALL ON FUNCTION "rise_pals_private"."resolve_or_provision_supabase_identity"(text, text) FROM PUBLIC;--> statement-breakpoint
GRANT EXECUTE ON FUNCTION "rise_pals_private"."resolve_or_provision_supabase_identity"(text, text) TO "rise_pals_app";--> statement-breakpoint
ALTER FUNCTION "rise_pals_private"."resolve_or_provision_supabase_identity"(text, text) OWNER TO "rise_pals_identity_resolver";--> statement-breakpoint
REVOKE CREATE ON SCHEMA "rise_pals_private" FROM "rise_pals_identity_resolver";

--> statement-breakpoint
-- The application uses server-side pg transactions, never public Data API access.
DO $$
DECLARE api_role text;
BEGIN
  FOREACH api_role IN ARRAY ARRAY['anon', 'authenticated'] LOOP
    IF EXISTS (SELECT FROM pg_roles WHERE rolname = api_role) THEN
      EXECUTE format('REVOKE ALL ON ALL TABLES IN SCHEMA public FROM %I', api_role);
      EXECUTE format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM %I', api_role);
      EXECUTE format('REVOKE ALL ON SCHEMA rise_pals_private FROM %I', api_role);
    END IF;
  END LOOP;
END;
$$;

--> statement-breakpoint
-- Framework definitions are served by the application, not the public Data API.
DO $$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY['framework_versions','competency_versions','scoring_model_versions','assessment_versions','assessment_item_versions','assessment_item_competencies'] LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
    EXECUTE format('CREATE POLICY definition_app_read ON public.%I FOR SELECT TO rise_pals_app USING (true)', table_name);
  END LOOP;
END;
$$;
