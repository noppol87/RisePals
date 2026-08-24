import "server-only";

export type MutationDisposition = "applied" | "replayed" | "not-applied";

export type ServerMutationExecution<T> = Readonly<{
  result: T;
  disposition: MutationDisposition;
}>;

export function mutationExecution<T>(
  result: T,
  disposition: MutationDisposition,
): ServerMutationExecution<T> {
  return { result, disposition };
}
