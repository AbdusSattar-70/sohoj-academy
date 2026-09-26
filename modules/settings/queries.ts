import { createClient } from "@/lib/supabase/server";

export type SettingsPolicyRow = {
  id: string;
  domain: string;
  ruleKey: string;
  version: number;
  status: string;
  payload: unknown;
  changeReason: string;
  effectiveFrom: string;
};

export type SettingsRoleRow = {
  id: string;
  code: string;
  name: string;
  isSystem: boolean;
  isActive: boolean;
  permissions: Array<{
    code: string;
    name: string;
    description: string | null;
  }>;
};

export type SettingsPermissionRow = {
  id: string;
  code: string;
  name: string;
  description: string | null;
};

export async function getSettingsOverview() {
  const supabase = await createClient();

  const [rulesQ, rolesQ, permissionsQ, rolePermissionsQ, definitionsQ, valuesQ] =
    await Promise.all([
      supabase
        .from("business_rule_versions")
        .select(
          "id,domain,rule_key,version,status,payload,change_reason,effective_from"
        )
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
        .select("id,code,name,description")
        .order("code"),
      supabase.from("role_permissions").select("role_id,permission_id"),
      supabase
        .from("setting_definitions")
        .select(
          "id,code,group_code,name,description,value_type,is_active,validation_contract"
        )
        .eq("is_active", true)
        .order("group_code")
        .order("sort_order"),
      supabase
        .from("setting_versions")
        .select(
          "setting_definition_id,version,status,value,branch_id,effective_from,change_reason"
        )
        .eq("status", "ACTIVE"),
    ]);

  const permissions: SettingsPermissionRow[] = (permissionsQ.data ?? []).map(
    (permission) => ({
      id: permission.id,
      code: permission.code,
      name: permission.name,
      description: permission.description,
    })
  );

  const permissionsById = new Map(
    permissions.map((permission) => [permission.id, permission])
  );
  const permissionsByRole = new Map<string, SettingsRoleRow["permissions"]>();

  for (const link of rolePermissionsQ.data ?? []) {
    const permission = permissionsById.get(link.permission_id);
    if (!permission) continue;

    const list = permissionsByRole.get(link.role_id) ?? [];
    list.push({
      code: permission.code,
      name: permission.name,
      description: permission.description,
    });
    permissionsByRole.set(link.role_id, list);
  }

  const settingValueByDefinition = new Map(
    (valuesQ.data ?? []).map((value) => [value.setting_definition_id, value])
  );

  return {
    rules: (rulesQ.data ?? []).map(
      (rule): SettingsPolicyRow => ({
        id: rule.id,
        domain: rule.domain,
        ruleKey: rule.rule_key,
        version: rule.version,
        status: rule.status,
        payload: rule.payload,
        changeReason: rule.change_reason,
        effectiveFrom: rule.effective_from,
      })
    ),
    roles: (rolesQ.data ?? []).map(
      (role): SettingsRoleRow => ({
        id: role.id,
        code: role.code,
        name: role.name,
        isSystem: role.is_system,
        isActive: role.is_active,
        permissions: (permissionsByRole.get(role.id) ?? []).sort((a, b) =>
          a.code.localeCompare(b.code)
        ),
      })
    ),
    permissions,
    settings: (definitionsQ.data ?? []).map((definition) => ({
      ...definition,
      activeValue: settingValueByDefinition.get(definition.id) ?? null,
    })),
  };
}
