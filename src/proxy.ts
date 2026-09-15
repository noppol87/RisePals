import { refreshSupabaseSession } from "@/modules/identity/providers/supabase/proxy";
export default refreshSupabaseSession;
export const config = {
  matcher: [
    "/:locale/sign-in/:path*",
    "/:locale/sign-up/:path*",
    "/:locale/profile/:path*",
    "/:locale/onboarding/:path*",
    "/:locale/learning/:path*",
    "/:locale/evidence/:path*",
    "/:locale/assessment/attempt/:path*",
    "/:locale/assessment/result/:path*",
    "/:locale/lessons/:lesson/attempt/:path*",
  ],
};
