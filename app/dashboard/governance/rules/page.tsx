import { PageHeader } from "@/components/erp/page-header";
import { PolicyControlCenter } from "@/modules/settings/components/policy-control-center";
import { getSettingsOverview } from "@/modules/settings/queries";
import { requirePermission } from "@/modules/platform/auth/erp-context";
import { can } from "@/types/erp";

export default async function OperatingRulesPage() {
  const context = await requirePermission("system.rules.view");
  const { rules } = await getSettingsOverview();
  const editable = can(context, "system.settings.manage");

  return (
    <div className="space-y-7">
      <PageHeader
        eyebrow="Academy Setup"
        title="Operating Rules"
        description="Review the current capacity, enrollment and compensation rules. Authorized changes apply to future work; finalized records retain their original terms."
      />
      {rules.length === 0 ? (
        <p className="rounded-2xl border border-dashed p-6 text-sm text-muted-foreground">
          No operating rules are configured. Check the academy setup before admitting students.
        </p>
      ) : editable ? (
        <PolicyControlCenter rules={rules} />
      ) : (
        <div className="grid gap-4 lg:grid-cols-2">
          {rules.map((rule) => (
            <section key={rule.id} className="rounded-2xl border bg-card p-5">
              <h2 className="font-semibold">{rule.ruleKey.replaceAll("_", " ")}</h2>
              <p className="mt-1 text-xs text-muted-foreground">Effective {rule.effectiveFrom}</p>
              <dl className="mt-4 space-y-2 text-sm">
                {Object.entries(
                  rule.payload && typeof rule.payload === "object" && !Array.isArray(rule.payload)
                    ? rule.payload as Record<string, unknown>
                    : {}
                ).map(([key, value]) => (
                  <div key={key} className="flex justify-between gap-4 border-b pb-2">
                    <dt>{key.replaceAll("_", " ")}</dt>
                    <dd className="font-medium">{String(value)}</dd>
                  </div>
                ))}
              </dl>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}
