import type { NextMiddleware } from "next/server";

export function auth(): Promise<
  Readonly<{
    isAuthenticated: boolean;
    userId: string | null;
  }>
>;

export function clerkMiddleware(): NextMiddleware;
