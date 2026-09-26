export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

type TableDef<Row extends Record<string, unknown>> = {
  Row: Row;
  Insert: Partial<Row>;
  Update: Partial<Row>;
  Relationships: [];
};

export type Database = {
  public: {
    Tables: {
      organizations: TableDef<{
        id: string;
        code: string;
        name: string;
        timezone: string;
        currency_code: string;
        is_active: boolean;
        created_at: string;
        updated_at: string;
      }>;
      branches: TableDef<{
        id: string;
        organization_id: string;
        code: string;
        name: string;
        address: string | null;
        timezone: string;
        is_active: boolean;
        created_at: string;
        updated_at: string;
      }>;
      profiles: TableDef<{
        id: string;
        display_name: string;
        status: Database["public"]["Enums"]["profile_status"];
        created_at: string;
        updated_at: string;
      }>;
      system_roles: TableDef<{
        id: string;
        code: string;
        name: string;
        description: string | null;
        is_system: boolean;
        is_active: boolean;
        created_at: string;
      }>;
      permissions: TableDef<{
        id: string;
        code: string;
        name: string;
        description: string | null;
        created_at: string;
      }>;
      role_permissions: TableDef<{
        role_id: string;
        permission_id: string;
        created_at: string;
      }>;
      user_role_assignments: TableDef<{
        id: string;
        profile_id: string;
        role_id: string;
        branch_id: string | null;
        effective_from: string;
        effective_to: string | null;
        is_active: boolean;
        assigned_by: string | null;
        created_at: string;
      }>;
      staff: TableDef<{
        id: string;
        staff_no: string;
        profile_id: string | null;
        branch_id: string | null;
        full_name: string;
        mobile: string | null;
        alternate_mobile: string | null;
        email: string | null;
        address: string | null;
        emergency_contact_name: string | null;
        emergency_contact_mobile: string | null;
        joined_on: string | null;
        left_on: string | null;
        status: Database["public"]["Enums"]["staff_status"];
        notes: string | null;
        created_by: string | null;
        created_at: string;
        updated_at: string;
      }>;
      staff_roles: TableDef<{
        id: string;
        code: string;
        name: string;
        is_teaching_role: boolean;
        is_active: boolean;
        created_at: string;
      }>;
      staff_role_assignments: TableDef<{
        id: string;
        staff_id: string;
        staff_role_id: string;
        branch_id: string | null;
        effective_from: string;
        effective_to: string | null;
        is_primary: boolean;
        assigned_by: string | null;
        created_at: string;
      }>;
      staff_subject_assignments: TableDef<{
        id: string;
        staff_id: string;
        subject_id: string;
        effective_from: string;
        effective_to: string | null;
        is_primary: boolean;
        assigned_by: string | null;
        created_at: string;
      }>;
      audit_events: TableDef<{
        id: string;
        correlation_id: string;
        occurred_at: string;
        actor_profile_id: string | null;
        actor_staff_id: string | null;
        actor_role_code: string | null;
        branch_id: string | null;
        entity_type: string;
        entity_id: string;
        action: string;
        reason: string | null;
        before_data: Json | null;
        after_data: Json | null;
        metadata: Json;
      }>;
      approval_requests: TableDef<{
        id: string;
        correlation_id: string;
        workflow_type: string;
        entity_type: string;
        entity_id: string;
        requested_action: string;
        payload_snapshot: Json;
        request_note: string | null;
        status: Database["public"]["Enums"]["approval_status"];
        requested_by: string;
        requested_at: string;
        decided_by: string | null;
        decided_at: string | null;
        decision_note: string | null;
        created_at: string;
      }>;
      business_rule_versions: TableDef<{
        id: string;
        domain: string;
        rule_key: string;
        version: number;
        status: Database["public"]["Enums"]["rule_status"];
        effective_from: string;
        effective_to: string | null;
        payload: Json;
        change_reason: string;
        created_by: string | null;
        created_at: string;
      }>;
      academic_years: TableDef<{
        id: string;
        organization_id: string;
        name: string;
        starts_on: string;
        ends_on: string;
        is_active: boolean;
        created_at: string;
      }>;
      classes: TableDef<{
        id: string;
        organization_id: string;
        code: string;
        name: string;
        sort_order: number;
        is_active: boolean;
        created_at: string;
      }>;
      programs: TableDef<{
        id: string;
        organization_id: string;
        code: string;
        name: string;
        description: string | null;
        is_active: boolean;
        created_at: string;
      }>;
      subjects: TableDef<{
        id: string;
        organization_id: string;
        code: string;
        name: string;
        is_active: boolean;
        created_at: string;
      }>;
      areas: TableDef<{
        id: string;
        organization_id: string;
        name: string;
        parent_id: string | null;
        is_active: boolean;
        created_at: string;
      }>;
      schools: TableDef<{
        id: string;
        organization_id: string;
        area_id: string | null;
        name: string;
        is_verified: boolean;
        is_active: boolean;
        created_by: string | null;
        created_at: string;
        updated_at: string;
      }>;
      lead_sources: TableDef<{
        id: string;
        organization_id: string;
        code: string;
        name: string;
        is_active: boolean;
        created_at: string;
      }>;
      guardian_relationships: TableDef<{
        id: string;
        organization_id: string;
        code: string;
        name: string;
        is_active: boolean;
        created_at: string;
      }>;
      payment_methods: TableDef<{
        id: string;
        organization_id: string;
        code: string;
        name: string;
        is_active: boolean;
        created_at: string;
      }>;
      prospects: TableDef<{
        id: string;
        prospect_no: string;
        organization_id: string;
        branch_id: string | null;
        student_name: string;
        student_name_bn: string | null;
        guardian_name: string;
        guardian_relationship_id: string | null;
        guardian_relationship_snapshot: string | null;
        mobile: string;
        alternate_mobile: string | null;
        current_class_id: string | null;
        school_id: string | null;
        school_name_snapshot: string | null;
        area_id: string | null;
        area_snapshot: string | null;
        preferred_schedule: string | null;
        preferred_days: string[];
        trial_interest: boolean;
        source_id: string | null;
        referral_note: string | null;
        notes: string | null;
        consent_to_contact: boolean;
        status: Database["public"]["Enums"]["prospect_status"];
        assigned_to_staff_id: string | null;
        next_follow_up_at: string | null;
        lost_reason: string | null;
        converted_student_id: string | null;
        converted_at: string | null;
        submitted_via: string;
        created_at: string;
        updated_at: string;
      }>;
      prospect_program_interests: TableDef<{
        prospect_id: string;
        program_id: string;
        created_at: string;
      }>;
      prospect_subject_interests: TableDef<{
        prospect_id: string;
        subject_id: string;
        created_at: string;
      }>;
      prospect_followups: TableDef<{
        id: string;
        prospect_id: string;
        followup_type: string;
        occurred_at: string;
        outcome: string | null;
        notes: string;
        next_follow_up_at: string | null;
        recorded_by: string;
        created_at: string;
      }>;
      students: TableDef<{
        id: string;
        student_no: string;
        organization_id: string;
        branch_id: string | null;
        full_name: string;
        name_bn: string | null;
        gender: string | null;
        date_of_birth: string | null;
        school_id: string | null;
        school_name_snapshot: string | null;
        school_roll: string | null;
        status: Database["public"]["Enums"]["student_status"];
        created_from_prospect_id: string | null;
        created_by: string | null;
        created_at: string;
        updated_at: string;
      }>;
      guardians: TableDef<{
        id: string;
        organization_id: string;
        full_name: string;
        mobile: string;
        alternate_mobile: string | null;
        email: string | null;
        address: string | null;
        created_by: string | null;
        created_at: string;
        updated_at: string;
      }>;
      student_guardians: TableDef<{
        id: string;
        student_id: string;
        guardian_id: string;
        relationship_id: string | null;
        relationship_snapshot: string | null;
        is_primary: boolean;
        created_at: string;
      }>;
      batches: TableDef<{
        id: string;
        organization_id: string;
        branch_id: string | null;
        academic_year_id: string;
        class_id: string;
        program_id: string | null;
        code: string;
        name: string;
        capacity: number;
        is_active: boolean;
        created_by: string | null;
        created_at: string;
        updated_at: string;
      }>;
      enrollments: TableDef<{
        id: string;
        student_id: string;
        organization_id: string;
        branch_id: string | null;
        academic_year_id: string;
        class_id: string;
        program_id: string | null;
        batch_id: string | null;
        admission_date: string;
        status: Database["public"]["Enums"]["enrollment_status"];
        ended_on: string | null;
        created_by: string | null;
        created_at: string;
        updated_at: string;
      }>;
    };
    Views: Record<string, never>;
    Functions: {
      bootstrap_admin: {
        Args: { p_email: string; p_full_name?: string | null };
        Returns: Json;
      };
      create_staff_member: {
        Args: { p_input: Json };
        Returns: Json;
      };
      generate_prospect_no: { Args: never; Returns: string };
      generate_staff_no: { Args: never; Returns: string };
      generate_student_no: { Args: never; Returns: string };
      has_permission: {
        Args: { p_permission_code: string };
        Returns: boolean;
      };
      my_erp_context: { Args: never; Returns: Json };
      submit_public_interest: {
        Args: { p_payload: Json };
        Returns: Json;
      };
    };
    Enums: {
      approval_status: "PENDING" | "APPROVED" | "REJECTED" | "CANCELLED";
      enrollment_status: "ACTIVE" | "COMPLETED" | "WITHDRAWN" | "CANCELLED";
      profile_status: "ACTIVE" | "SUSPENDED" | "ARCHIVED";
      prospect_status:
        | "NEW"
        | "CONTACTED"
        | "COUNSELLING"
        | "TRIAL_SCHEDULED"
        | "TRIAL_ATTENDED"
        | "REGISTERED"
        | "CONVERTED"
        | "FUTURE_FOLLOW_UP"
        | "LOST";
      rule_status: "DRAFT" | "ACTIVE" | "RETIRED";
      staff_status: "ACTIVE" | "ON_LEAVE" | "RESIGNED" | "TERMINATED" | "ARCHIVED";
      student_status: "ACTIVE" | "INACTIVE" | "WITHDRAWN" | "GRADUATED" | "ARCHIVED";
    };
    CompositeTypes: Record<string, never>;
  };
};
