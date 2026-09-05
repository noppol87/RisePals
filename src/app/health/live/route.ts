import { liveHealthPayload } from "@/lib/infra/health";

export const dynamic = "force-dynamic";

export function GET(): Response {
  return Response.json(liveHealthPayload, {
    headers: { "Cache-Control": "no-store" },
    status: 200,
  });
}
