import Logo from "@/components/shared/logo";

export default function DashboardLoading() {
  return (
    <main
      className="flex min-h-screen items-center justify-center bg-background px-5 text-foreground"
      aria-busy="true"
      aria-live="polite"
    >
      <div className="flex flex-col items-center text-center">
        <div className="flex size-16 items-center justify-center rounded-2xl border bg-card shadow-sm">
          <Logo variant="mark" size={42} priority />
        </div>
        <div className="mt-5 h-2 w-40 overflow-hidden rounded-full bg-muted">
          <div className="h-full w-1/2 animate-pulse rounded-full bg-primary" />
        </div>
        <p className="mt-3 text-sm font-medium">Loading Sohoj Academy ERP…</p>
        <p className="mt-1 text-xs text-muted-foreground">
          Preparing your permitted workspace.
        </p>
      </div>
    </main>
  );
}
