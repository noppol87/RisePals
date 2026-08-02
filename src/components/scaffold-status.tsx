export function ScaffoldStatus() {
  return (
    <section
      aria-labelledby="scaffold-heading"
      className="w-full rounded-[var(--radius-surface)] border border-black/10 bg-surface p-6 shadow-sm sm:p-10"
    >
      <p className="m-0 text-sm font-semibold tracking-wide text-accent uppercase">
        Application scaffold
      </p>
      <h1 id="scaffold-heading" className="mt-3 text-4xl font-semibold tracking-tight sm:text-5xl">
        Rise Pals
      </h1>
      <p className="mt-5 max-w-2xl text-base text-muted sm:text-lg">
        โครงแอปพลิเคชันพร้อมสำหรับการพัฒนาทีละส่วนตามกระบวนการ review
      </p>
    </section>
  );
}
