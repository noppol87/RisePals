import {
  hasSafeRehearsalForwardedHeaders,
  hasLoopbackRequestHost,
  isInfrastructureRehearsalEnabled,
  rehearsalStreamChunks,
} from "@/lib/infra/health";

export const dynamic = "force-dynamic";

const encoder = new TextEncoder();

export function GET(request: Request): Response {
  if (
    !isInfrastructureRehearsalEnabled(process.env) ||
    !hasLoopbackRequestHost(request) ||
    !hasSafeRehearsalForwardedHeaders(request)
  ) {
    return new Response("Not Found", { status: 404 });
  }

  const stream = new ReadableStream<Uint8Array>({
    async start(controller) {
      for (const chunk of rehearsalStreamChunks) {
        controller.enqueue(encoder.encode(chunk));
        await new Promise((resolve) => setTimeout(resolve, 150));
      }
      controller.close();
    },
  });

  return new Response(stream, {
    headers: {
      "Cache-Control": "no-cache, no-store",
      "Content-Type": "text/plain; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
    },
    status: 200,
  });
}
