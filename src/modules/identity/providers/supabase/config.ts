type Environment = Readonly<Record<string, string | undefined>>;
export type SupabaseConfiguration =
  | Readonly<{ state: "disabled" }>
  | Readonly<{ state: "enabled"; url: string; publishableKey: string }>;

export function parseSupabaseConfiguration(environment: Environment): SupabaseConfiguration {
  if (environment.RISE_PALS_SECRET_FREE_STANDARD_GATE === "true") return { state: "disabled" };
  if (
    (environment.CONTEXT === "deploy-preview" || environment.CONTEXT === "branch-deploy") &&
    environment.RISE_PALS_ALLOW_PREVIEW_AUTH !== "true"
  ) {
    return { state: "disabled" };
  }
  const url = environment.SUPABASE_URL?.trim();
  const publishableKey = environment.SUPABASE_PUBLISHABLE_KEY?.trim();
  if (!url && !publishableKey) return { state: "disabled" };
  const message = "Supabase authentication requires a valid project URL and publishable key.";
  if (!url || !publishableKey || !/^sb_publishable_[A-Za-z0-9_-]+$/.test(publishableKey)) {
    throw new Error(message);
  }
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new Error(message);
  }
  const loopback = ["localhost", "127.0.0.1", "[::1]"].includes(parsed.hostname);
  if (
    (parsed.protocol !== "https:" && !(loopback && parsed.protocol === "http:")) ||
    parsed.username ||
    parsed.password ||
    parsed.pathname !== "/" ||
    parsed.search ||
    parsed.hash
  ) {
    throw new Error(message);
  }
  return { state: "enabled", url: parsed.origin, publishableKey };
}
