import type { ComponentPropsWithoutRef } from "react";

type PageContainerProps = Readonly<ComponentPropsWithoutRef<"div">>;

export function PageContainer({ className, ...props }: PageContainerProps) {
  const classes = ["page-container", className].filter(Boolean).join(" ");

  return <div className={classes} {...props} />;
}
