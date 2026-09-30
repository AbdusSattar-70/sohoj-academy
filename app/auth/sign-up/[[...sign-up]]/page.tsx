import Link from "next/link";
import { StaffAccessRequestForm } from "@/modules/platform/access/request-form";
export default function SignUpPage() {
  return (
    <main className="mx-auto max-w-xl px-5 py-12">
      <Link href="/auth" className="text-sm underline">
        Back to Digital Campus
      </Link>
      <section className="mt-6 rounded-3xl border bg-card p-7">
        <h1 className="text-2xl font-bold">Request academy staff access</h1>
        <p className="my-5 text-sm text-muted-foreground">
          Choose your intended role. The super admin verifies each request and
          assigns permissions before sending a Supabase password setup link.
          Students and guardians can apply without an account.
        </p>
        <StaffAccessRequestForm />
      </section>
    </main>
  );
}
