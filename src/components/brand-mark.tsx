export function BrandMark({ className = "" }: Readonly<{ className?: string }>) {
  return (
    <svg className={`brand-mark ${className}`} viewBox="0 0 40 40" fill="none" aria-hidden="true">
      <rect width="40" height="40" rx="13" fill="currentColor" />
      <path
        d="M11 28V20L18 13V28M22 28V11H30V28"
        stroke="var(--rp-lime)"
        strokeWidth="4"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function ArrowIcon({ diagonal = false }: Readonly<{ diagonal?: boolean }>) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      aria-hidden="true"
      className="arrow-icon"
    >
      <path
        d={diagonal ? "M6 18 18 6M6 6h12v12" : "M4 12h16m-6-6 6 6-6 6"}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

const paths = [
  "m15 15 5 5M17 10a7 7 0 1 1-14 0 7 7 0 0 1 14 0ZM7 10l2 2 4-4",
  "M4 4h6v6H4zM14 14h6v6h-6zM14 4h6v6h-6zM4 14h6v6H4zM10 7h4M7 10v4M17 10v4M10 17h4",
  "M12 21V10M12 14C4 14 3 9 4 4c5 0 8 3 8 7M12 17c7 0 9-4 8-8-5 0-8 3-8 6",
  "M12 20S3 15 3 9a5 5 0 0 1 9-3 5 5 0 0 1 9 3c0 6-9 11-9 11Z",
  "M19 8a8 8 0 1 0 1 8M19 3v5h-5M8 13l3 3 5-6",
  "M9 18h6M10 21h4M8 15c0-2-3-3-3-7a7 7 0 0 1 14 0c0 4-3 5-3 7H8ZM12 3v4",
  "M12 2 3 6v6c0 5 9 10 9 10s9-5 9-10V6l-9-4ZM8 12l3 3 5-6",
  "M4 4h16v12H9l-5 5V4ZM8 8h8M8 12h5",
] as const;

export function SkillIcon({ index }: Readonly<{ index: number }>) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={paths[index % paths.length]} />
    </svg>
  );
}
