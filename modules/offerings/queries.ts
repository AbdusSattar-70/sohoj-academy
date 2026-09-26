import { createClient } from "@/lib/supabase/server";
import { createOfferingClient } from "@/modules/offerings/database-contract";

function dataOrThrow<T>(data: T | null, error: { message: string } | null): T {
  if (error) throw new Error(error.message);
  if (data === null) throw new Error("The requested data is unavailable.");
  return data;
}

export async function getOfferingOverview() {
  const db = await createOfferingClient();
  const base = await createClient();
  const [offeringsQ, groupsQ, yearsQ, branchesQ, classesQ, programsQ, plansQ, componentsQ] = await Promise.all([
    db.from("programme_offerings").select("*").order("created_at", { ascending: false }),
    db.from("academic_groups").select("id,code,name").eq("is_active", true).order("name"),
    base.from("academic_years").select("id,name,is_active").order("starts_on", { ascending: false }),
    base.from("branches").select("id,name").eq("is_active", true).order("name"),
    base.from("classes").select("id,name,sort_order").eq("is_active", true).order("sort_order"),
    base.from("programs").select("id,name").eq("is_active", true).order("name"),
    db.from("fee_plan_versions").select("*").order("version", { ascending: false }),
    db.from("fee_plan_components").select("*").order("sort_order"),
  ]);

  return {
    offerings: dataOrThrow(offeringsQ.data, offeringsQ.error),
    groups: dataOrThrow(groupsQ.data, groupsQ.error),
    years: dataOrThrow(yearsQ.data, yearsQ.error),
    branches: dataOrThrow(branchesQ.data, branchesQ.error),
    classes: dataOrThrow(classesQ.data, classesQ.error),
    programs: dataOrThrow(programsQ.data, programsQ.error),
    plans: dataOrThrow(plansQ.data, plansQ.error),
    components: dataOrThrow(componentsQ.data, componentsQ.error),
  };
}
export type OfferingOverview = Awaited<ReturnType<typeof getOfferingOverview>>;
