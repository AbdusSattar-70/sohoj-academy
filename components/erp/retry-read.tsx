"use client";
import { useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { LocalizedText } from "@/components/shared/localized-text";

export function RetryRead() {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  return (
    <Button
      type="button"
      disabled={pending}
      aria-busy={pending}
      onClick={() => startTransition(() => router.refresh())}
    >
      {pending ? (
        <LocalizedText en="Trying again…" bn="আবার চেষ্টা চলছে…" />
      ) : (
        <LocalizedText en="Try again" bn="আবার চেষ্টা করুন" />
      )}
    </Button>
  );
}

export function ReadUnavailable({ en, bn }: { en: string; bn: string }) {
  return (
    <section role="status" className="space-y-3 rounded-xl border p-5">
      <h2 className="font-semibold">
        <LocalizedText en={en} bn={bn} />
      </h2>
      <p>
        <LocalizedText
          en="The connection was interrupted. Try again to load the latest records. This does not change your saved work."
          bn="সংযোগ বিচ্ছিন্ন হওয়ায় তথ্য আনা যায়নি। সর্বশেষ তথ্য পেতে আবার চেষ্টা করুন। আপনার সংরক্ষিত কাজ পরিবর্তন হবে না।"
        />
      </p>
      <RetryRead />
    </section>
  );
}
