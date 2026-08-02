import { ScaffoldStatus } from "@/components/scaffold-status";

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-3xl items-center px-[var(--space-page)] py-12">
      <ScaffoldStatus />
    </main>
  );
}
