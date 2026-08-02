import type { SessionStorageLike } from "@/modules/assessment/player/storage";

export function getBrowserSessionStorage(): SessionStorageLike | null {
  try {
    return window.sessionStorage;
  } catch {
    return null;
  }
}
