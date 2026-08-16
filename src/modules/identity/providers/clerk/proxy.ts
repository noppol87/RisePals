import { NextResponse, type NextMiddleware } from "next/server";
import { parseClerkDevelopmentConfiguration } from "@/modules/identity/providers/clerk/config";
import { clerkMiddleware } from "@/modules/identity/providers/clerk/server-runtime.mjs";

const configuration = parseClerkDevelopmentConfiguration(process.env);

export const clerkDevelopmentProxy: NextMiddleware =
  configuration.state === "enabled"
    ? clerkMiddleware()
    : (request) => {
        void request;
        return NextResponse.next();
      };
