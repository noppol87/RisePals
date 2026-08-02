import Link from "next/link";
import type { ComponentPropsWithoutRef } from "react";

type TextLinkProps = Readonly<ComponentPropsWithoutRef<typeof Link>>;

export function TextLink({ className, ...props }: TextLinkProps) {
  const classes = ["text-link", className].filter(Boolean).join(" ");

  return <Link className={classes} {...props} />;
}
