// Generated from fresh SQL function signatures. Run pnpm db:rpc-types.
// RPC-only client intentionally has no direct table-write contract.
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];
export type AcademyDatabase = {
  public: {
    Tables: Record<string, never>;
    Views: Record<string, never>;
    Functions: {
      current_academy_id: { Args: Record<string, never>; Returns: string };
      can_operate: { Args: { permission: string }; Returns: boolean };
      require_operation: { Args: { permission: string }; Returns: string };
      record_activity: { Args: { action_value: string; entity_value: string; id_value: string; reason_value: string; before_value: Json; after_value: Json; request_value?: string }; Returns: undefined };
      reject_record_delete: { Args: Record<string, never>; Returns: unknown };
      reject_evidence_change: { Args: Record<string, never>; Returns: unknown };
      initialize_academy: { Args: { admin_email: string; admin_name: string }; Returns: string };
      save_person: { Args: { p_input: Json }; Returns: Json };
      search_people: { Args: { p_query?: string; p_page?: number }; Returns: Json };
      set_person_responsibility: { Args: { p_input: Json }; Returns: Json };
      save_directory_entry: { Args: { p_input: Json }; Returns: Json };
      search_directory: { Args: { p_kind: string; p_query?: string; p_page?: number; p_include_inactive?: boolean }; Returns: Json };
      lookup_operation: { Args: { request_value: string; command_value: string; payload_value: Json }; Returns: Json };
      finish_operation: { Args: { request_value: string; command_value: string; payload_value: Json; result_value: Json; entity_value: string; id_value: string; before_value: Json }; Returns: Json };
      check_change_reason: { Args: { reason_value: string }; Returns: undefined };
      save_programme: { Args: { p_input: Json }; Returns: Json };
      save_programme_run: { Args: { p_input: Json }; Returns: Json };
      save_run_fees: { Args: { p_input: Json }; Returns: Json };
      save_teaching_batch: { Args: { p_input: Json }; Returns: Json };
      guard_batch_seat: { Args: Record<string, never>; Returns: unknown };
      list_current_programmes: { Args: { p_division_id?: string; p_query?: string; p_page?: number }; Returns: Json };
      public_current_programmes: { Args: Record<string, never>; Returns: Json };
      save_academic_year: { Args: { p_input: Json }; Returns: Json };
      set_programme_run_active: { Args: { p_input: Json }; Returns: Json };
      programme_run_setup: { Args: { p_run_id: string; p_batch_page?: number }; Returns: Json };
      academy_account_context: { Args: Record<string, never>; Returns: Json };
      academy_setup_choices: { Args: Record<string, never>; Returns: Json };
      person_profile: { Args: { p_person_id: string }; Returns: Json };
      save_person_profile: { Args: { p_input: Json }; Returns: Json };
      set_person_active: { Args: { p_input: Json }; Returns: Json };
      search_programme_definitions: { Args: { p_query?: string; p_page?: number }; Returns: Json };
    };
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
};
