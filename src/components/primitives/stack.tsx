import type { ComponentPropsWithoutRef } from "react";

type StackProps = Readonly<ComponentPropsWithoutRef<"div">>;

export function Stack({ className, ...props }: StackProps) {
  const classes = ["stack", className].filter(Boolean).join(" ");

  return <div className={classes} {...props} />;
}
