import Link from "next/link";
import { LocalizedText } from "@/components/shared/localized-text";
export type WorkflowStep = {
  title: [string, string];
  body: [string, string];
  href: string;
  permission: string;
};
export function WorkflowSteps({
  steps,
  permissions,
}: {
  steps: WorkflowStep[];
  permissions: string[];
}) {
  return (
    <ol className="space-y-3">
      {steps.map((step, index) => (
        <li key={step.title[0]} className="rounded-xl border p-4">
          <details open={index === 0}>
            <summary className="min-h-11 cursor-pointer font-semibold">
              <LocalizedText en={step.title[0]} bn={step.title[1]} />
            </summary>
            <div className="space-y-3 pt-2">
              <p className="leading-7">
                <LocalizedText en={step.body[0]} bn={step.body[1]} />
              </p>
              {permissions.includes(step.permission) ? (
                <Link
                  prefetch={false}
                  href={step.href}
                  className="inline-flex min-h-11 items-center rounded-lg border px-4 hover:bg-muted"
                >
                  <LocalizedText
                    en="Open this work area →"
                    bn="কাজের পেজ খুলুন →"
                  />
                </Link>
              ) : (
                <p className="text-sm text-muted-foreground">
                  <LocalizedText
                    en="This step requires an authorized colleague; your access does not include this action."
                    bn="এই ধাপ অনুমোদিত সহকর্মী করবেন; আপনার role-এ এই action নেই।"
                  />
                </p>
              )}
            </div>
          </details>
        </li>
      ))}
    </ol>
  );
}
