import { createClient } from "@/lib/supabase/server";

export async function getSettingsOverview() {
  const supabase = await createClient();

  const [rulesQ, rolesQ, permissionsQ, rolePermissionsQ, definitionsQ, valuesQ] =
    await Promise.all([
      supabase
        .from("business_rule_versions")
        .select("id,domain,rule_key,version,status,payload,change_reason,effective_from")
        .eq("status", "ACTIVE")
        .order("domain")
        .order("rule_key"),
      supabase
        .from("system_roles")
        .select("id,code,name,is_system,is_active")
        .eq("is_active", true)
        .order("name"),
      supabase
        .from("permissions")
        .select("id,code,name")
        .order("code"),
      supabase
        .from("role_permissions")
        .select("role_id,permission_id"),
      supabase
        .from("setting_definitions")
        .select("id,code,group_code,name,description,value_type,is_active")
        .eq("is_active", true)
        .order("group_code")
        .order("sort_order"),
      supabase
        .from("setting_versions")
        .select("setting_definition_id,version,status,value,branch_id,effective_from")
        .eq("status", "ACTIVE"),
    ]);

  const permissions = new Map(
    (permissionsQ.data ?? []).map((permission) => [
      permission.id,
      { code: permission.code, name: permission.name },
    ])
  );

  const permissionsByRole = new Map<string, Array<{ code: string; name: string }>>();

  for (const link of rolePermissionsQ.data ?? []) {
    const permission = permissions.get(link.permission_id);
    if (!permission) continue;

    const list = permissionsByRole.get(link.role_id) ?? [];
    list.push(permission);
    permissionsByRole.set(link.role_id, list);
  }

  const settingValueByDefinition = new Map(
    (valuesQ.data ?? []).map((value) => [value.setting_definition_id, value])
  );

  return {
    rules: rulesQ.data ?? [],
    roles: (rolesQ.data ?? []).map((role) => ({
      ...role,
      permissions: (permissionsByRole.get(role.id) ?? []).sort((a, b) =>
        a.code.localeCompare(b.code)
      ),
    })),
    settings: (definitionsQ.data ?? []).map((definition) => ({
      ...definition,
      activeValue: settingValueByDefinition.get(definition.id) ?? null,
    })),
  };
}
