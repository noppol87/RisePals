import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { parseSupabaseConfiguration } from "./config";

export async function createSupabaseServerClient(writable = false) {
  const configuration = parseSupabaseConfiguration(process.env);
  if (configuration.state === "disabled") return null;
  const cookieStore = await cookies();
  return createServerClient(configuration.url, configuration.publishableKey, {
    cookieOptions: {
      httpOnly: true,
      sameSite: "lax",
      path: "/",
      secure: process.env.NODE_ENV === "production",
    },
    global: { fetch: (input, init) => fetch(input, { ...init, cache: "no-store" }) },
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll(values) {
        try {
          values.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
        } catch {
          if (writable) throw new Error("Could not persist the authentication session.");
          /* Server Components cannot write cookies; proxy refreshes them. */
        }
      },
    },
  });
}
