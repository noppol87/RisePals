import type { ComponentType, ReactNode } from "react";

type ClerkProviderProps = Readonly<{
  children: ReactNode;
  publishableKey: string;
  localization: unknown;
  signInUrl: string;
  signUpUrl: string;
  afterSignOutUrl: string;
}>;

type SignInProps = Readonly<{
  routing: "path";
  path: string;
  signUpUrl: string;
  fallbackRedirectUrl: string;
}>;

type SignOutButtonProps = Readonly<{
  children: ReactNode;
  redirectUrl: string;
}>;

export const ClerkProvider: ComponentType<ClerkProviderProps>;
export const SignIn: ComponentType<SignInProps>;
export const SignOutButton: ComponentType<SignOutButtonProps>;
export const enUS: unknown;
export const thTH: unknown;
