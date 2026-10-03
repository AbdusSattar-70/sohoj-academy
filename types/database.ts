/** Fresh database contract. Update alongside schema changes; regenerate with Supabase after deployment. */
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];
export type Database = {
  public: {
    Tables: {
      organizations: {
        Row: {
          id: string;
          code: string;
          name: string;
          timezone: string;
          currency_code: string;
          is_active: boolean;
          created_at: string;
          updated_at: string;
          setup_completed_at: string | null;
          setup_completed_by: string | null;
          setup_identity_confirmed_at: string | null;
        };
        Insert: {
          id?: string;
          code: string;
          name: string;
          timezone?: string;
          currency_code?: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
          setup_completed_at?: string | null;
          setup_completed_by?: string | null;
          setup_identity_confirmed_at?: string | null;
        };
        Update: {
          id?: string;
          code?: string;
          name?: string;
          timezone?: string;
          currency_code?: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
          setup_completed_at?: string | null;
          setup_completed_by?: string | null;
          setup_identity_confirmed_at?: string | null;
        };
        Relationships: [];
      };
      branches: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          address: string | null;
          timezone: string;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          address?: string | null;
          timezone?: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          address?: string | null;
          timezone?: string;
          is_active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      profiles: {
        Row: {
          id: string;
          display_name: string;
          status: Database["public"]["Enums"]["profile_status"];
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id: string;
          display_name: string;
          status?: Database["public"]["Enums"]["profile_status"];
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          display_name?: string;
          status?: Database["public"]["Enums"]["profile_status"];
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      system_roles: {
        Row: {
          id: string;
          code: string;
          name: string;
          description: string | null;
          is_system: boolean;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          code: string;
          name: string;
          description?: string | null;
          is_system?: boolean;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          code?: string;
          name?: string;
          description?: string | null;
          is_system?: boolean;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      permissions: {
        Row: {
          id: string;
          code: string;
          name: string;
          description: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          code: string;
          name: string;
          description?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          code?: string;
          name?: string;
          description?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      role_permissions: {
        Row: {
          role_id: string;
          permission_id: string;
          created_at: string;
        };
        Insert: {
          role_id: string;
          permission_id: string;
          created_at?: string;
        };
        Update: {
          role_id?: string;
          permission_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      user_role_assignments: {
        Row: {
          id: string;
          profile_id: string;
          role_id: string;
          branch_id: string | null;
          effective_from: string;
          effective_to: string | null;
          is_active: boolean;
          assigned_by: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          profile_id: string;
          role_id: string;
          branch_id?: string | null;
          effective_from?: string;
          effective_to?: string | null;
          is_active?: boolean;
          assigned_by?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          profile_id?: string;
          role_id?: string;
          branch_id?: string | null;
          effective_from?: string;
          effective_to?: string | null;
          is_active?: boolean;
          assigned_by?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      staff: {
        Row: {
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
        };
        Insert: {
          id?: string;
          staff_no?: string;
          profile_id?: string | null;
          branch_id?: string | null;
          full_name: string;
          mobile?: string | null;
          alternate_mobile?: string | null;
          email?: string | null;
          address?: string | null;
          emergency_contact_name?: string | null;
          emergency_contact_mobile?: string | null;
          joined_on?: string | null;
          left_on?: string | null;
          status?: Database["public"]["Enums"]["staff_status"];
          notes?: string | null;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          staff_no?: string;
          profile_id?: string | null;
          branch_id?: string | null;
          full_name?: string;
          mobile?: string | null;
          alternate_mobile?: string | null;
          email?: string | null;
          address?: string | null;
          emergency_contact_name?: string | null;
          emergency_contact_mobile?: string | null;
          joined_on?: string | null;
          left_on?: string | null;
          status?: Database["public"]["Enums"]["staff_status"];
          notes?: string | null;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      staff_roles: {
        Row: {
          id: string;
          code: string;
          name: string;
          is_teaching_role: boolean;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          code: string;
          name: string;
          is_teaching_role?: boolean;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          code?: string;
          name?: string;
          is_teaching_role?: boolean;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      staff_role_assignments: {
        Row: {
          id: string;
          staff_id: string;
          staff_role_id: string;
          branch_id: string | null;
          effective_from: string;
          effective_to: string | null;
          is_primary: boolean;
          assigned_by: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          staff_id: string;
          staff_role_id: string;
          branch_id?: string | null;
          effective_from?: string;
          effective_to?: string | null;
          is_primary?: boolean;
          assigned_by?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          staff_id?: string;
          staff_role_id?: string;
          branch_id?: string | null;
          effective_from?: string;
          effective_to?: string | null;
          is_primary?: boolean;
          assigned_by?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      audit_events: {
        Row: {
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
        };
        Insert: {
          id?: string;
          correlation_id?: string;
          occurred_at?: string;
          actor_profile_id?: string | null;
          actor_staff_id?: string | null;
          actor_role_code?: string | null;
          branch_id?: string | null;
          entity_type: string;
          entity_id: string;
          action: string;
          reason?: string | null;
          before_data?: Json | null;
          after_data?: Json | null;
          metadata?: Json;
        };
        Update: {
          id?: string;
          correlation_id?: string;
          occurred_at?: string;
          actor_profile_id?: string | null;
          actor_staff_id?: string | null;
          actor_role_code?: string | null;
          branch_id?: string | null;
          entity_type?: string;
          entity_id?: string;
          action?: string;
          reason?: string | null;
          before_data?: Json | null;
          after_data?: Json | null;
          metadata?: Json;
        };
        Relationships: [];
      };
      approval_requests: {
        Row: {
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
        };
        Insert: {
          id?: string;
          correlation_id?: string;
          workflow_type: string;
          entity_type: string;
          entity_id: string;
          requested_action: string;
          payload_snapshot?: Json;
          request_note?: string | null;
          status?: Database["public"]["Enums"]["approval_status"];
          requested_by: string;
          requested_at?: string;
          decided_by?: string | null;
          decided_at?: string | null;
          decision_note?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          correlation_id?: string;
          workflow_type?: string;
          entity_type?: string;
          entity_id?: string;
          requested_action?: string;
          payload_snapshot?: Json;
          request_note?: string | null;
          status?: Database["public"]["Enums"]["approval_status"];
          requested_by?: string;
          requested_at?: string;
          decided_by?: string | null;
          decided_at?: string | null;
          decision_note?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      business_rule_versions: {
        Row: {
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
        };
        Insert: {
          id?: string;
          domain: string;
          rule_key: string;
          version: number;
          status?: Database["public"]["Enums"]["rule_status"];
          effective_from?: string;
          effective_to?: string | null;
          payload: Json;
          change_reason: string;
          created_by?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          domain?: string;
          rule_key?: string;
          version?: number;
          status?: Database["public"]["Enums"]["rule_status"];
          effective_from?: string;
          effective_to?: string | null;
          payload?: Json;
          change_reason?: string;
          created_by?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      staff_access_requests: {
        Row: {
          id: string;
          full_name: string;
          email: string;
          mobile: string;
          requested_role: string;
          purpose: string;
          status: string;
          assigned_role: string | null;
          profile_id: string | null;
          reviewed_by: string | null;
          reviewed_at: string | null;
          invitation_sent_at: string | null;
          review_note: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          full_name: string;
          email: string;
          mobile: string;
          requested_role: string;
          purpose: string;
          status?: string;
          assigned_role?: string | null;
          profile_id?: string | null;
          reviewed_by?: string | null;
          reviewed_at?: string | null;
          invitation_sent_at?: string | null;
          review_note?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          full_name?: string;
          email?: string;
          mobile?: string;
          requested_role?: string;
          purpose?: string;
          status?: string;
          assigned_role?: string | null;
          profile_id?: string | null;
          reviewed_by?: string | null;
          reviewed_at?: string | null;
          invitation_sent_at?: string | null;
          review_note?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      academic_years: {
        Row: {
          id: string;
          organization_id: string;
          name: string;
          starts_on: string;
          ends_on: string;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          name: string;
          starts_on: string;
          ends_on: string;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          name?: string;
          starts_on?: string;
          ends_on?: string;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      classes: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          sort_order: number;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          sort_order?: number;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          sort_order?: number;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      programs: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          description: string | null;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          description?: string | null;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          description?: string | null;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      subjects: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      areas: {
        Row: {
          id: string;
          organization_id: string;
          name: string;
          parent_id: string | null;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          name: string;
          parent_id?: string | null;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          name?: string;
          parent_id?: string | null;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      schools: {
        Row: {
          id: string;
          organization_id: string;
          area_id: string | null;
          name: string;
          is_verified: boolean;
          is_active: boolean;
          created_by: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          area_id?: string | null;
          name: string;
          is_verified?: boolean;
          is_active?: boolean;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          area_id?: string | null;
          name?: string;
          is_verified?: boolean;
          is_active?: boolean;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      lead_sources: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      guardian_relationships: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      academic_groups: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          is_active: boolean;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          is_active?: boolean;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          is_active?: boolean;
        };
        Relationships: [];
      };
      programme_offerings: {
        Row: {
          id: string;
          organization_id: string;
          branch_id: string;
          academic_year_id: string;
          class_id: string;
          program_id: string;
          group_id: string | null;
          code: string;
          name: string;
          status: Database["public"]["Enums"]["offering_status"];
          created_by: string;
          created_at: string;
          updated_at: string;
          showcase_title: string | null;
          showcase_title_bn: string | null;
          showcase_description: string | null;
          showcase_description_bn: string | null;
          showcase_eyebrow: string | null;
          showcase_eyebrow_bn: string | null;
          showcase_icon: string | null;
          showcase_sort_order: number;
          is_website_visible: boolean;
          is_accepting_applications: boolean;
          applications_open_on: string | null;
          applications_close_on: string | null;
          public_schedule: string | null;
          public_requirements: string | null;
          admission_policy: string | null;
          public_schedule_bn: string | null;
          public_requirements_bn: string | null;
          admission_policy_bn: string | null;
          allowed_discount_percentages: number[];
        };
        Insert: {
          id?: string;
          organization_id: string;
          branch_id: string;
          academic_year_id: string;
          class_id: string;
          program_id: string;
          group_id?: string | null;
          code: string;
          name: string;
          status?: Database["public"]["Enums"]["offering_status"];
          created_by: string;
          created_at?: string;
          updated_at?: string;
          showcase_title?: string | null;
          showcase_title_bn?: string | null;
          showcase_description?: string | null;
          showcase_description_bn?: string | null;
          showcase_eyebrow?: string | null;
          showcase_eyebrow_bn?: string | null;
          showcase_icon?: string | null;
          showcase_sort_order?: number;
          is_website_visible?: boolean;
          is_accepting_applications?: boolean;
          applications_open_on?: string | null;
          applications_close_on?: string | null;
          public_schedule?: string | null;
          public_requirements?: string | null;
          admission_policy?: string | null;
          public_schedule_bn?: string | null;
          public_requirements_bn?: string | null;
          admission_policy_bn?: string | null;
          allowed_discount_percentages?: number[];
        };
        Update: {
          id?: string;
          organization_id?: string;
          branch_id?: string;
          academic_year_id?: string;
          class_id?: string;
          program_id?: string;
          group_id?: string | null;
          code?: string;
          name?: string;
          status?: Database["public"]["Enums"]["offering_status"];
          created_by?: string;
          created_at?: string;
          updated_at?: string;
          showcase_title?: string | null;
          showcase_title_bn?: string | null;
          showcase_description?: string | null;
          showcase_description_bn?: string | null;
          showcase_eyebrow?: string | null;
          showcase_eyebrow_bn?: string | null;
          showcase_icon?: string | null;
          showcase_sort_order?: number;
          is_website_visible?: boolean;
          is_accepting_applications?: boolean;
          applications_open_on?: string | null;
          applications_close_on?: string | null;
          public_schedule?: string | null;
          public_requirements?: string | null;
          admission_policy?: string | null;
          public_schedule_bn?: string | null;
          public_requirements_bn?: string | null;
          admission_policy_bn?: string | null;
          allowed_discount_percentages?: number[];
        };
        Relationships: [];
      };
      fee_plan_versions: {
        Row: {
          id: string;
          offering_id: string;
          version: number;
          status: Database["public"]["Enums"]["rule_status"];
          billing_cycle: string;
          due_day: number | null;
          currency_code: string;
          effective_from: string;
          effective_to: string | null;
          change_reason: string;
          created_by: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          offering_id: string;
          version: number;
          status?: Database["public"]["Enums"]["rule_status"];
          billing_cycle: string;
          due_day?: number | null;
          currency_code?: string;
          effective_from: string;
          effective_to?: string | null;
          change_reason: string;
          created_by: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          offering_id?: string;
          version?: number;
          status?: Database["public"]["Enums"]["rule_status"];
          billing_cycle?: string;
          due_day?: number | null;
          currency_code?: string;
          effective_from?: string;
          effective_to?: string | null;
          change_reason?: string;
          created_by?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      fee_plan_components: {
        Row: {
          id: string;
          fee_plan_version_id: string;
          code: string;
          name: string;
          amount: number;
          charge_type: string;
          recurrence: string;
          sort_order: number;
        };
        Insert: {
          id?: string;
          fee_plan_version_id: string;
          code: string;
          name: string;
          amount: number;
          charge_type: string;
          recurrence: string;
          sort_order?: number;
        };
        Update: {
          id?: string;
          fee_plan_version_id?: string;
          code?: string;
          name?: string;
          amount?: number;
          charge_type?: string;
          recurrence?: string;
          sort_order?: number;
        };
        Relationships: [];
      };
      programme_offering_subjects: {
        Row: {
          offering_id: string;
          subject_id: string;
          sort_order: number;
        };
        Insert: {
          offering_id: string;
          subject_id: string;
          sort_order?: number;
        };
        Update: {
          offering_id?: string;
          subject_id?: string;
          sort_order?: number;
        };
        Relationships: [];
      };
      prospects: {
        Row: {
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
          interested_offering_id: string | null;
          submission_intent: string;
          date_of_birth: string | null;
          gender: string | null;
          school_roll: string | null;
          guardian_address: string | null;
          application_snapshot: Json | null;
          application_verified_at: string | null;
          application_verified_by: string | null;
        };
        Insert: {
          id?: string;
          prospect_no?: string;
          organization_id: string;
          branch_id?: string | null;
          student_name: string;
          student_name_bn?: string | null;
          guardian_name: string;
          guardian_relationship_id?: string | null;
          guardian_relationship_snapshot?: string | null;
          mobile: string;
          alternate_mobile?: string | null;
          current_class_id?: string | null;
          school_id?: string | null;
          school_name_snapshot?: string | null;
          area_id?: string | null;
          area_snapshot?: string | null;
          preferred_schedule?: string | null;
          preferred_days?: string[];
          trial_interest?: boolean;
          source_id?: string | null;
          referral_note?: string | null;
          notes?: string | null;
          consent_to_contact?: boolean;
          status?: Database["public"]["Enums"]["prospect_status"];
          assigned_to_staff_id?: string | null;
          next_follow_up_at?: string | null;
          lost_reason?: string | null;
          converted_student_id?: string | null;
          converted_at?: string | null;
          submitted_via?: string;
          created_at?: string;
          updated_at?: string;
          interested_offering_id?: string | null;
          submission_intent?: string;
          date_of_birth?: string | null;
          gender?: string | null;
          school_roll?: string | null;
          guardian_address?: string | null;
          application_snapshot?: Json | null;
          application_verified_at?: string | null;
          application_verified_by?: string | null;
        };
        Update: {
          id?: string;
          prospect_no?: string;
          organization_id?: string;
          branch_id?: string | null;
          student_name?: string;
          student_name_bn?: string | null;
          guardian_name?: string;
          guardian_relationship_id?: string | null;
          guardian_relationship_snapshot?: string | null;
          mobile?: string;
          alternate_mobile?: string | null;
          current_class_id?: string | null;
          school_id?: string | null;
          school_name_snapshot?: string | null;
          area_id?: string | null;
          area_snapshot?: string | null;
          preferred_schedule?: string | null;
          preferred_days?: string[];
          trial_interest?: boolean;
          source_id?: string | null;
          referral_note?: string | null;
          notes?: string | null;
          consent_to_contact?: boolean;
          status?: Database["public"]["Enums"]["prospect_status"];
          assigned_to_staff_id?: string | null;
          next_follow_up_at?: string | null;
          lost_reason?: string | null;
          converted_student_id?: string | null;
          converted_at?: string | null;
          submitted_via?: string;
          created_at?: string;
          updated_at?: string;
          interested_offering_id?: string | null;
          submission_intent?: string;
          date_of_birth?: string | null;
          gender?: string | null;
          school_roll?: string | null;
          guardian_address?: string | null;
          application_snapshot?: Json | null;
          application_verified_at?: string | null;
          application_verified_by?: string | null;
        };
        Relationships: [];
      };
      prospect_program_interests: {
        Row: {
          prospect_id: string;
          program_id: string;
          created_at: string;
        };
        Insert: {
          prospect_id: string;
          program_id: string;
          created_at?: string;
        };
        Update: {
          prospect_id?: string;
          program_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      prospect_subject_interests: {
        Row: {
          prospect_id: string;
          subject_id: string;
          created_at: string;
        };
        Insert: {
          prospect_id: string;
          subject_id: string;
          created_at?: string;
        };
        Update: {
          prospect_id?: string;
          subject_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      prospect_followups: {
        Row: {
          id: string;
          prospect_id: string;
          followup_type: string;
          occurred_at: string;
          outcome: string | null;
          notes: string;
          next_follow_up_at: string | null;
          recorded_by: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          prospect_id: string;
          followup_type: string;
          occurred_at?: string;
          outcome?: string | null;
          notes: string;
          next_follow_up_at?: string | null;
          recorded_by: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          prospect_id?: string;
          followup_type?: string;
          occurred_at?: string;
          outcome?: string | null;
          notes?: string;
          next_follow_up_at?: string | null;
          recorded_by?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      students: {
        Row: {
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
          merged_into_id: string | null;
          academy_roll: number;
          mobile: string | null;
          email: string | null;
        };
        Insert: {
          id?: string;
          student_no?: string;
          organization_id: string;
          branch_id?: string | null;
          full_name: string;
          name_bn?: string | null;
          gender?: string | null;
          date_of_birth?: string | null;
          school_id?: string | null;
          school_name_snapshot?: string | null;
          school_roll?: string | null;
          status?: Database["public"]["Enums"]["student_status"];
          created_from_prospect_id?: string | null;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
          merged_into_id?: string | null;
          mobile?: string | null;
          email?: string | null;
        };
        Update: {
          id?: string;
          student_no?: string;
          organization_id?: string;
          branch_id?: string | null;
          full_name?: string;
          name_bn?: string | null;
          gender?: string | null;
          date_of_birth?: string | null;
          school_id?: string | null;
          school_name_snapshot?: string | null;
          school_roll?: string | null;
          status?: Database["public"]["Enums"]["student_status"];
          created_from_prospect_id?: string | null;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
          merged_into_id?: string | null;
          mobile?: string | null;
          email?: string | null;
        };
        Relationships: [];
      };
      guardians: {
        Row: {
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
        };
        Insert: {
          id?: string;
          organization_id: string;
          full_name: string;
          mobile: string;
          alternate_mobile?: string | null;
          email?: string | null;
          address?: string | null;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          full_name?: string;
          mobile?: string;
          alternate_mobile?: string | null;
          email?: string | null;
          address?: string | null;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      student_guardians: {
        Row: {
          id: string;
          student_id: string;
          guardian_id: string;
          relationship_id: string | null;
          relationship_snapshot: string | null;
          is_primary: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          student_id: string;
          guardian_id: string;
          relationship_id?: string | null;
          relationship_snapshot?: string | null;
          is_primary?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          student_id?: string;
          guardian_id?: string;
          relationship_id?: string | null;
          relationship_snapshot?: string | null;
          is_primary?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      batches: {
        Row: {
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
          offering_id: string | null;
          capacity_policy_version_id: string | null;
        };
        Insert: {
          id?: string;
          organization_id: string;
          branch_id?: string | null;
          academic_year_id: string;
          class_id: string;
          program_id?: string | null;
          code: string;
          name: string;
          capacity: number;
          is_active?: boolean;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
          offering_id?: string | null;
          capacity_policy_version_id?: string | null;
        };
        Update: {
          id?: string;
          organization_id?: string;
          branch_id?: string | null;
          academic_year_id?: string;
          class_id?: string;
          program_id?: string | null;
          code?: string;
          name?: string;
          capacity?: number;
          is_active?: boolean;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
          offering_id?: string | null;
          capacity_policy_version_id?: string | null;
        };
        Relationships: [];
      };
      enrollments: {
        Row: {
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
        };
        Insert: {
          id?: string;
          student_id: string;
          organization_id: string;
          branch_id?: string | null;
          academic_year_id: string;
          class_id: string;
          program_id?: string | null;
          batch_id?: string | null;
          admission_date?: string;
          status?: Database["public"]["Enums"]["enrollment_status"];
          ended_on?: string | null;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          student_id?: string;
          organization_id?: string;
          branch_id?: string | null;
          academic_year_id?: string;
          class_id?: string;
          program_id?: string | null;
          batch_id?: string | null;
          admission_date?: string;
          status?: Database["public"]["Enums"]["enrollment_status"];
          ended_on?: string | null;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      admission_cases: {
        Row: {
          id: string;
          admission_no: string;
          prospect_id: string | null;
          batch_id: string;
          fee_plan_version_id: string;
          activation_policy_version_id: string | null;
          capacity_policy_version_id: string | null;
          student_id: string | null;
          enrollment_id: string | null;
          status: string;
          identity_snapshot: Json;
          created_by: string;
          created_at: string;
          updated_at: string;
          existing_student: boolean;
          consent_required: boolean;
          origin: string;
          origin_prospect_id: string | null;
          selected_discount_percent: number;
          discount_reason: string | null;
          identity_revision: number;
          additional_charges: Json;
        };
        Insert: {
          id?: string;
          admission_no?: string;
          prospect_id?: string | null;
          batch_id: string;
          fee_plan_version_id: string;
          activation_policy_version_id?: string | null;
          capacity_policy_version_id?: string | null;
          student_id?: string | null;
          enrollment_id?: string | null;
          status?: string;
          identity_snapshot: Json;
          created_by: string;
          created_at?: string;
          updated_at?: string;
          existing_student?: boolean;
          consent_required?: boolean;
          origin?: string;
          origin_prospect_id?: string | null;
          selected_discount_percent?: number;
          discount_reason?: string | null;
          identity_revision?: number;
          additional_charges?: Json;
        };
        Update: {
          id?: string;
          admission_no?: string;
          prospect_id?: string | null;
          batch_id?: string;
          fee_plan_version_id?: string;
          activation_policy_version_id?: string | null;
          capacity_policy_version_id?: string | null;
          student_id?: string | null;
          enrollment_id?: string | null;
          status?: string;
          identity_snapshot?: Json;
          created_by?: string;
          created_at?: string;
          updated_at?: string;
          existing_student?: boolean;
          consent_required?: boolean;
          origin?: string;
          origin_prospect_id?: string | null;
          selected_discount_percent?: number;
          discount_reason?: string | null;
          identity_revision?: number;
          additional_charges?: Json;
        };
        Relationships: [];
      };
      admission_command_keys: {
        Row: {
          request_id: string;
          actor_id: string;
          payload: Json;
          result: Json;
          created_at: string;
        };
        Insert: {
          request_id: string;
          actor_id: string;
          payload: Json;
          result: Json;
          created_at?: string;
        };
        Update: {
          request_id?: string;
          actor_id?: string;
          payload?: Json;
          result?: Json;
          created_at?: string;
        };
        Relationships: [];
      };
      student_merges: {
        Row: {
          id: string;
          source_id: string;
          target_id: string;
          source_snapshot: Json;
          target_snapshot: Json;
          created_at: string;
          authorized_by: string;
          authorization_reason: string;
        };
        Insert: {
          id?: string;
          source_id: string;
          target_id: string;
          source_snapshot: Json;
          target_snapshot: Json;
          created_at?: string;
          authorized_by: string;
          authorization_reason: string;
        };
        Update: {
          id?: string;
          source_id?: string;
          target_id?: string;
          source_snapshot?: Json;
          target_snapshot?: Json;
          created_at?: string;
          authorized_by?: string;
          authorization_reason?: string;
        };
        Relationships: [];
      };
      enrollment_transfers: {
        Row: {
          id: string;
          student_id: string;
          admission_id: string;
          from_enrollment_id: string;
          to_enrollment_id: string;
          from_batch_id: string;
          to_batch_id: string;
          capacity_policy_version_id: string;
          transferred_on: string;
          created_at: string;
          authorized_by: string;
          authorization_reason: string;
        };
        Insert: {
          id?: string;
          student_id: string;
          admission_id: string;
          from_enrollment_id: string;
          to_enrollment_id: string;
          from_batch_id: string;
          to_batch_id: string;
          capacity_policy_version_id: string;
          transferred_on: string;
          created_at?: string;
          authorized_by: string;
          authorization_reason: string;
        };
        Update: {
          id?: string;
          student_id?: string;
          admission_id?: string;
          from_enrollment_id?: string;
          to_enrollment_id?: string;
          from_batch_id?: string;
          to_batch_id?: string;
          capacity_policy_version_id?: string;
          transferred_on?: string;
          created_at?: string;
          authorized_by?: string;
          authorization_reason?: string;
        };
        Relationships: [];
      };
      staff_admission_intake_requests: {
        Row: {
          request_id: string;
          actor_id: string;
          payload: Json;
          prospect_id: string | null;
          admission_id: string;
          created_at: string;
        };
        Insert: {
          request_id: string;
          actor_id: string;
          payload: Json;
          prospect_id?: string | null;
          admission_id: string;
          created_at?: string;
        };
        Update: {
          request_id?: string;
          actor_id?: string;
          payload?: Json;
          prospect_id?: string | null;
          admission_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      admission_physical_consent_receipts: {
        Row: {
          id: string;
          request_id: string;
          request_payload: Json;
          admission_id: string;
          version: number;
          guardian_signed_on: string;
          student_signed: boolean;
          physical_copy_reference: string | null;
          received_by: string;
          received_at: string;
          reason: string;
          identity_revision: number;
        };
        Insert: {
          id?: string;
          request_id: string;
          request_payload: Json;
          admission_id: string;
          version: number;
          guardian_signed_on: string;
          student_signed?: boolean;
          physical_copy_reference?: string | null;
          received_by: string;
          received_at?: string;
          reason: string;
          identity_revision?: number;
        };
        Update: {
          id?: string;
          request_id?: string;
          request_payload?: Json;
          admission_id?: string;
          version?: number;
          guardian_signed_on?: string;
          student_signed?: boolean;
          physical_copy_reference?: string | null;
          received_by?: string;
          received_at?: string;
          reason?: string;
          identity_revision?: number;
        };
        Relationships: [];
      };
      payment_methods: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          is_active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          is_active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          is_active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
      admission_invoices: {
        Row: {
          id: string;
          invoice_no: string;
          admission_id: string;
          student_id: string;
          fee_plan_version_id: string;
          currency_code: string;
          total: number;
          due_on: string;
          issued_on: string;
          posted_by: string;
          posted_at: string;
          invoice_kind: string;
          billing_period: string;
        };
        Insert: {
          id?: string;
          invoice_no?: string;
          admission_id: string;
          student_id: string;
          fee_plan_version_id: string;
          currency_code: string;
          total: number;
          due_on: string;
          issued_on: string;
          posted_by: string;
          posted_at?: string;
          invoice_kind?: string;
          billing_period: string;
        };
        Update: {
          id?: string;
          invoice_no?: string;
          admission_id?: string;
          student_id?: string;
          fee_plan_version_id?: string;
          currency_code?: string;
          total?: number;
          due_on?: string;
          issued_on?: string;
          posted_by?: string;
          posted_at?: string;
          invoice_kind?: string;
          billing_period?: string;
        };
        Relationships: [];
      };
      admission_invoice_lines: {
        Row: {
          id: string;
          invoice_id: string;
          fee_component_id: string | null;
          name: string;
          charge_type: string;
          amount: number;
        };
        Insert: {
          id?: string;
          invoice_id: string;
          fee_component_id?: string | null;
          name: string;
          charge_type: string;
          amount: number;
        };
        Update: {
          id?: string;
          invoice_id?: string;
          fee_component_id?: string | null;
          name?: string;
          charge_type?: string;
          amount?: number;
        };
        Relationships: [];
      };
      admission_payments: {
        Row: {
          id: string;
          student_id: string;
          payment_method_id: string;
          amount: number;
          currency_code: string;
          external_reference: string | null;
          receipt_no: string;
          posted_by: string;
          posted_at: string;
          reason: string;
        };
        Insert: {
          id?: string;
          student_id: string;
          payment_method_id: string;
          amount: number;
          currency_code: string;
          external_reference?: string | null;
          receipt_no?: string;
          posted_by: string;
          posted_at?: string;
          reason: string;
        };
        Update: {
          id?: string;
          student_id?: string;
          payment_method_id?: string;
          amount?: number;
          currency_code?: string;
          external_reference?: string | null;
          receipt_no?: string;
          posted_by?: string;
          posted_at?: string;
          reason?: string;
        };
        Relationships: [];
      };
      admission_payment_allocations: {
        Row: {
          payment_id: string;
          invoice_id: string;
          amount: number;
        };
        Insert: {
          payment_id: string;
          invoice_id: string;
          amount: number;
        };
        Update: {
          payment_id?: string;
          invoice_id?: string;
          amount?: number;
        };
        Relationships: [];
      };
      billing_terms: {
        Row: {
          id: string;
          academic_year_id: string;
          name: string;
          starts_on: string;
          ends_on: string;
          due_on: string;
          created_by: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          academic_year_id: string;
          name: string;
          starts_on: string;
          ends_on: string;
          due_on: string;
          created_by: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          academic_year_id?: string;
          name?: string;
          starts_on?: string;
          ends_on?: string;
          due_on?: string;
          created_by?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      admission_discounts: {
        Row: {
          id: string;
          admission_id: string;
          kind: string;
          value: number;
          starts_on: string;
          ends_on: string;
          created_at: string;
          authorized_by: string | null;
          authorization_reason: string | null;
          correlation_id: string | null;
        };
        Insert: {
          id?: string;
          admission_id: string;
          kind: string;
          value: number;
          starts_on: string;
          ends_on: string;
          created_at?: string;
          authorized_by?: string | null;
          authorization_reason?: string | null;
          correlation_id?: string | null;
        };
        Update: {
          id?: string;
          admission_id?: string;
          kind?: string;
          value?: number;
          starts_on?: string;
          ends_on?: string;
          created_at?: string;
          authorized_by?: string | null;
          authorization_reason?: string | null;
          correlation_id?: string | null;
        };
        Relationships: [];
      };
      invoice_credits: {
        Row: {
          id: string;
          invoice_id: string;
          discount_id: string | null;
          kind: string;
          amount: number;
          created_at: string;
          applied_by: string | null;
          category: string;
          description: string | null;
        };
        Insert: {
          id?: string;
          invoice_id: string;
          discount_id?: string | null;
          kind: string;
          amount: number;
          created_at?: string;
          applied_by?: string | null;
          category?: string;
          description?: string | null;
        };
        Update: {
          id?: string;
          invoice_id?: string;
          discount_id?: string | null;
          kind?: string;
          amount?: number;
          created_at?: string;
          applied_by?: string | null;
          category?: string;
          description?: string | null;
        };
        Relationships: [];
      };
      refund_authorizations: {
        Row: {
          id: string;
          payment_id: string;
          invoice_id: string;
          amount: number;
          created_at: string;
          authorized_by: string | null;
          authorization_reason: string | null;
          correlation_id: string | null;
        };
        Insert: {
          id?: string;
          payment_id: string;
          invoice_id: string;
          amount: number;
          created_at?: string;
          authorized_by?: string | null;
          authorization_reason?: string | null;
          correlation_id?: string | null;
        };
        Update: {
          id?: string;
          payment_id?: string;
          invoice_id?: string;
          amount?: number;
          created_at?: string;
          authorized_by?: string | null;
          authorization_reason?: string | null;
          correlation_id?: string | null;
        };
        Relationships: [];
      };
      refund_payouts: {
        Row: {
          id: string;
          authorization_id: string;
          refund_no: string;
          payment_method_id: string;
          external_reference: string | null;
          posted_by: string;
          posted_at: string;
          reason: string;
        };
        Insert: {
          id?: string;
          authorization_id: string;
          refund_no?: string;
          payment_method_id: string;
          external_reference?: string | null;
          posted_by: string;
          posted_at?: string;
          reason: string;
        };
        Update: {
          id?: string;
          authorization_id?: string;
          refund_no?: string;
          payment_method_id?: string;
          external_reference?: string | null;
          posted_by?: string;
          posted_at?: string;
          reason?: string;
        };
        Relationships: [];
      };
      admission_cancellations: {
        Row: {
          admission_id: string;
          settlement: string;
          cancelled_at: string;
          cancelled_by: string | null;
          cancellation_reason: string | null;
          correlation_id: string | null;
        };
        Insert: {
          admission_id: string;
          settlement: string;
          cancelled_at?: string;
          cancelled_by?: string | null;
          cancellation_reason?: string | null;
          correlation_id?: string | null;
        };
        Update: {
          admission_id?: string;
          settlement?: string;
          cancelled_at?: string;
          cancelled_by?: string | null;
          cancellation_reason?: string | null;
          correlation_id?: string | null;
        };
        Relationships: [];
      };
      billing_runs: {
        Row: {
          id: string;
          period: string;
          term_id: string | null;
          posted_by: string;
          posted_at: string;
          invoice_count: number;
          gross_total: number;
          reason: string;
        };
        Insert: {
          id: string;
          period: string;
          term_id?: string | null;
          posted_by: string;
          posted_at?: string;
          invoice_count: number;
          gross_total: number;
          reason: string;
        };
        Update: {
          id?: string;
          period?: string;
          term_id?: string | null;
          posted_by?: string;
          posted_at?: string;
          invoice_count?: number;
          gross_total?: number;
          reason?: string;
        };
        Relationships: [];
      };
      finance_accounts: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          account_type: string;
          account_subtype: string;
          parent_id: string | null;
          is_control_account: boolean;
          is_active: boolean;
          created_by: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          account_type: string;
          account_subtype: string;
          parent_id?: string | null;
          is_control_account?: boolean;
          is_active?: boolean;
          created_by?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          account_type?: string;
          account_subtype?: string;
          parent_id?: string | null;
          is_control_account?: boolean;
          is_active?: boolean;
          created_by?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_cost_centres: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          branch_id: string | null;
          program_id: string | null;
          batch_id: string | null;
          is_active: boolean;
          created_by: string | null;
          created_at: string;
          offering_id: string | null;
          revision: number;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          branch_id?: string | null;
          program_id?: string | null;
          batch_id?: string | null;
          is_active?: boolean;
          created_by?: string | null;
          created_at?: string;
          offering_id?: string | null;
          revision?: number;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          branch_id?: string | null;
          program_id?: string | null;
          batch_id?: string | null;
          is_active?: boolean;
          created_by?: string | null;
          created_at?: string;
          offering_id?: string | null;
          revision?: number;
        };
        Relationships: [];
      };
      general_ledger_journals: {
        Row: {
          id: string;
          organization_id: string;
          journal_no: string;
          journal_date: string;
          journal_type: string;
          source_type: string;
          source_id: string;
          description: string;
          status: string;
          posted_by: string;
          posted_at: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          journal_no?: string;
          journal_date: string;
          journal_type: string;
          source_type: string;
          source_id: string;
          description: string;
          status?: string;
          posted_by: string;
          posted_at?: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          journal_no?: string;
          journal_date?: string;
          journal_type?: string;
          source_type?: string;
          source_id?: string;
          description?: string;
          status?: string;
          posted_by?: string;
          posted_at?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      general_ledger_lines: {
        Row: {
          id: string;
          journal_id: string;
          line_no: number;
          account_id: string;
          debit: number;
          credit: number;
          memo: string | null;
          cost_centre_id: string | null;
          branch_id: string | null;
          program_id: string | null;
          batch_id: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          journal_id: string;
          line_no: number;
          account_id: string;
          debit?: number;
          credit?: number;
          memo?: string | null;
          cost_centre_id?: string | null;
          branch_id?: string | null;
          program_id?: string | null;
          batch_id?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          journal_id?: string;
          line_no?: number;
          account_id?: string;
          debit?: number;
          credit?: number;
          memo?: string | null;
          cost_centre_id?: string | null;
          branch_id?: string | null;
          program_id?: string | null;
          batch_id?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      vendors: {
        Row: {
          id: string;
          vendor_no: string;
          organization_id: string;
          name: string;
          mobile: string | null;
          email: string | null;
          address: string | null;
          service_category: string | null;
          is_active: boolean;
          created_by: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          vendor_no?: string;
          organization_id: string;
          name: string;
          mobile?: string | null;
          email?: string | null;
          address?: string | null;
          service_category?: string | null;
          is_active?: boolean;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          vendor_no?: string;
          organization_id?: string;
          name?: string;
          mobile?: string | null;
          email?: string | null;
          address?: string | null;
          service_category?: string | null;
          is_active?: boolean;
          created_by?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      finance_payment_account_map: {
        Row: {
          payment_method_id: string;
          account_id: string;
          created_at: string;
        };
        Insert: {
          payment_method_id: string;
          account_id: string;
          created_at?: string;
        };
        Update: {
          payment_method_id?: string;
          account_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_fee_revenue_map: {
        Row: {
          id: string;
          organization_id: string;
          charge_type: string;
          account_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          charge_type: string;
          account_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          charge_type?: string;
          account_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_payables: {
        Row: {
          id: string;
          payable_no: string;
          organization_id: string;
          payable_type: string;
          staff_id: string | null;
          vendor_id: string | null;
          source_type: string;
          source_id: string;
          payable_account_id: string;
          original_amount: number;
          due_on: string | null;
          status: string;
          created_by: string;
          created_at: string;
          referrer_id: string | null;
        };
        Insert: {
          id?: string;
          payable_no?: string;
          organization_id: string;
          payable_type: string;
          staff_id?: string | null;
          vendor_id?: string | null;
          source_type: string;
          source_id: string;
          payable_account_id: string;
          original_amount: number;
          due_on?: string | null;
          status?: string;
          created_by: string;
          created_at?: string;
          referrer_id?: string | null;
        };
        Update: {
          id?: string;
          payable_no?: string;
          organization_id?: string;
          payable_type?: string;
          staff_id?: string | null;
          vendor_id?: string | null;
          source_type?: string;
          source_id?: string;
          payable_account_id?: string;
          original_amount?: number;
          due_on?: string | null;
          status?: string;
          created_by?: string;
          created_at?: string;
          referrer_id?: string | null;
        };
        Relationships: [];
      };
      finance_payable_settlements: {
        Row: {
          id: string;
          payable_id: string;
          amount: number;
          payment_account_id: string | null;
          external_reference: string | null;
          settled_by: string;
          settled_at: string;
          reason: string;
          advance_id: string | null;
          settlement_kind: string;
        };
        Insert: {
          id?: string;
          payable_id: string;
          amount: number;
          payment_account_id?: string | null;
          external_reference?: string | null;
          settled_by: string;
          settled_at?: string;
          reason: string;
          advance_id?: string | null;
          settlement_kind?: string;
        };
        Update: {
          id?: string;
          payable_id?: string;
          amount?: number;
          payment_account_id?: string | null;
          external_reference?: string | null;
          settled_by?: string;
          settled_at?: string;
          reason?: string;
          advance_id?: string | null;
          settlement_kind?: string;
        };
        Relationships: [];
      };
      finance_advances: {
        Row: {
          id: string;
          advance_no: string;
          organization_id: string;
          beneficiary_type: string;
          staff_id: string | null;
          vendor_id: string | null;
          project_reference: string | null;
          purpose: string;
          requested_amount: number;
          approved_amount: number | null;
          expected_settlement_date: string | null;
          requested_by: string;
          status: string;
          created_at: string;
          authorized_by: string | null;
          authorization_reason: string | null;
        };
        Insert: {
          id?: string;
          advance_no?: string;
          organization_id: string;
          beneficiary_type: string;
          staff_id?: string | null;
          vendor_id?: string | null;
          project_reference?: string | null;
          purpose: string;
          requested_amount: number;
          approved_amount?: number | null;
          expected_settlement_date?: string | null;
          requested_by: string;
          status?: string;
          created_at?: string;
          authorized_by?: string | null;
          authorization_reason?: string | null;
        };
        Update: {
          id?: string;
          advance_no?: string;
          organization_id?: string;
          beneficiary_type?: string;
          staff_id?: string | null;
          vendor_id?: string | null;
          project_reference?: string | null;
          purpose?: string;
          requested_amount?: number;
          approved_amount?: number | null;
          expected_settlement_date?: string | null;
          requested_by?: string;
          status?: string;
          created_at?: string;
          authorized_by?: string | null;
          authorization_reason?: string | null;
        };
        Relationships: [];
      };
      finance_advance_movements: {
        Row: {
          id: string;
          advance_id: string;
          movement_type: string;
          amount: number;
          source_type: string | null;
          source_id: string | null;
          payment_account_id: string | null;
          created_by: string;
          created_at: string;
          reason: string;
          payable_id: string | null;
        };
        Insert: {
          id?: string;
          advance_id: string;
          movement_type: string;
          amount: number;
          source_type?: string | null;
          source_id?: string | null;
          payment_account_id?: string | null;
          created_by: string;
          created_at?: string;
          reason: string;
          payable_id?: string | null;
        };
        Update: {
          id?: string;
          advance_id?: string;
          movement_type?: string;
          amount?: number;
          source_type?: string | null;
          source_id?: string | null;
          payment_account_id?: string | null;
          created_by?: string;
          created_at?: string;
          reason?: string;
          payable_id?: string | null;
        };
        Relationships: [];
      };
      finance_expense_categories: {
        Row: {
          id: string;
          organization_id: string;
          code: string;
          name: string;
          expense_account_id: string;
          is_active: boolean;
          created_by: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          code: string;
          name: string;
          expense_account_id: string;
          is_active?: boolean;
          created_by?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          code?: string;
          name?: string;
          expense_account_id?: string;
          is_active?: boolean;
          created_by?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_expenses: {
        Row: {
          id: string;
          expense_no: string;
          organization_id: string;
          expense_date: string;
          category_id: string;
          expense_account_id: string;
          payment_mode: string;
          payment_account_id: string | null;
          payable_id: string | null;
          vendor_id: string | null;
          staff_id: string | null;
          amount: number;
          description: string;
          receipt_reference: string | null;
          status: string;
          submitted_by: string;
          posted_by: string | null;
          posted_at: string | null;
          created_at: string;
          authorized_by: string | null;
          authorization_reason: string | null;
        };
        Insert: {
          id?: string;
          expense_no?: string;
          organization_id: string;
          expense_date: string;
          category_id: string;
          expense_account_id: string;
          payment_mode: string;
          payment_account_id?: string | null;
          payable_id?: string | null;
          vendor_id?: string | null;
          staff_id?: string | null;
          amount: number;
          description: string;
          receipt_reference?: string | null;
          status?: string;
          submitted_by: string;
          posted_by?: string | null;
          posted_at?: string | null;
          created_at?: string;
          authorized_by?: string | null;
          authorization_reason?: string | null;
        };
        Update: {
          id?: string;
          expense_no?: string;
          organization_id?: string;
          expense_date?: string;
          category_id?: string;
          expense_account_id?: string;
          payment_mode?: string;
          payment_account_id?: string | null;
          payable_id?: string | null;
          vendor_id?: string | null;
          staff_id?: string | null;
          amount?: number;
          description?: string;
          receipt_reference?: string | null;
          status?: string;
          submitted_by?: string;
          posted_by?: string | null;
          posted_at?: string | null;
          created_at?: string;
          authorized_by?: string | null;
          authorization_reason?: string | null;
        };
        Relationships: [];
      };
      finance_expense_reconciliations: {
        Row: {
          id: string;
          expense_id: string;
          matched_amount: number;
          statement_reference: string;
          reconciled_by: string;
          reconciled_at: string;
          note: string;
        };
        Insert: {
          id?: string;
          expense_id: string;
          matched_amount: number;
          statement_reference: string;
          reconciled_by: string;
          reconciled_at?: string;
          note: string;
        };
        Update: {
          id?: string;
          expense_id?: string;
          matched_amount?: number;
          statement_reference?: string;
          reconciled_by?: string;
          reconciled_at?: string;
          note?: string;
        };
        Relationships: [];
      };
      finance_account_reconciliations: {
        Row: {
          id: string;
          account_id: string;
          statement_date: string;
          statement_reference: string;
          statement_balance: number;
          ledger_balance: number;
          difference: number;
          status: string;
          reconciled_by: string | null;
          reconciled_at: string | null;
          note: string;
        };
        Insert: {
          id?: string;
          account_id: string;
          statement_date: string;
          statement_reference: string;
          statement_balance: number;
          ledger_balance: number;
          difference: number;
          status: string;
          reconciled_by?: string | null;
          reconciled_at?: string | null;
          note: string;
        };
        Update: {
          id?: string;
          account_id?: string;
          statement_date?: string;
          statement_reference?: string;
          statement_balance?: number;
          ledger_balance?: number;
          difference?: number;
          status?: string;
          reconciled_by?: string | null;
          reconciled_at?: string | null;
          note?: string;
        };
        Relationships: [];
      };
      teacher_referrals: {
        Row: {
          id: string;
          admission_id: string;
          teacher_id: string;
          captured_by: string;
          captured_at: string;
          reason: string;
        };
        Insert: {
          id?: string;
          admission_id: string;
          teacher_id: string;
          captured_by: string;
          captured_at?: string;
          reason: string;
        };
        Update: {
          id?: string;
          admission_id?: string;
          teacher_id?: string;
          captured_by?: string;
          captured_at?: string;
          reason?: string;
        };
        Relationships: [];
      };
      teacher_compensation_runs: {
        Row: {
          id: string;
          run_no: string;
          organization_id: string;
          period_start: string;
          period_end: string;
          policy_version_id: string;
          status: string;
          total_amount: number;
          submitted_by: string;
          approved_by: string | null;
          approved_at: string | null;
          created_at: string;
          authorized_by: string | null;
          authorization_reason: string | null;
        };
        Insert: {
          id?: string;
          run_no?: string;
          organization_id: string;
          period_start: string;
          period_end: string;
          policy_version_id: string;
          status?: string;
          total_amount?: number;
          submitted_by: string;
          approved_by?: string | null;
          approved_at?: string | null;
          created_at?: string;
          authorized_by?: string | null;
          authorization_reason?: string | null;
        };
        Update: {
          id?: string;
          run_no?: string;
          organization_id?: string;
          period_start?: string;
          period_end?: string;
          policy_version_id?: string;
          status?: string;
          total_amount?: number;
          submitted_by?: string;
          approved_by?: string | null;
          approved_at?: string | null;
          created_at?: string;
          authorized_by?: string | null;
          authorization_reason?: string | null;
        };
        Relationships: [];
      };
      teacher_compensation_events: {
        Row: {
          id: string;
          event_key: string;
          teacher_id: string;
          admission_id: string | null;
          event_type: string;
          event_period: string;
          amount: number;
          created_at: string;
        };
        Insert: {
          id?: string;
          event_key: string;
          teacher_id: string;
          admission_id?: string | null;
          event_type: string;
          event_period: string;
          amount: number;
          created_at?: string;
        };
        Update: {
          id?: string;
          event_key?: string;
          teacher_id?: string;
          admission_id?: string | null;
          event_type?: string;
          event_period?: string;
          amount?: number;
          created_at?: string;
        };
        Relationships: [];
      };
      teacher_compensation_adjustments: {
        Row: {
          id: string;
          teacher_id: string;
          amount: number;
          adjustment_type: string;
          effective_period: string;
          reason: string;
          status: string;
          requested_by: string;
          approved_by: string | null;
          approved_at: string | null;
          created_at: string;
          authorized_by: string | null;
          authorization_reason: string | null;
        };
        Insert: {
          id?: string;
          teacher_id: string;
          amount: number;
          adjustment_type: string;
          effective_period: string;
          reason: string;
          status?: string;
          requested_by: string;
          approved_by?: string | null;
          approved_at?: string | null;
          created_at?: string;
          authorized_by?: string | null;
          authorization_reason?: string | null;
        };
        Update: {
          id?: string;
          teacher_id?: string;
          amount?: number;
          adjustment_type?: string;
          effective_period?: string;
          reason?: string;
          status?: string;
          requested_by?: string;
          approved_by?: string | null;
          approved_at?: string | null;
          created_at?: string;
          authorized_by?: string | null;
          authorization_reason?: string | null;
        };
        Relationships: [];
      };
      teacher_compensation_lines: {
        Row: {
          id: string;
          run_id: string;
          teacher_id: string;
          line_type: string;
          source_type: string;
          source_id: string;
          amount: number;
          calculation: Json;
          created_at: string;
          admission_id: string | null;
        };
        Insert: {
          id?: string;
          run_id: string;
          teacher_id: string;
          line_type: string;
          source_type: string;
          source_id: string;
          amount: number;
          calculation?: Json;
          created_at?: string;
          admission_id?: string | null;
        };
        Update: {
          id?: string;
          run_id?: string;
          teacher_id?: string;
          line_type?: string;
          source_type?: string;
          source_id?: string;
          amount?: number;
          calculation?: Json;
          created_at?: string;
          admission_id?: string | null;
        };
        Relationships: [];
      };
      teacher_compensation_settlements: {
        Row: {
          id: string;
          run_id: string;
          teacher_id: string;
          payable_id: string;
          gross_amount: number;
          advance_offset: number;
          cash_paid: number;
          payment_account_id: string | null;
          external_reference: string | null;
          settled_by: string;
          settled_at: string;
          reason: string;
        };
        Insert: {
          id?: string;
          run_id: string;
          teacher_id: string;
          payable_id: string;
          gross_amount: number;
          advance_offset?: number;
          cash_paid?: number;
          payment_account_id?: string | null;
          external_reference?: string | null;
          settled_by: string;
          settled_at?: string;
          reason: string;
        };
        Update: {
          id?: string;
          run_id?: string;
          teacher_id?: string;
          payable_id?: string;
          gross_amount?: number;
          advance_offset?: number;
          cash_paid?: number;
          payment_account_id?: string | null;
          external_reference?: string | null;
          settled_by?: string;
          settled_at?: string;
          reason?: string;
        };
        Relationships: [];
      };
      teacher_compensation_claims: {
        Row: {
          id: string;
          teacher_id: string;
          source_type: string;
          source_id: string;
          line_id: string;
          run_id: string;
          claimed_at: string;
        };
        Insert: {
          id?: string;
          teacher_id: string;
          source_type: string;
          source_id: string;
          line_id: string;
          run_id: string;
          claimed_at?: string;
        };
        Update: {
          id?: string;
          teacher_id?: string;
          source_type?: string;
          source_id?: string;
          line_id?: string;
          run_id?: string;
          claimed_at?: string;
        };
        Relationships: [];
      };
      referral_people: {
        Row: {
          id: string;
          organization_id: string;
          staff_id: string | null;
          full_name: string;
          mobile: string | null;
          relationship_note: string | null;
          contact_note: string | null;
          created_by: string | null;
          created_at: string;
          email: string | null;
          profile_id: string | null;
          is_active: boolean;
        };
        Insert: {
          id?: string;
          organization_id: string;
          staff_id?: string | null;
          full_name: string;
          mobile?: string | null;
          relationship_note?: string | null;
          contact_note?: string | null;
          created_by?: string | null;
          created_at?: string;
          email?: string | null;
          profile_id?: string | null;
          is_active?: boolean;
        };
        Update: {
          id?: string;
          organization_id?: string;
          staff_id?: string | null;
          full_name?: string;
          mobile?: string | null;
          relationship_note?: string | null;
          contact_note?: string | null;
          created_by?: string | null;
          created_at?: string;
          email?: string | null;
          profile_id?: string | null;
          is_active?: boolean;
        };
        Relationships: [];
      };
      admission_referrals: {
        Row: {
          admission_id: string;
          source: string;
          referrer_id: string | null;
          captured_by: string;
          captured_at: string;
          reason: string;
        };
        Insert: {
          admission_id: string;
          source: string;
          referrer_id?: string | null;
          captured_by: string;
          captured_at?: string;
          reason: string;
        };
        Update: {
          admission_id?: string;
          source?: string;
          referrer_id?: string | null;
          captured_by?: string;
          captured_at?: string;
          reason?: string;
        };
        Relationships: [];
      };
      referral_bonus_awards: {
        Row: {
          id: string;
          admission_id: string;
          referrer_id: string;
          period_start: string;
          net_collected: number;
          policy_version_id: string;
          bonus_percent: number;
          amount: number;
          status: string;
          payable_id: string | null;
          requested_by: string;
          reviewed_by: string | null;
          created_at: string;
          reviewed_at: string | null;
        };
        Insert: {
          id?: string;
          admission_id: string;
          referrer_id: string;
          period_start: string;
          net_collected: number;
          policy_version_id: string;
          bonus_percent: number;
          amount: number;
          status?: string;
          payable_id?: string | null;
          requested_by: string;
          reviewed_by?: string | null;
          created_at?: string;
          reviewed_at?: string | null;
        };
        Update: {
          id?: string;
          admission_id?: string;
          referrer_id?: string;
          period_start?: string;
          net_collected?: number;
          policy_version_id?: string;
          bonus_percent?: number;
          amount?: number;
          status?: string;
          payable_id?: string | null;
          requested_by?: string;
          reviewed_by?: string | null;
          created_at?: string;
          reviewed_at?: string | null;
        };
        Relationships: [];
      };
      staff_subject_assignments: {
        Row: {
          id: string;
          staff_id: string;
          subject_id: string;
          effective_from: string;
          effective_to: string | null;
          is_primary: boolean;
          assigned_by: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          staff_id: string;
          subject_id: string;
          effective_from?: string;
          effective_to?: string | null;
          is_primary?: boolean;
          assigned_by?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          staff_id?: string;
          subject_id?: string;
          effective_from?: string;
          effective_to?: string | null;
          is_primary?: boolean;
          assigned_by?: string | null;
          created_at?: string;
        };
        Relationships: [];
      };
      academic_rooms: {
        Row: {
          id: string;
          branch_id: string;
          name: string;
          capacity: number;
          created_by: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          branch_id: string;
          name: string;
          capacity: number;
          created_by: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          branch_id?: string;
          name?: string;
          capacity?: number;
          created_by?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      curriculum_versions: {
        Row: {
          id: string;
          batch_id: string;
          subject_id: string;
          version: number;
          title: string;
          units: Json;
          reason: string;
          published_by: string;
          published_at: string;
        };
        Insert: {
          id?: string;
          batch_id: string;
          subject_id: string;
          version: number;
          title: string;
          units: Json;
          reason: string;
          published_by: string;
          published_at?: string;
        };
        Update: {
          id?: string;
          batch_id?: string;
          subject_id?: string;
          version?: number;
          title?: string;
          units?: Json;
          reason?: string;
          published_by?: string;
          published_at?: string;
        };
        Relationships: [];
      };
      academic_routines: {
        Row: {
          id: string;
          batch_id: string;
          subject_id: string;
          teacher_id: string;
          room_id: string;
          weekday: number;
          start_time: string;
          end_time: string;
          starts_on: string;
          ends_on: string;
          created_by: string;
          created_at: string;
          retired_at: string | null;
        };
        Insert: {
          id?: string;
          batch_id: string;
          subject_id: string;
          teacher_id: string;
          room_id: string;
          weekday: number;
          start_time: string;
          end_time: string;
          starts_on: string;
          ends_on: string;
          created_by: string;
          created_at?: string;
          retired_at?: string | null;
        };
        Update: {
          id?: string;
          batch_id?: string;
          subject_id?: string;
          teacher_id?: string;
          room_id?: string;
          weekday?: number;
          start_time?: string;
          end_time?: string;
          starts_on?: string;
          ends_on?: string;
          created_by?: string;
          created_at?: string;
          retired_at?: string | null;
        };
        Relationships: [];
      };
      class_sessions: {
        Row: {
          id: string;
          routine_id: string | null;
          batch_id: string;
          subject_id: string;
          teacher_id: string;
          room_id: string;
          curriculum_version_id: string | null;
          planned_scope: string;
          session_date: string;
          starts_at: string;
          ends_at: string;
          status: string;
          cancellation_reason: string | null;
          cancelled_by: string | null;
          cancelled_at: string | null;
          created_by: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          routine_id?: string | null;
          batch_id: string;
          subject_id: string;
          teacher_id: string;
          room_id: string;
          curriculum_version_id?: string | null;
          planned_scope: string;
          session_date: string;
          starts_at: string;
          ends_at: string;
          status?: string;
          cancellation_reason?: string | null;
          cancelled_by?: string | null;
          cancelled_at?: string | null;
          created_by: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          routine_id?: string | null;
          batch_id?: string;
          subject_id?: string;
          teacher_id?: string;
          room_id?: string;
          curriculum_version_id?: string | null;
          planned_scope?: string;
          session_date?: string;
          starts_at?: string;
          ends_at?: string;
          status?: string;
          cancellation_reason?: string | null;
          cancelled_by?: string | null;
          cancelled_at?: string | null;
          created_by?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      attendance_submissions: {
        Row: {
          id: string;
          session_id: string;
          revision: number;
          entries: Json;
          reason: string;
          status: string;
          recorded_by: string;
          created_at: string;
          approval_id: string | null;
          reviewer_id: string | null;
          review_note: string | null;
          reviewed_at: string | null;
        };
        Insert: {
          id?: string;
          session_id: string;
          revision: number;
          entries: Json;
          reason: string;
          status?: string;
          recorded_by: string;
          created_at?: string;
          approval_id?: string | null;
          reviewer_id?: string | null;
          review_note?: string | null;
          reviewed_at?: string | null;
        };
        Update: {
          id?: string;
          session_id?: string;
          revision?: number;
          entries?: Json;
          reason?: string;
          status?: string;
          recorded_by?: string;
          created_at?: string;
          approval_id?: string | null;
          reviewer_id?: string | null;
          review_note?: string | null;
          reviewed_at?: string | null;
        };
        Relationships: [];
      };
      class_logs: {
        Row: {
          id: string;
          session_id: string;
          revision: number;
          previous_log_id: string | null;
          status: string;
          unit_progress: Json;
          class_summary: string;
          unfinished_reason: string;
          homework: string;
          next_session_plan: string;
          reason: string;
          authored_by: string;
          created_at: string;
          submitted_at: string | null;
          reviewer_id: string | null;
          review_note: string | null;
          reviewed_at: string | null;
        };
        Insert: {
          id?: string;
          session_id: string;
          revision: number;
          previous_log_id?: string | null;
          status: string;
          unit_progress?: Json;
          class_summary: string;
          unfinished_reason?: string;
          homework?: string;
          next_session_plan?: string;
          reason: string;
          authored_by: string;
          created_at?: string;
          submitted_at?: string | null;
          reviewer_id?: string | null;
          review_note?: string | null;
          reviewed_at?: string | null;
        };
        Update: {
          id?: string;
          session_id?: string;
          revision?: number;
          previous_log_id?: string | null;
          status?: string;
          unit_progress?: Json;
          class_summary?: string;
          unfinished_reason?: string;
          homework?: string;
          next_session_plan?: string;
          reason?: string;
          authored_by?: string;
          created_at?: string;
          submitted_at?: string | null;
          reviewer_id?: string | null;
          review_note?: string | null;
          reviewed_at?: string | null;
        };
        Relationships: [];
      };
      question_bank_items: {
        Row: {
          id: string;
          root_id: string | null;
          revision: number;
          batch_id: string;
          subject_id: string;
          curriculum_version_id: string | null;
          topic: string;
          difficulty: string;
          question_type: string;
          prompt: string;
          choices: Json;
          answer_key: string;
          explanation: string | null;
          status: string;
          author_id: string;
          reviewer_id: string | null;
          review_note: string | null;
          created_at: string;
          submitted_at: string | null;
          reviewed_at: string | null;
        };
        Insert: {
          id?: string;
          root_id?: string | null;
          revision?: number;
          batch_id: string;
          subject_id: string;
          curriculum_version_id?: string | null;
          topic: string;
          difficulty: string;
          question_type: string;
          prompt: string;
          choices?: Json;
          answer_key: string;
          explanation?: string | null;
          status?: string;
          author_id: string;
          reviewer_id?: string | null;
          review_note?: string | null;
          created_at?: string;
          submitted_at?: string | null;
          reviewed_at?: string | null;
        };
        Update: {
          id?: string;
          root_id?: string | null;
          revision?: number;
          batch_id?: string;
          subject_id?: string;
          curriculum_version_id?: string | null;
          topic?: string;
          difficulty?: string;
          question_type?: string;
          prompt?: string;
          choices?: Json;
          answer_key?: string;
          explanation?: string | null;
          status?: string;
          author_id?: string;
          reviewer_id?: string | null;
          review_note?: string | null;
          created_at?: string;
          submitted_at?: string | null;
          reviewed_at?: string | null;
        };
        Relationships: [];
      };
      homework_checks: {
        Row: {
          id: string;
          class_log_id: string;
          enrollment_id: string;
          revision: number;
          status: string;
          submitted_on: string | null;
          feedback: string;
          recorded_by: string;
          recorded_at: string;
        };
        Insert: {
          id?: string;
          class_log_id: string;
          enrollment_id: string;
          revision: number;
          status: string;
          submitted_on?: string | null;
          feedback?: string;
          recorded_by: string;
          recorded_at?: string;
        };
        Update: {
          id?: string;
          class_log_id?: string;
          enrollment_id?: string;
          revision?: number;
          status?: string;
          submitted_on?: string | null;
          feedback?: string;
          recorded_by?: string;
          recorded_at?: string;
        };
        Relationships: [];
      };
      academic_assessments: {
        Row: {
          id: string;
          batch_id: string;
          subject_id: string;
          title: string;
          assessment_date: string;
          max_marks: number;
          status: string;
          author_id: string;
          created_at: string;
          published_at: string | null;
        };
        Insert: {
          id?: string;
          batch_id: string;
          subject_id: string;
          title: string;
          assessment_date: string;
          max_marks: number;
          status?: string;
          author_id: string;
          created_at?: string;
          published_at?: string | null;
        };
        Update: {
          id?: string;
          batch_id?: string;
          subject_id?: string;
          title?: string;
          assessment_date?: string;
          max_marks?: number;
          status?: string;
          author_id?: string;
          created_at?: string;
          published_at?: string | null;
        };
        Relationships: [];
      };
      assessment_result_submissions: {
        Row: {
          id: string;
          assessment_id: string;
          revision: number;
          entries: Json;
          status: string;
          author_id: string;
          reviewer_id: string | null;
          review_note: string | null;
          created_at: string;
          submitted_at: string | null;
          reviewed_at: string | null;
        };
        Insert: {
          id?: string;
          assessment_id: string;
          revision: number;
          entries: Json;
          status?: string;
          author_id: string;
          reviewer_id?: string | null;
          review_note?: string | null;
          created_at?: string;
          submitted_at?: string | null;
          reviewed_at?: string | null;
        };
        Update: {
          id?: string;
          assessment_id?: string;
          revision?: number;
          entries?: Json;
          status?: string;
          author_id?: string;
          reviewer_id?: string | null;
          review_note?: string | null;
          created_at?: string;
          submitted_at?: string | null;
          reviewed_at?: string | null;
        };
        Relationships: [];
      };
      referral_reward_contracts: {
        Row: {
          admission_id: string;
          referrer_id: string;
          billing_period: string;
          bonus_percent: number;
          policy_version_id: string;
          created_at: string;
        };
        Insert: {
          admission_id: string;
          referrer_id: string;
          billing_period: string;
          bonus_percent: number;
          policy_version_id: string;
          created_at?: string;
        };
        Update: {
          admission_id?: string;
          referrer_id?: string;
          billing_period?: string;
          bonus_percent?: number;
          policy_version_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      referral_reward_entries: {
        Row: {
          id: string;
          admission_id: string;
          referrer_id: string;
          amount: number;
          net_collected: number;
          bonus_percent: number;
          journal_id: string | null;
          payable_id: string | null;
          source_reference: string | null;
          created_at: string;
          actor_id: string | null;
        };
        Insert: {
          id?: string;
          admission_id: string;
          referrer_id: string;
          amount: number;
          net_collected: number;
          bonus_percent: number;
          journal_id?: string | null;
          payable_id?: string | null;
          source_reference?: string | null;
          created_at?: string;
          actor_id?: string | null;
        };
        Update: {
          id?: string;
          admission_id?: string;
          referrer_id?: string;
          amount?: number;
          net_collected?: number;
          bonus_percent?: number;
          journal_id?: string | null;
          payable_id?: string | null;
          source_reference?: string | null;
          created_at?: string;
          actor_id?: string | null;
        };
        Relationships: [];
      };
      staff_attendance_records: {
        Row: {
          id: string;
          staff_id: string;
          work_date: string;
          status: string;
          started_at: string | null;
          ended_at: string | null;
          break_minutes: number;
          recorded_by: string;
          reason: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          staff_id: string;
          work_date: string;
          status: string;
          started_at?: string | null;
          ended_at?: string | null;
          break_minutes?: number;
          recorded_by: string;
          reason: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          staff_id?: string;
          work_date?: string;
          status?: string;
          started_at?: string | null;
          ended_at?: string | null;
          break_minutes?: number;
          recorded_by?: string;
          reason?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      staff_compensation_terms: {
        Row: {
          staff_id: string;
          model: string;
          monthly_base: number;
          hourly_rate: number;
          pay_day: number;
          effective_from: string;
          recorded_by: string;
          reason: string;
          updated_at: string;
        };
        Insert: {
          staff_id: string;
          model: string;
          monthly_base?: number;
          hourly_rate?: number;
          pay_day: number;
          effective_from: string;
          recorded_by: string;
          reason: string;
          updated_at?: string;
        };
        Update: {
          staff_id?: string;
          model?: string;
          monthly_base?: number;
          hourly_rate?: number;
          pay_day?: number;
          effective_from?: string;
          recorded_by?: string;
          reason?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      staff_work_tasks: {
        Row: {
          id: string;
          staff_id: string;
          title: string;
          instructions: string;
          due_on: string;
          status: string;
          progress: number;
          blocker: string;
          review_note: string | null;
          created_by: string;
          updated_by: string;
          created_at: string;
          updated_at: string;
          completed_at: string | null;
        };
        Insert: {
          id?: string;
          staff_id: string;
          title: string;
          instructions?: string;
          due_on: string;
          status?: string;
          progress?: number;
          blocker?: string;
          review_note?: string | null;
          created_by: string;
          updated_by: string;
          created_at?: string;
          updated_at?: string;
          completed_at?: string | null;
        };
        Update: {
          id?: string;
          staff_id?: string;
          title?: string;
          instructions?: string;
          due_on?: string;
          status?: string;
          progress?: number;
          blocker?: string;
          review_note?: string | null;
          created_by?: string;
          updated_by?: string;
          created_at?: string;
          updated_at?: string;
          completed_at?: string | null;
        };
        Relationships: [];
      };
      staff_payroll_records: {
        Row: {
          id: string;
          payroll_no: string;
          staff_id: string;
          month: string;
          payable_id: string;
          snapshot: Json;
          gross: number;
          corrections: number;
          net: number;
          due_on: string;
          posted_by: string;
          posted_at: string;
          reason: string;
        };
        Insert: {
          id?: string;
          payroll_no?: string;
          staff_id: string;
          month: string;
          payable_id: string;
          snapshot: Json;
          gross: number;
          corrections: number;
          net: number;
          due_on: string;
          posted_by: string;
          posted_at?: string;
          reason: string;
        };
        Update: {
          id?: string;
          payroll_no?: string;
          staff_id?: string;
          month?: string;
          payable_id?: string;
          snapshot?: Json;
          gross?: number;
          corrections?: number;
          net?: number;
          due_on?: string;
          posted_by?: string;
          posted_at?: string;
          reason?: string;
        };
        Relationships: [];
      };
      finance_daily_closes: {
        Row: {
          id: string;
          close_no: string;
          account_id: string;
          close_date: string;
          opening: number;
          receipts: number;
          payments: number;
          expected: number;
          actual: number;
          variance: number;
          ledger_token: string;
          denominations: Json | null;
          statement_reference: string;
          explanation: string;
          handed_to: string | null;
          recorded_by: string;
          recorded_at: string;
        };
        Insert: {
          id?: string;
          close_no?: string;
          account_id: string;
          close_date: string;
          opening: number;
          receipts: number;
          payments: number;
          expected: number;
          actual: number;
          variance: number;
          ledger_token: string;
          denominations?: Json | null;
          statement_reference: string;
          explanation: string;
          handed_to?: string | null;
          recorded_by: string;
          recorded_at?: string;
        };
        Update: {
          id?: string;
          close_no?: string;
          account_id?: string;
          close_date?: string;
          opening?: number;
          receipts?: number;
          payments?: number;
          expected?: number;
          actual?: number;
          variance?: number;
          ledger_token?: string;
          denominations?: Json | null;
          statement_reference?: string;
          explanation?: string;
          handed_to?: string | null;
          recorded_by?: string;
          recorded_at?: string;
        };
        Relationships: [];
      };
      finance_close_resolutions: {
        Row: {
          id: string;
          event_order: number;
          ledger_token: string;
          close_id: string;
          action: string;
          reason: string;
          journal_id: string | null;
          actor_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          ledger_token: string;
          close_id: string;
          action: string;
          reason: string;
          journal_id?: string | null;
          actor_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          ledger_token?: string;
          close_id?: string;
          action?: string;
          reason?: string;
          journal_id?: string | null;
          actor_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_period_events: {
        Row: {
          id: string;
          event_order: number;
          month: string;
          action: string;
          snapshot: Json;
          reason: string;
          actor_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          month: string;
          action: string;
          snapshot: Json;
          reason: string;
          actor_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          month?: string;
          action?: string;
          snapshot?: Json;
          reason?: string;
          actor_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_purchases: {
        Row: {
          id: string;
          purchase_no: string;
          organization_id: string;
          vendor_id: string;
          category_id: string;
          description: string;
          items: Json;
          total: number;
          expected_on: string | null;
          status: string;
          revision: number;
          invoice_reference: string | null;
          received_on: string | null;
          expense_id: string | null;
          created_by: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          purchase_no?: string;
          organization_id: string;
          vendor_id: string;
          category_id: string;
          description: string;
          items: Json;
          total: number;
          expected_on?: string | null;
          status?: string;
          revision?: number;
          invoice_reference?: string | null;
          received_on?: string | null;
          expense_id?: string | null;
          created_by: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          purchase_no?: string;
          organization_id?: string;
          vendor_id?: string;
          category_id?: string;
          description?: string;
          items?: Json;
          total?: number;
          expected_on?: string | null;
          status?: string;
          revision?: number;
          invoice_reference?: string | null;
          received_on?: string | null;
          expense_id?: string | null;
          created_by?: string;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      finance_documents: {
        Row: {
          id: string;
          entity_type: string;
          entity_id: string;
          actor_id: string;
          object_path: string;
          original_name: string;
          mime_type: string;
          byte_size: number;
          sha256: string;
          note: string;
          request_payload: Json;
          status: string;
          created_at: string;
          ready_at: string | null;
        };
        Insert: {
          id: string;
          entity_type: string;
          entity_id: string;
          actor_id: string;
          object_path: string;
          original_name: string;
          mime_type: string;
          byte_size: number;
          sha256: string;
          note: string;
          request_payload: Json;
          status?: string;
          created_at?: string;
          ready_at?: string | null;
        };
        Update: {
          id?: string;
          entity_type?: string;
          entity_id?: string;
          actor_id?: string;
          object_path?: string;
          original_name?: string;
          mime_type?: string;
          byte_size?: number;
          sha256?: string;
          note?: string;
          request_payload?: Json;
          status?: string;
          created_at?: string;
          ready_at?: string | null;
        };
        Relationships: [];
      };
      purchase_adjustments: {
        Row: {
          id: string;
          purchase_id: string;
          kind: string;
          reference: string;
          adjustment_date: string;
          amount: number;
          payable_credit: number;
          cash_refund: number;
          refund_due: number;
          payment_account_id: string | null;
          journal_id: string;
          reason: string;
          actor_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          purchase_id: string;
          kind: string;
          reference: string;
          adjustment_date: string;
          amount: number;
          payable_credit: number;
          cash_refund: number;
          refund_due: number;
          payment_account_id?: string | null;
          journal_id: string;
          reason: string;
          actor_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          purchase_id?: string;
          kind?: string;
          reference?: string;
          adjustment_date?: string;
          amount?: number;
          payable_credit?: number;
          cash_refund?: number;
          refund_due?: number;
          payment_account_id?: string | null;
          journal_id?: string;
          reason?: string;
          actor_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      purchase_refund_receipts: {
        Row: {
          id: string;
          adjustment_id: string;
          amount: number;
          receipt_date: string;
          payment_account_id: string;
          reference: string;
          reason: string;
          actor_id: string;
          journal_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          adjustment_id: string;
          amount: number;
          receipt_date: string;
          payment_account_id: string;
          reference: string;
          reason: string;
          actor_id: string;
          journal_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          adjustment_id?: string;
          amount?: number;
          receipt_date?: string;
          payment_account_id?: string;
          reference?: string;
          reason?: string;
          actor_id?: string;
          journal_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      staff_reimbursements: {
        Row: {
          id: string;
          claim_no: string;
          organization_id: string;
          staff_id: string;
          category_id: string;
          expense_date: string;
          amount: number;
          description: string;
          receipt_reference: string;
          status: string;
          revision: number;
          expense_id: string | null;
          review_note: string | null;
          created_by: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          claim_no?: string;
          organization_id: string;
          staff_id: string;
          category_id: string;
          expense_date: string;
          amount: number;
          description: string;
          receipt_reference: string;
          status?: string;
          revision?: number;
          expense_id?: string | null;
          review_note?: string | null;
          created_by: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          claim_no?: string;
          organization_id?: string;
          staff_id?: string;
          category_id?: string;
          expense_date?: string;
          amount?: number;
          description?: string;
          receipt_reference?: string;
          status?: string;
          revision?: number;
          expense_id?: string | null;
          review_note?: string | null;
          created_by?: string;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      academy_assets: {
        Row: {
          id: string;
          asset_no: string;
          organization_id: string;
          name: string;
          serial_no: string | null;
          location: string;
          vendor_id: string;
          source_purchase_id: string | null;
          asset_account_id: string;
          cost: number;
          residual: number;
          life_months: number;
          acquired_on: string;
          in_service_on: string;
          depreciation_start: string;
          invoice_reference: string;
          status: string;
          custodian_id: string | null;
          payable_id: string | null;
          acquisition_journal_id: string | null;
          revision: number;
          created_by: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          asset_no?: string;
          organization_id: string;
          name: string;
          serial_no?: string | null;
          location: string;
          vendor_id: string;
          source_purchase_id?: string | null;
          asset_account_id: string;
          cost: number;
          residual: number;
          life_months: number;
          acquired_on: string;
          in_service_on: string;
          depreciation_start: string;
          invoice_reference: string;
          status?: string;
          custodian_id?: string | null;
          payable_id?: string | null;
          acquisition_journal_id?: string | null;
          revision?: number;
          created_by: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          asset_no?: string;
          organization_id?: string;
          name?: string;
          serial_no?: string | null;
          location?: string;
          vendor_id?: string;
          source_purchase_id?: string | null;
          asset_account_id?: string;
          cost?: number;
          residual?: number;
          life_months?: number;
          acquired_on?: string;
          in_service_on?: string;
          depreciation_start?: string;
          invoice_reference?: string;
          status?: string;
          custodian_id?: string | null;
          payable_id?: string | null;
          acquisition_journal_id?: string | null;
          revision?: number;
          created_by?: string;
          created_at?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      asset_depreciation_entries: {
        Row: {
          id: string;
          asset_id: string;
          month: string;
          amount: number;
          journal_id: string | null;
          actor_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          asset_id: string;
          month: string;
          amount: number;
          journal_id?: string | null;
          actor_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          asset_id?: string;
          month?: string;
          amount?: number;
          journal_id?: string | null;
          actor_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      asset_events: {
        Row: {
          id: string;
          event_order: number;
          asset_id: string;
          action: string;
          actor_id: string;
          reason: string;
          payload: Json;
          created_at: string;
        };
        Insert: {
          id?: string;
          asset_id: string;
          action: string;
          actor_id: string;
          reason: string;
          payload: Json;
          created_at?: string;
        };
        Update: {
          id?: string;
          asset_id?: string;
          action?: string;
          actor_id?: string;
          reason?: string;
          payload?: Json;
          created_at?: string;
        };
        Relationships: [];
      };
      asset_disposals: {
        Row: {
          id: string;
          asset_id: string;
          disposed_on: string;
          proceeds: number;
          book_value: number;
          journal_id: string;
          reference: string;
          actor_id: string;
          reason: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          asset_id: string;
          disposed_on: string;
          proceeds: number;
          book_value: number;
          journal_id: string;
          reference: string;
          actor_id: string;
          reason: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          asset_id?: string;
          disposed_on?: string;
          proceeds?: number;
          book_value?: number;
          journal_id?: string;
          reference?: string;
          actor_id?: string;
          reason?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_handover_receipts: {
        Row: {
          close_id: string;
          recipient_id: string;
          actor_id: string;
          outcome: string;
          counted_amount: number;
          reason: string;
          created_at: string;
        };
        Insert: {
          close_id: string;
          recipient_id: string;
          actor_id: string;
          outcome: string;
          counted_amount: number;
          reason: string;
          created_at?: string;
        };
        Update: {
          close_id?: string;
          recipient_id?: string;
          actor_id?: string;
          outcome?: string;
          counted_amount?: number;
          reason?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_cash_counters: {
        Row: {
          id: string;
          account_id: string;
          payment_method_id: string;
          name: string;
          is_active: boolean;
          revision: number;
          created_by: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          account_id: string;
          payment_method_id: string;
          name: string;
          is_active?: boolean;
          revision?: number;
          created_by: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          account_id?: string;
          payment_method_id?: string;
          name?: string;
          is_active?: boolean;
          revision?: number;
          created_by?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_counter_shifts: {
        Row: {
          id: string;
          counter_id: string;
          staff_id: string;
          work_date: string;
          opening_balance: number;
          float_amount: number;
          source_account_id: string | null;
          journal_id: string | null;
          opened_by: string;
          reason: string;
          opened_at: string;
          closed_at: string | null;
          close_id: string | null;
          closed_by: string | null;
          event_order: number;
        };
        Insert: {
          id?: string;
          counter_id: string;
          staff_id: string;
          work_date: string;
          opening_balance: number;
          float_amount: number;
          source_account_id?: string | null;
          journal_id?: string | null;
          opened_by: string;
          reason: string;
          opened_at?: string;
          closed_at?: string | null;
          close_id?: string | null;
          closed_by?: string | null;
          event_order?: number;
        };
        Update: {
          id?: string;
          counter_id?: string;
          staff_id?: string;
          work_date?: string;
          opening_balance?: number;
          float_amount?: number;
          source_account_id?: string | null;
          journal_id?: string | null;
          opened_by?: string;
          reason?: string;
          opened_at?: string;
          closed_at?: string | null;
          close_id?: string | null;
          closed_by?: string | null;
          event_order?: number;
        };
        Relationships: [];
      };
      finance_counter_receipts: {
        Row: {
          id: string;
          event_order: number;
          shift_id: string;
          actor_id: string;
          outcome: string;
          counted_amount: number;
          reason: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          shift_id: string;
          actor_id: string;
          outcome: string;
          counted_amount: number;
          reason: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          shift_id?: string;
          actor_id?: string;
          outcome?: string;
          counted_amount?: number;
          reason?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_counter_transfers: {
        Row: {
          id: string;
          counter_id: string;
          shift_id: string;
          kind: string;
          amount: number;
          source_account_id: string;
          destination_account_id: string;
          journal_id: string;
          close_id: string | null;
          reference: string;
          reason: string;
          actor_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          counter_id: string;
          shift_id: string;
          kind: string;
          amount: number;
          source_account_id: string;
          destination_account_id: string;
          journal_id: string;
          close_id?: string | null;
          reference: string;
          reason: string;
          actor_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          counter_id?: string;
          shift_id?: string;
          kind?: string;
          amount?: number;
          source_account_id?: string;
          destination_account_id?: string;
          journal_id?: string;
          close_id?: string | null;
          reference?: string;
          reason?: string;
          actor_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_counter_transfer_receipts: {
        Row: {
          id: string;
          event_order: number;
          transfer_id: string;
          actor_id: string;
          outcome: string;
          counted_amount: number;
          reason: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          transfer_id: string;
          actor_id: string;
          outcome: string;
          counted_amount: number;
          reason: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          transfer_id?: string;
          actor_id?: string;
          outcome?: string;
          counted_amount?: number;
          reason?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      staff_payroll_month_terms: {
        Row: {
          id: string;
          staff_id: string;
          month: string;
          terms: Json;
          reason: string;
          actor_id: string;
          created_at: string;
          event_order: number;
        };
        Insert: {
          id?: string;
          staff_id: string;
          month: string;
          terms: Json;
          reason: string;
          actor_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          staff_id?: string;
          month?: string;
          terms?: Json;
          reason?: string;
          actor_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      staff_payroll_adjustments: {
        Row: {
          id: string;
          payroll_id: string;
          amount: number;
          posted_on: string;
          reason: string;
          actor_id: string;
          journal_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          payroll_id: string;
          amount: number;
          posted_on: string;
          reason: string;
          actor_id: string;
          journal_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          payroll_id?: string;
          amount?: number;
          posted_on?: string;
          reason?: string;
          actor_id?: string;
          journal_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_recurring_expenses: {
        Row: {
          id: string;
          organization_id: string;
          name: string;
          vendor_id: string;
          category_id: string;
          amount: number;
          first_month: string;
          due_day: number;
          is_active: boolean;
          revision: number;
          actor_id: string;
          reason: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          name: string;
          vendor_id: string;
          category_id: string;
          amount: number;
          first_month: string;
          due_day: number;
          is_active?: boolean;
          revision?: number;
          actor_id: string;
          reason: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          name?: string;
          vendor_id?: string;
          category_id?: string;
          amount?: number;
          first_month?: string;
          due_day?: number;
          is_active?: boolean;
          revision?: number;
          actor_id?: string;
          reason?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      finance_recurring_occurrences: {
        Row: {
          id: string;
          schedule_id: string;
          month: string;
          purchase_id: string;
          snapshot: Json;
          event_order: number;
          actor_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          schedule_id: string;
          month: string;
          purchase_id: string;
          snapshot: Json;
          actor_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          schedule_id?: string;
          month?: string;
          purchase_id?: string;
          snapshot?: Json;
          actor_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_collection_promises: {
        Row: {
          id: string;
          invoice_id: string;
          amount: number;
          due_on: string;
          baseline_net_paid: number;
          status: string;
          revision: number;
          reason: string;
          actor_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          invoice_id: string;
          amount: number;
          due_on: string;
          baseline_net_paid: number;
          status?: string;
          revision?: number;
          reason: string;
          actor_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          invoice_id?: string;
          amount?: number;
          due_on?: string;
          baseline_net_paid?: number;
          status?: string;
          revision?: number;
          reason?: string;
          actor_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_collection_events: {
        Row: {
          id: string;
          invoice_id: string;
          promise_id: string | null;
          action: string;
          reason: string;
          actor_id: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          invoice_id: string;
          promise_id?: string | null;
          action: string;
          reason: string;
          actor_id: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          invoice_id?: string;
          promise_id?: string | null;
          action?: string;
          reason?: string;
          actor_id?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_owners: {
        Row: {
          id: string;
          organization_id: string;
          name: string;
          contact: string;
          is_active: boolean;
          revision: number;
          actor_id: string;
          reason: string;
        };
        Insert: {
          id?: string;
          organization_id: string;
          name: string;
          contact?: string;
          is_active?: boolean;
          revision?: number;
          actor_id: string;
          reason: string;
        };
        Update: {
          id?: string;
          organization_id?: string;
          name?: string;
          contact?: string;
          is_active?: boolean;
          revision?: number;
          actor_id?: string;
          reason?: string;
        };
        Relationships: [];
      };
      finance_capital_movements: {
        Row: {
          id: string;
          owner_id: string;
          kind: string;
          amount: number;
          account_id: string;
          reference: string;
          journal_id: string;
          actor_id: string;
          reason: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          owner_id: string;
          kind: string;
          amount: number;
          account_id: string;
          reference: string;
          journal_id: string;
          actor_id: string;
          reason: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          owner_id?: string;
          kind?: string;
          amount?: number;
          account_id?: string;
          reference?: string;
          journal_id?: string;
          actor_id?: string;
          reason?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_budgets: {
        Row: {
          id: string;
          centre_id: string;
          month: string;
          revenue_target: number;
          expense_limit: number;
          cash_in: number;
          cash_out: number;
          revision: number;
          actor_id: string;
          reason: string;
        };
        Insert: {
          id?: string;
          centre_id: string;
          month: string;
          revenue_target: number;
          expense_limit: number;
          cash_in: number;
          cash_out: number;
          revision?: number;
          actor_id: string;
          reason: string;
        };
        Update: {
          id?: string;
          centre_id?: string;
          month?: string;
          revenue_target?: number;
          expense_limit?: number;
          cash_in?: number;
          cash_out?: number;
          revision?: number;
          actor_id?: string;
          reason?: string;
        };
        Relationships: [];
      };
      finance_line_allocations: {
        Row: {
          id: string;
          line_id: string;
          allocation: Json;
          event_order: number;
          actor_id: string;
          reason: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          line_id: string;
          allocation: Json;
          actor_id: string;
          reason: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          line_id?: string;
          allocation?: Json;
          actor_id?: string;
          reason?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_bank_imports: {
        Row: {
          id: string;
          account_id: string;
          statement_reference: string;
          actor_id: string;
          reason: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          account_id: string;
          statement_reference: string;
          actor_id: string;
          reason: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          account_id?: string;
          statement_reference?: string;
          actor_id?: string;
          reason?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      finance_bank_transactions: {
        Row: {
          id: string;
          import_id: string;
          account_id: string;
          transaction_date: string;
          reference: string;
          description: string;
          amount: number;
        };
        Insert: {
          id?: string;
          import_id: string;
          account_id: string;
          transaction_date: string;
          reference: string;
          description?: string;
          amount: number;
        };
        Update: {
          id?: string;
          import_id?: string;
          account_id?: string;
          transaction_date?: string;
          reference?: string;
          description?: string;
          amount?: number;
        };
        Relationships: [];
      };
      finance_bank_links: {
        Row: {
          id: string;
          transaction_id: string;
          line_id: string;
          actor_id: string;
          reason: string;
          matched_at: string;
          released_at: string | null;
          released_by: string | null;
          release_reason: string | null;
        };
        Insert: {
          id?: string;
          transaction_id: string;
          line_id: string;
          actor_id: string;
          reason: string;
          matched_at?: string;
          released_at?: string | null;
          released_by?: string | null;
          release_reason?: string | null;
        };
        Update: {
          id?: string;
          transaction_id?: string;
          line_id?: string;
          actor_id?: string;
          reason?: string;
          matched_at?: string;
          released_at?: string | null;
          released_by?: string | null;
          release_reason?: string | null;
        };
        Relationships: [];
      };
      finance_cash_classifications: {
        Row: {
          id: string;
          journal_id: string;
          category: string;
          event_order: number;
          actor_id: string;
          reason: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          journal_id: string;
          category: string;
          actor_id: string;
          reason: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          journal_id?: string;
          category?: string;
          actor_id?: string;
          reason?: string;
          created_at?: string;
        };
        Relationships: [];
      };
    };
    Views: {
      current_fee_plans: { Row: {
        id: string | null;
        offering_id: string | null;
        version: number | null;
        status: Database["public"]["Enums"]["rule_status"] | null;
        billing_cycle: string | null;
        due_day: number | null;
        currency_code: string | null;
        effective_from: string | null;
        effective_to: string | null;
        change_reason: string | null;
        created_by: string | null;
        created_at: string | null;
      }; Relationships: [] };
      current_fee_plan_components: { Row: {
        id: string | null;
        fee_plan_version_id: string | null;
        code: string | null;
        name: string | null;
        amount: number | null;
        charge_type: string | null;
        recurrence: string | null;
        sort_order: number | null;
      }; Relationships: [] };
      current_operating_rules: { Row: {
        id: string | null;
        domain: string | null;
        rule_key: string | null;
        status: Database["public"]["Enums"]["rule_status"] | null;
        payload: Json | null;
      }; Relationships: [] };
      finance_receivable_rows: { Row: {
        id: string | null;
        invoice_no: string | null;
        student_id: string | null;
        admission_id: string | null;
        issued_on: string | null;
        due_on: string | null;
        student_no: string | null;
        full_name: string | null;
        gross: number | null;
        credits: number | null;
        net: number | null;
        paid: number | null;
        refunded: number | null;
        due: number | null;
        age_days: number | null;
        bucket: string | null;
        guardian: string | null;
        mobile: string | null;
        promise_id: string | null;
        promise_amount: number | null;
        promise_due: string | null;
        promise_revision: number | null;
        promise_collected: number | null;
        last_contact: string | null;
      }; Relationships: [] };
    };
    Functions: {
      generate_staff_no: {
        Args: Record<string, never>;
        Returns: string;
      };
      generate_prospect_no: {
        Args: Record<string, never>;
        Returns: string;
      };
      generate_student_no: {
        Args: Record<string, never>;
        Returns: string;
      };
      has_permission: {
        Args: {
          p_permission_code: string;
        };
        Returns: boolean;
      };
      my_erp_context: {
        Args: Record<string, never>;
        Returns: Json;
      };
      bootstrap_admin: {
        Args: {
          p_email: string;
          p_full_name?: string | null;
        };
        Returns: Json;
      };
      submit_public_interest: {
        Args: {
          p_payload: Json;
        };
        Returns: Json;
      };
      create_staff_member: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      is_valid_prospect_transition: {
        Args: {
          p_from: string;
        };
        Returns: boolean;
      };
      record_prospect_followup: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      publish_business_rule_version: {
        Args: {
          p_domain: string;
          p_rule_key: string;
          p_payload: Json;
          p_reason: string;
        };
        Returns: Json;
      };
      set_role_permissions: {
        Args: {
          p_role_code: string;
          p_permission_codes: string[];
          p_reason: string;
        };
        Returns: Json;
      };
      validate_business_rule_payload: {
        Args: {
          p_domain: string;
          p_rule_key: string;
          p_payload: Json;
        };
        Returns: boolean;
      };
      set_user_operational_roles: {
        Args: {
          p_profile_id: string;
          p_role_codes: string[];
          p_reason: string;
          p_branch_id?: string | null;
        };
        Returns: Json;
      };
      manage_crm_master_record: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      update_programme_offering_public_controls: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      list_public_programme_offerings: {
        Args: Record<string, never>;
        Returns: Json;
      };
      link_staff_profile_by_email: {
        Args: {
          p_email: string;
        };
        Returns: string;
      };
      admin_review_queue: {
        Args: Record<string, never>;
        Returns: Json;
      };
      save_fee_plan: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      save_offering_discount_policy: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      academy_setup_status: {
        Args: Record<string, never>;
        Returns: Json;
      };
      complete_academy_setup: {
        Args: Record<string, never>;
        Returns: Json;
      };
      record_lifecycle_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      request_staff_access: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      review_staff_access: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      edit_staff_record: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      save_academy_identity: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      create_admission_directory_choice: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      audit_event_list: {
        Args: {
          p_correlation?: string | null;
        };
        Returns: Json;
      };
      prospect_assignment_options: {
        Args: Record<string, never>;
        Returns: Json;
      };
      assign_prospect_staff: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      create_programme_offering: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      update_programme_offering: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      invoice_balance: {
        Args: {
          p_invoice_id: string;
        };
        Returns: Json;
      };
      admission_payment_satisfied: {
        Args: {
          p_admission_id: string;
        };
        Returns: boolean;
      };
      post_admission_payment: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      admission_workspace: {
        Args: Record<string, never>;
        Returns: Json;
      };
      apply_invoice_discounts: {
        Args: {
          p_invoice_id: string;
        };
        Returns: undefined;
      };
      billing_preview: {
        Args: {
          p_period: string;
          p_term_id?: string | null;
        };
        Returns: Json;
      };
      student_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      student_profile_workspace: {
        Args: {
          p_student_id: string;
        };
        Returns: Json;
      };
      batch_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      record_physical_admission_consent: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      admission_offering_options: {
        Args: Record<string, never>;
        Returns: Json;
      };
      admission_discount_options: {
        Args: {
          p_admission_id: string;
        };
        Returns: Json;
      };
      edit_admission_identity: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      admission_review_checks: {
        Args: {
          p_admission_id: string;
        };
        Returns: Json;
      };
      create_staff_admission_intake: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      admission_directory_options: {
        Args: Record<string, never>;
        Returns: Json;
      };
      save_admission_extra_charge: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      deactivate_admission_extra_charge: {
        Args: {
          p_admission_id: string;
          p_charge_id: string;
        };
        Returns: undefined;
      };
      admission_case_detail: {
        Args: {
          p_admission_id: string;
        };
        Returns: Json;
      };
      correct_admission_placement: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      admission_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      close_student_enrollment: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      create_prospect_admission: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      execute_admission_stage: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      finance_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      finance_account_balance: {
        Args: {
          p_account_id: string;
          p_as_of?: string | null;
        };
        Returns: number;
      };
      advance_balance: {
        Args: {
          p_advance_id: string;
        };
        Returns: number;
      };
      finance_post_journal_engine: {
        Args: {
          p_organization_id: string;
          p_journal_date: string;
          p_journal_type: string;
          p_source_type: string;
          p_source_id: string;
          p_description: string;
          p_posted_by: string;
          p_lines: Json;
        };
        Returns: string;
      };
      finance_sync_invoice: {
        Args: {
          p_invoice_id: string;
        };
        Returns: string;
      };
      finance_sync_invoice_credit: {
        Args: {
          p_credit_id: string;
        };
        Returns: string;
      };
      finance_sync_payment: {
        Args: {
          p_payment_id: string;
        };
        Returns: string;
      };
      finance_sync_refund: {
        Args: {
          p_payout_id: string;
        };
        Returns: string;
      };
      finance_net_collected_tuition: {
        Args: {
          p_from: string;
          p_to: string;
        };
        Returns: Json;
      };
      teacher_compensation_preview: {
        Args: {
          p_from: string;
          p_to: string;
        };
        Returns: Json;
      };
      finance_accounting_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      advance_paid: {
        Args: {
          p_advance_id: string;
        };
        Returns: number;
      };
      finance_read_account_balance: {
        Args: {
          p_account_id: string;
          p_as_of?: string | null;
        };
        Returns: number;
      };
      referral_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      finance_workspace: {
        Args: Record<string, never>;
        Returns: Json;
      };
      apply_finance_adjustment: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      post_accounting_operation: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      can_access_class_session: {
        Args: {
          p_session: string;
        };
        Returns: boolean;
      };
      academic_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      academic_workspace: {
        Args: {
          p_from: string;
          p_to: string;
        };
        Returns: Json;
      };
      class_session_workspace: {
        Args: {
          p_session_id: string;
        };
        Returns: Json;
      };
      class_log_workspace: {
        Args: {
          p_session_id: string;
        };
        Returns: Json;
      };
      class_log_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      question_bank_workspace: {
        Args: Record<string, never>;
        Returns: Json;
      };
      question_bank_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      homework_workspace: {
        Args: {
          p_session_id: string;
        };
        Returns: Json;
      };
      homework_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      can_access_assessment: {
        Args: {
          p_batch: string;
          p_subject: string;
        };
        Returns: boolean;
      };
      assessment_workspace: {
        Args: Record<string, never>;
        Returns: Json;
      };
      assessment_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      attendance_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      referral_invoice_collections: {
        Args: {
          p_admission_id: string;
        };
        Returns: Json;
      };
      sync_referral_reward: {
        Args: {
          p_admission_id: string;
        };
        Returns: undefined;
      };
      referrer_paid: {
        Args: {
          p_referrer: string;
        };
        Returns: number;
      };
      referrer_workspace: {
        Args: {
          p_referrer_id?: string | null;
        };
        Returns: Json;
      };
      manage_referrer: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      settle_referrer_reward: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      collect_student_payment: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      finance_operating_summary: {
        Args: Record<string, never>;
        Returns: Json;
      };
      save_referral_operating_rules: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      audit_event_page: {
        Args: {
          p_filters?: Json | null;
        };
        Returns: Json;
      };
      complete_own_staff_access: {
        Args: Record<string, never>;
        Returns: undefined;
      };
      workforce_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      staff_work_workspace: {
        Args: {
          p_month?: string | null;
          p_staff_id?: string | null;
          p_page?: number | null;
        };
        Returns: Json;
      };
      staff_task_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      staff_tasks_workspace: {
        Args: {
          p_staff_id?: string | null;
          p_history?: boolean | null;
          p_page?: number | null;
        };
        Returns: Json;
      };
      staff_payroll_preview: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      staff_payroll_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      staff_payroll_workspace: {
        Args: {
          p_id?: string | null;
          p_page?: number | null;
        };
        Returns: Json;
      };
      my_salary_summary: {
        Args: Record<string, never>;
        Returns: Json;
      };
      daily_close_preview: {
        Args: {
          p_account_id: string;
          p_date: string;
        };
        Returns: Json;
      };
      daily_close_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      daily_close_workspace: {
        Args: {
          p_page?: number | null;
        };
        Returns: Json;
      };
      finance_account_ledger_token: {
        Args: {
          p_account: string;
          p_date: string;
        };
        Returns: string;
      };
      monthly_financial_report: {
        Args: {
          p_month?: string | null;
        };
        Returns: Json;
      };
      finance_period_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      purchase_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      purchase_workspace: {
        Args: {
          p_page?: number | null;
          p_status?: string | null;
          p_search?: string | null;
        };
        Returns: Json;
      };
      purchase_directory_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      purchase_directory_workspace: {
        Args: {
          p_kind?: string | null;
          p_page?: number | null;
          p_search?: string | null;
        };
        Returns: Json;
      };
      finance_document_entity_allowed: {
        Args: {
          p_type: string;
          p_id: string;
        };
        Returns: boolean;
      };
      finance_document_storage_allowed: {
        Args: {
          p_path: string;
          p_write: boolean;
        };
        Returns: boolean;
      };
      finance_document_prepare: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      finance_document_complete: {
        Args: {
          p_id: string;
        };
        Returns: Json;
      };
      finance_document_workspace: {
        Args: {
          p_type: string;
          p_id: string;
        };
        Returns: Json;
      };
      finance_document_batch: {
        Args: {
          p_type: string;
          p_ids: string[];
        };
        Returns: Json;
      };
      purchase_adjustment_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      purchase_adjustment_workspace: {
        Args: {
          p_ids: string[];
        };
        Returns: Json;
      };
      reimbursement_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      reimbursement_workspace: {
        Args: {
          p_page?: number | null;
          p_status?: string | null;
        };
        Returns: Json;
      };
      asset_access: {
        Args: {
          p_id: string;
        };
        Returns: boolean;
      };
      asset_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      asset_workspace: {
        Args: {
          p_page?: number | null;
          p_status?: string | null;
          p_search?: string | null;
        };
        Returns: Json;
      };
      cash_handover_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      cash_handover_workspace: {
        Args: {
          p_page?: number | null;
        };
        Returns: Json;
      };
      cash_handover_recipients: {
        Args: Record<string, never>;
        Returns: Json;
      };
      finance_post_journal: {
        Args: {
          p_organization_id: string;
          p_journal_date: string;
          p_journal_type: string;
          p_source_type: string;
          p_source_id: string;
          p_description: string;
          p_posted_by: string;
          p_lines: Json;
        };
        Returns: string;
      };
      cash_counter_base_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      cash_counter_workspace: {
        Args: {
          p_page?: number | null;
        };
        Returns: Json;
      };
      cash_counter_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      counter_transfer_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      counter_transfer_workspace: {
        Args: {
          p_page?: number | null;
          p_counter_ids?: string[] | null;
          p_pending?: boolean | null;
        };
        Returns: Json;
      };
      payroll_recovery_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      recurring_expense_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      recurring_expense_workspace: {
        Args: {
          p_month?: string | null;
          p_page?: number | null;
        };
        Returns: Json;
      };
      collection_followup_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      receivable_workspace: {
        Args: {
          p_page?: number | null;
          p_search?: string | null;
          p_bucket?: string | null;
          p_promises?: boolean | null;
          p_student_id?: string | null;
        };
        Returns: Json;
      };
      owner_capital_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      owner_capital_workspace: {
        Args: {
          p_page?: number | null;
          p_owner_id?: string | null;
        };
        Returns: Json;
      };
      finance_planning_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      finance_planning_workspace: {
        Args: {
          p_month?: string | null;
          p_page?: number | null;
        };
        Returns: Json;
      };
      bank_reconciliation_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      bank_reconciliation_workspace: {
        Args: {
          p_account_id?: string | null;
          p_page?: number | null;
          p_search?: string | null;
          p_unmatched?: boolean | null;
        };
        Returns: Json;
      };
      bank_match_candidates: {
        Args: {
          p_id: string;
          p_page?: number | null;
          p_search?: string | null;
        };
        Returns: Json;
      };
      finance_cash_default_class: {
        Args: {
          p_source: string;
          p_type: string;
        };
        Returns: string;
      };
      cash_classification_command: {
        Args: {
          p_input: Json;
        };
        Returns: Json;
      };
      classified_cash_flow: {
        Args: {
          p_month?: string | null;
          p_page?: number | null;
        };
        Returns: Json;
      };
    };
    Enums: {
      approval_status: "PENDING" | "APPROVED" | "REJECTED" | "CANCELLED";
      enrollment_status: "ACTIVE" | "COMPLETED" | "WITHDRAWN" | "CANCELLED";
      offering_status: "DRAFT" | "ACTIVE" | "RETIRED";
      profile_status: "ACTIVE" | "SUSPENDED" | "ARCHIVED";
      prospect_status: "NEW" | "CONTACTED" | "COUNSELLING" | "TRIAL_SCHEDULED" | "TRIAL_ATTENDED" | "REGISTERED" | "CONVERTED" | "FUTURE_FOLLOW_UP" | "LOST";
      rule_status: "DRAFT" | "ACTIVE" | "RETIRED";
      staff_status: "ACTIVE" | "ON_LEAVE" | "RESIGNED" | "TERMINATED" | "ARCHIVED";
      student_status: "ACTIVE" | "INACTIVE" | "WITHDRAWN" | "GRADUATED" | "ARCHIVED";
    };
    CompositeTypes: Record<string, never>;
  };
};
