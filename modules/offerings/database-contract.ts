import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "@/types/database";
import { createClient } from "@/lib/supabase/server";

// Scoped contract for migration 0008. Replace with generated linked types after
// that migration is applied; the generated types/database.ts is not hand-edited.
type ReadonlyTable<Row> = {
  Row: Row;
  Insert: never;
  Update: never;
  Relationships: [];
};

type Offering = {
  id: string; organization_id: string; branch_id: string;
  academic_year_id: string; class_id: string; program_id: string;
  group_id: string | null; code: string; name: string;
  status: "DRAFT" | "ACTIVE" | "RETIRED";
  created_by: string; created_at: string; updated_at: string;
};
type Plan = {
  id: string; offering_id: string; version: number;
  status: "DRAFT" | "ACTIVE" | "RETIRED";
  billing_cycle: "ONE_TIME" | "MONTHLY" | "TERM";
  due_day: number | null; currency_code: string;
  effective_from: string; effective_to: string | null;
  change_reason: string; created_by: string; created_at: string;
};
type Component = {
  id: string; fee_plan_version_id: string; code: string; name: string;
  amount: number; charge_type: string; recurrence: string; sort_order: number;
};
type Group = {
  id: string; organization_id: string; code: string; name: string; is_active: boolean;
};

type ExtendedDatabase = Omit<Database, "public"> & {
  public: Omit<Database["public"], "Tables" | "Functions"> & {
    Tables: Database["public"]["Tables"] & {
      academic_groups: ReadonlyTable<Group>;
      programme_offerings: ReadonlyTable<Offering>;
      fee_plan_versions: ReadonlyTable<Plan>;
      fee_plan_components: ReadonlyTable<Component>;
    };
    Functions: Database["public"]["Functions"] & {
      create_programme_offering: { Args: { p_input: Json }; Returns: Json };
      publish_fee_plan: { Args: { p_input: Json }; Returns: Json };
    };
  };
};

export async function createOfferingClient() {
  return (await createClient()) as unknown as SupabaseClient<ExtendedDatabase>;
}
