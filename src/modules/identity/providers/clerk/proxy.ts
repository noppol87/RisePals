import { NextResponse, type NextRequest } from "next/server";
import { parseClerkDevelopmentConfiguration } from "@/modules/identity/providers/clerk/config";
import { clerkMiddleware } from "@/modules/identity/providers/clerk/server-runtime.mjs";

const configuration = parseClerkDevelopmentConfiguration(process.env);

export const clerkDevelopmentProxy =
  configuration.state === "enabled"
    ? clerkMiddleware()
    : (request: NextRequest) => {
        void request;
        return NextResponse.next();
      };
