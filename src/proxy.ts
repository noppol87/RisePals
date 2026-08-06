import type { NextRequest } from "next/server";
import { clerkDevelopmentProxy } from "@/modules/identity/providers/clerk/proxy";

export default function proxy(request: NextRequest) {
  return clerkDevelopmentProxy(request);
}

export const config = {
  matcher: [
    "/((?!_next|[^?]*\\.(?:html?|css|js(?!on)|jpe?g|webp|png|gif|svg|ttf|woff2?|ico|csv|docx?|xlsx?|zip|webmanifest)).*)",
    "/(api|trpc)(.*)",
    "/__clerk/(.*)",
  ],
};
