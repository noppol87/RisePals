import type { NextRequest, NextResponse } from "next/server";

export function auth(): Promise<
  Readonly<{
    isAuthenticated: boolean;
    userId: string | null;
  }>
>;

export function clerkMiddleware(): (request: NextRequest) => NextResponse | Promise<NextResponse>;
