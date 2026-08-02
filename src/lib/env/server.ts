import "server-only";
import { parseServerEnvironment } from "@/lib/env/schema";

export const serverEnvironment = parseServerEnvironment(process.env);
