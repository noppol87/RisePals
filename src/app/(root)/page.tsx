import { redirect } from "next/navigation";
import { defaultLocale, localePath } from "@/lib/i18n/config";

export default function DefaultLocalePage(): never {
  redirect(localePath(defaultLocale));
}
