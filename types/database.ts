export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      academic_years: {
        Row: {
          created_at: string
          ends_on: string
          id: string
          is_active: boolean
          name: string
          organization_id: string
          starts_on: string
        }
        Insert: {
          created_at?: string
          ends_on: string
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
          starts_on: string
        }
        Update: {
          created_at?: string
          ends_on?: string
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
          starts_on?: string
        }
        Relationships: [
          {
            foreignKeyName: "academic_years_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      approval_requests: {
        Row: {
          correlation_id: string
          created_at: string
          decided_at: string | null
          decided_by: string | null
          decision_note: string | null
          entity_id: string
          entity_type: string
          id: string
          payload_snapshot: Json
          request_note: string | null
          requested_action: string
          requested_at: string
          requested_by: string
          status: Database["public"]["Enums"]["approval_status"]
          workflow_type: string
        }
        Insert: {
          correlation_id?: string
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          decision_note?: string | null
          entity_id: string
          entity_type: string
          id?: string
          payload_snapshot?: Json
          request_note?: string | null
          requested_action: string
          requested_at?: string
          requested_by: string
          status?: Database["public"]["Enums"]["approval_status"]
          workflow_type: string
        }
        Update: {
          correlation_id?: string
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          decision_note?: string | null
          entity_id?: string
          entity_type?: string
          id?: string
          payload_snapshot?: Json
          request_note?: string | null
          requested_action?: string
          requested_at?: string
          requested_by?: string
          status?: Database["public"]["Enums"]["approval_status"]
          workflow_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "approval_requests_decided_by_fkey"
            columns: ["decided_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "approval_requests_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      areas: {
        Row: {
          created_at: string
          id: string
          is_active: boolean
          name: string
          organization_id: string
          parent_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
          parent_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
          parent_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "areas_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "areas_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "areas"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_events: {
        Row: {
          action: string
          actor_profile_id: string | null
          actor_role_code: string | null
          actor_staff_id: string | null
          after_data: Json | null
          before_data: Json | null
          branch_id: string | null
          correlation_id: string
          entity_id: string
          entity_type: string
          id: string
          metadata: Json
          occurred_at: string
          reason: string | null
        }
        Insert: {
          action: string
          actor_profile_id?: string | null
          actor_role_code?: string | null
          actor_staff_id?: string | null
          after_data?: Json | null
          before_data?: Json | null
          branch_id?: string | null
          correlation_id?: string
          entity_id: string
          entity_type: string
          id?: string
          metadata?: Json
          occurred_at?: string
          reason?: string | null
        }
        Update: {
          action?: string
          actor_profile_id?: string | null
          actor_role_code?: string | null
          actor_staff_id?: string | null
          after_data?: Json | null
          before_data?: Json | null
          branch_id?: string | null
          correlation_id?: string
          entity_id?: string
          entity_type?: string
          id?: string
          metadata?: Json
          occurred_at?: string
          reason?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_events_actor_profile_id_fkey"
            columns: ["actor_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_events_actor_staff_id_fkey"
            columns: ["actor_staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_events_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
        ]
      }
      batches: {
        Row: {
          academic_year_id: string
          branch_id: string | null
          capacity: number
          class_id: string
          code: string
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean
          name: string
          organization_id: string
          program_id: string | null
          updated_at: string
        }
        Insert: {
          academic_year_id: string
          branch_id?: string | null
          capacity: number
          class_id: string
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
          program_id?: string | null
          updated_at?: string
        }
        Update: {
          academic_year_id?: string
          branch_id?: string | null
          capacity?: number
          class_id?: string
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
          program_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "batches_academic_year_id_fkey"
            columns: ["academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "batches_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "batches_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "batches_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "batches_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "batches_program_id_fkey"
            columns: ["program_id"]
            isOneToOne: false
            referencedRelation: "programs"
            referencedColumns: ["id"]
          },
        ]
      }
      branches: {
        Row: {
          address: string | null
          code: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          organization_id: string
          timezone: string
          updated_at: string
        }
        Insert: {
          address?: string | null
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
          timezone?: string
          updated_at?: string
        }
        Update: {
          address?: string | null
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
          timezone?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "branches_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      business_rule_versions: {
        Row: {
          change_reason: string
          created_at: string
          created_by: string | null
          domain: string
          effective_from: string
          effective_to: string | null
          id: string
          payload: Json
          rule_key: string
          status: Database["public"]["Enums"]["rule_status"]
          version: number
        }
        Insert: {
          change_reason: string
          created_at?: string
          created_by?: string | null
          domain: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          payload: Json
          rule_key: string
          status?: Database["public"]["Enums"]["rule_status"]
          version: number
        }
        Update: {
          change_reason?: string
          created_at?: string
          created_by?: string | null
          domain?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          payload?: Json
          rule_key?: string
          status?: Database["public"]["Enums"]["rule_status"]
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "business_rule_versions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      classes: {
        Row: {
          code: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          organization_id: string
          sort_order: number
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
          sort_order?: number
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "classes_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      enrollments: {
        Row: {
          academic_year_id: string
          admission_date: string
          batch_id: string | null
          branch_id: string | null
          class_id: string
          created_at: string
          created_by: string | null
          ended_on: string | null
          id: string
          organization_id: string
          program_id: string | null
          status: Database["public"]["Enums"]["enrollment_status"]
          student_id: string
          updated_at: string
        }
        Insert: {
          academic_year_id: string
          admission_date?: string
          batch_id?: string | null
          branch_id?: string | null
          class_id: string
          created_at?: string
          created_by?: string | null
          ended_on?: string | null
          id?: string
          organization_id: string
          program_id?: string | null
          status?: Database["public"]["Enums"]["enrollment_status"]
          student_id: string
          updated_at?: string
        }
        Update: {
          academic_year_id?: string
          admission_date?: string
          batch_id?: string | null
          branch_id?: string | null
          class_id?: string
          created_at?: string
          created_by?: string | null
          ended_on?: string | null
          id?: string
          organization_id?: string
          program_id?: string | null
          status?: Database["public"]["Enums"]["enrollment_status"]
          student_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "enrollments_academic_year_id_fkey"
            columns: ["academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollments_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollments_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollments_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollments_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollments_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollments_program_id_fkey"
            columns: ["program_id"]
            isOneToOne: false
            referencedRelation: "programs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollments_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      guardian_relationships: {
        Row: {
          code: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          organization_id: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "guardian_relationships_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      guardians: {
        Row: {
          address: string | null
          alternate_mobile: string | null
          created_at: string
          created_by: string | null
          email: string | null
          full_name: string
          id: string
          mobile: string
          organization_id: string
          updated_at: string
        }
        Insert: {
          address?: string | null
          alternate_mobile?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          full_name: string
          id?: string
          mobile: string
          organization_id: string
          updated_at?: string
        }
        Update: {
          address?: string | null
          alternate_mobile?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          full_name?: string
          id?: string
          mobile?: string
          organization_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "guardians_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guardians_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      lead_sources: {
        Row: {
          code: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          organization_id: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "lead_sources_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          code: string
          created_at: string
          currency_code: string
          id: string
          is_active: boolean
          name: string
          timezone: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          currency_code?: string
          id?: string
          is_active?: boolean
          name: string
          timezone?: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          currency_code?: string
          id?: string
          is_active?: boolean
          name?: string
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      payment_methods: {
        Row: {
          code: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          organization_id: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_methods_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      permissions: {
        Row: {
          code: string
          created_at: string
          description: string | null
          id: string
          name: string
        }
        Insert: {
          code: string
          created_at?: string
          description?: string | null
          id?: string
          name: string
        }
        Update: {
          code?: string
          created_at?: string
          description?: string | null
          id?: string
          name?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          created_at: string
          display_name: string
          id: string
          status: Database["public"]["Enums"]["profile_status"]
          updated_at: string
        }
        Insert: {
          created_at?: string
          display_name: string
          id: string
          status?: Database["public"]["Enums"]["profile_status"]
          updated_at?: string
        }
        Update: {
          created_at?: string
          display_name?: string
          id?: string
          status?: Database["public"]["Enums"]["profile_status"]
          updated_at?: string
        }
        Relationships: []
      }
      programs: {
        Row: {
          code: string
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          name: string
          organization_id: string
        }
        Insert: {
          code: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
        }
        Update: {
          code?: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "programs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      prospect_followups: {
        Row: {
          created_at: string
          followup_type: string
          id: string
          next_follow_up_at: string | null
          notes: string
          occurred_at: string
          outcome: string | null
          prospect_id: string
          recorded_by: string
        }
        Insert: {
          created_at?: string
          followup_type: string
          id?: string
          next_follow_up_at?: string | null
          notes: string
          occurred_at?: string
          outcome?: string | null
          prospect_id: string
          recorded_by: string
        }
        Update: {
          created_at?: string
          followup_type?: string
          id?: string
          next_follow_up_at?: string | null
          notes?: string
          occurred_at?: string
          outcome?: string | null
          prospect_id?: string
          recorded_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "prospect_followups_prospect_id_fkey"
            columns: ["prospect_id"]
            isOneToOne: false
            referencedRelation: "prospects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "prospect_followups_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      prospect_program_interests: {
        Row: {
          created_at: string
          program_id: string
          prospect_id: string
        }
        Insert: {
          created_at?: string
          program_id: string
          prospect_id: string
        }
        Update: {
          created_at?: string
          program_id?: string
          prospect_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "prospect_program_interests_program_id_fkey"
            columns: ["program_id"]
            isOneToOne: false
            referencedRelation: "programs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "prospect_program_interests_prospect_id_fkey"
            columns: ["prospect_id"]
            isOneToOne: false
            referencedRelation: "prospects"
            referencedColumns: ["id"]
          },
        ]
      }
      prospect_subject_interests: {
        Row: {
          created_at: string
          prospect_id: string
          subject_id: string
        }
        Insert: {
          created_at?: string
          prospect_id: string
          subject_id: string
        }
        Update: {
          created_at?: string
          prospect_id?: string
          subject_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "prospect_subject_interests_prospect_id_fkey"
            columns: ["prospect_id"]
            isOneToOne: false
            referencedRelation: "prospects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "prospect_subject_interests_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      prospects: {
        Row: {
          alternate_mobile: string | null
          area_id: string | null
          area_snapshot: string | null
          assigned_to_staff_id: string | null
          branch_id: string | null
          consent_to_contact: boolean
          converted_at: string | null
          converted_student_id: string | null
          created_at: string
          current_class_id: string | null
          guardian_name: string
          guardian_relationship_id: string | null
          guardian_relationship_snapshot: string | null
          id: string
          lost_reason: string | null
          mobile: string
          next_follow_up_at: string | null
          notes: string | null
          organization_id: string
          preferred_days: string[]
          preferred_schedule: string | null
          prospect_no: string
          referral_note: string | null
          school_id: string | null
          school_name_snapshot: string | null
          source_id: string | null
          status: Database["public"]["Enums"]["prospect_status"]
          student_name: string
          student_name_bn: string | null
          submitted_via: string
          trial_interest: boolean
          updated_at: string
        }
        Insert: {
          alternate_mobile?: string | null
          area_id?: string | null
          area_snapshot?: string | null
          assigned_to_staff_id?: string | null
          branch_id?: string | null
          consent_to_contact?: boolean
          converted_at?: string | null
          converted_student_id?: string | null
          created_at?: string
          current_class_id?: string | null
          guardian_name: string
          guardian_relationship_id?: string | null
          guardian_relationship_snapshot?: string | null
          id?: string
          lost_reason?: string | null
          mobile: string
          next_follow_up_at?: string | null
          notes?: string | null
          organization_id: string
          preferred_days?: string[]
          preferred_schedule?: string | null
          prospect_no?: string
          referral_note?: string | null
          school_id?: string | null
          school_name_snapshot?: string | null
          source_id?: string | null
          status?: Database["public"]["Enums"]["prospect_status"]
          student_name: string
          student_name_bn?: string | null
          submitted_via?: string
          trial_interest?: boolean
          updated_at?: string
        }
        Update: {
          alternate_mobile?: string | null
          area_id?: string | null
          area_snapshot?: string | null
          assigned_to_staff_id?: string | null
          branch_id?: string | null
          consent_to_contact?: boolean
          converted_at?: string | null
          converted_student_id?: string | null
          created_at?: string
          current_class_id?: string | null
          guardian_name?: string
          guardian_relationship_id?: string | null
          guardian_relationship_snapshot?: string | null
          id?: string
          lost_reason?: string | null
          mobile?: string
          next_follow_up_at?: string | null
          notes?: string | null
          organization_id?: string
          preferred_days?: string[]
          preferred_schedule?: string | null
          prospect_no?: string
          referral_note?: string | null
          school_id?: string | null
          school_name_snapshot?: string | null
          source_id?: string | null
          status?: Database["public"]["Enums"]["prospect_status"]
          student_name?: string
          student_name_bn?: string | null
          submitted_via?: string
          trial_interest?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "prospects_area_id_fkey"
            columns: ["area_id"]
            isOneToOne: false
            referencedRelation: "areas"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "prospects_assigned_to_staff_id_fkey"
            columns: ["assigned_to_staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "prospects_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "prospects_converted_student_fkey"
            columns: ["converted_student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "prospects_current_class_id_fkey"
            columns: ["current_class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "prospects_guardian_relationship_id_fkey"
            columns: ["guardian_relationship_id"]
            isOneToOne: false
            referencedRelation: "guardian_relationships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "prospects_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "prospects_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "prospects_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "lead_sources"
            referencedColumns: ["id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          created_at: string
          permission_id: string
          role_id: string
        }
        Insert: {
          created_at?: string
          permission_id: string
          role_id: string
        }
        Update: {
          created_at?: string
          permission_id?: string
          role_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_permission_id_fkey"
            columns: ["permission_id"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_permissions_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "system_roles"
            referencedColumns: ["id"]
          },
        ]
      }
      schools: {
        Row: {
          area_id: string | null
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean
          is_verified: boolean
          name: string
          organization_id: string
          updated_at: string
        }
        Insert: {
          area_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          is_verified?: boolean
          name: string
          organization_id: string
          updated_at?: string
        }
        Update: {
          area_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          is_verified?: boolean
          name?: string
          organization_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "schools_area_id_fkey"
            columns: ["area_id"]
            isOneToOne: false
            referencedRelation: "areas"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "schools_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "schools_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      setting_definitions: {
        Row: {
          code: string
          created_at: string
          default_value: Json | null
          description: string | null
          group_code: string
          id: string
          is_active: boolean
          is_sensitive: boolean
          name: string
          sort_order: number
          validation_contract: Json
          value_type: string
        }
        Insert: {
          code: string
          created_at?: string
          default_value?: Json | null
          description?: string | null
          group_code: string
          id?: string
          is_active?: boolean
          is_sensitive?: boolean
          name: string
          sort_order?: number
          validation_contract?: Json
          value_type: string
        }
        Update: {
          code?: string
          created_at?: string
          default_value?: Json | null
          description?: string | null
          group_code?: string
          id?: string
          is_active?: boolean
          is_sensitive?: boolean
          name?: string
          sort_order?: number
          validation_contract?: Json
          value_type?: string
        }
        Relationships: []
      }
      setting_versions: {
        Row: {
          branch_id: string | null
          change_reason: string
          created_at: string
          created_by: string
          effective_from: string
          effective_to: string | null
          id: string
          organization_id: string
          setting_definition_id: string
          status: Database["public"]["Enums"]["rule_status"]
          value: Json
          version: number
        }
        Insert: {
          branch_id?: string | null
          change_reason: string
          created_at?: string
          created_by: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          organization_id: string
          setting_definition_id: string
          status?: Database["public"]["Enums"]["rule_status"]
          value: Json
          version: number
        }
        Update: {
          branch_id?: string | null
          change_reason?: string
          created_at?: string
          created_by?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          organization_id?: string
          setting_definition_id?: string
          status?: Database["public"]["Enums"]["rule_status"]
          value?: Json
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "setting_versions_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "setting_versions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "setting_versions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "setting_versions_setting_definition_id_fkey"
            columns: ["setting_definition_id"]
            isOneToOne: false
            referencedRelation: "setting_definitions"
            referencedColumns: ["id"]
          },
        ]
      }
      staff: {
        Row: {
          address: string | null
          alternate_mobile: string | null
          branch_id: string | null
          created_at: string
          created_by: string | null
          email: string | null
          emergency_contact_mobile: string | null
          emergency_contact_name: string | null
          full_name: string
          id: string
          joined_on: string | null
          left_on: string | null
          mobile: string | null
          notes: string | null
          profile_id: string | null
          staff_no: string
          status: Database["public"]["Enums"]["staff_status"]
          updated_at: string
        }
        Insert: {
          address?: string | null
          alternate_mobile?: string | null
          branch_id?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          emergency_contact_mobile?: string | null
          emergency_contact_name?: string | null
          full_name: string
          id?: string
          joined_on?: string | null
          left_on?: string | null
          mobile?: string | null
          notes?: string | null
          profile_id?: string | null
          staff_no?: string
          status?: Database["public"]["Enums"]["staff_status"]
          updated_at?: string
        }
        Update: {
          address?: string | null
          alternate_mobile?: string | null
          branch_id?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          emergency_contact_mobile?: string | null
          emergency_contact_name?: string | null
          full_name?: string
          id?: string
          joined_on?: string | null
          left_on?: string | null
          mobile?: string | null
          notes?: string | null
          profile_id?: string | null
          staff_no?: string
          status?: Database["public"]["Enums"]["staff_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "staff_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      staff_role_assignments: {
        Row: {
          assigned_by: string | null
          branch_id: string | null
          created_at: string
          effective_from: string
          effective_to: string | null
          id: string
          is_primary: boolean
          staff_id: string
          staff_role_id: string
        }
        Insert: {
          assigned_by?: string | null
          branch_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_primary?: boolean
          staff_id: string
          staff_role_id: string
        }
        Update: {
          assigned_by?: string | null
          branch_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_primary?: boolean
          staff_id?: string
          staff_role_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "staff_role_assignments_assigned_by_fkey"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_role_assignments_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_role_assignments_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_role_assignments_staff_role_id_fkey"
            columns: ["staff_role_id"]
            isOneToOne: false
            referencedRelation: "staff_roles"
            referencedColumns: ["id"]
          },
        ]
      }
      staff_roles: {
        Row: {
          code: string
          created_at: string
          id: string
          is_active: boolean
          is_teaching_role: boolean
          name: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          is_teaching_role?: boolean
          name: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          is_teaching_role?: boolean
          name?: string
        }
        Relationships: []
      }
      staff_subject_assignments: {
        Row: {
          assigned_by: string | null
          created_at: string
          effective_from: string
          effective_to: string | null
          id: string
          is_primary: boolean
          staff_id: string
          subject_id: string
        }
        Insert: {
          assigned_by?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_primary?: boolean
          staff_id: string
          subject_id: string
        }
        Update: {
          assigned_by?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_primary?: boolean
          staff_id?: string
          subject_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "staff_subject_assignments_assigned_by_fkey"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_subject_assignments_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_subject_assignments_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      student_guardians: {
        Row: {
          created_at: string
          guardian_id: string
          id: string
          is_primary: boolean
          relationship_id: string | null
          relationship_snapshot: string | null
          student_id: string
        }
        Insert: {
          created_at?: string
          guardian_id: string
          id?: string
          is_primary?: boolean
          relationship_id?: string | null
          relationship_snapshot?: string | null
          student_id: string
        }
        Update: {
          created_at?: string
          guardian_id?: string
          id?: string
          is_primary?: boolean
          relationship_id?: string | null
          relationship_snapshot?: string | null
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "student_guardians_guardian_id_fkey"
            columns: ["guardian_id"]
            isOneToOne: false
            referencedRelation: "guardians"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_guardians_relationship_id_fkey"
            columns: ["relationship_id"]
            isOneToOne: false
            referencedRelation: "guardian_relationships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_guardians_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      students: {
        Row: {
          branch_id: string | null
          created_at: string
          created_by: string | null
          created_from_prospect_id: string | null
          date_of_birth: string | null
          full_name: string
          gender: string | null
          id: string
          name_bn: string | null
          organization_id: string
          school_id: string | null
          school_name_snapshot: string | null
          school_roll: string | null
          status: Database["public"]["Enums"]["student_status"]
          student_no: string
          updated_at: string
        }
        Insert: {
          branch_id?: string | null
          created_at?: string
          created_by?: string | null
          created_from_prospect_id?: string | null
          date_of_birth?: string | null
          full_name: string
          gender?: string | null
          id?: string
          name_bn?: string | null
          organization_id: string
          school_id?: string | null
          school_name_snapshot?: string | null
          school_roll?: string | null
          status?: Database["public"]["Enums"]["student_status"]
          student_no?: string
          updated_at?: string
        }
        Update: {
          branch_id?: string | null
          created_at?: string
          created_by?: string | null
          created_from_prospect_id?: string | null
          date_of_birth?: string | null
          full_name?: string
          gender?: string | null
          id?: string
          name_bn?: string | null
          organization_id?: string
          school_id?: string | null
          school_name_snapshot?: string | null
          school_roll?: string | null
          status?: Database["public"]["Enums"]["student_status"]
          student_no?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "students_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_created_from_prospect_id_fkey"
            columns: ["created_from_prospect_id"]
            isOneToOne: true
            referencedRelation: "prospects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      subjects: {
        Row: {
          code: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          organization_id: string
        }
        Insert: {
          code: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
        }
        Update: {
          code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "subjects_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      system_roles: {
        Row: {
          code: string
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          is_system: boolean
          name: string
        }
        Insert: {
          code: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          is_system?: boolean
          name: string
        }
        Update: {
          code?: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          is_system?: boolean
          name?: string
        }
        Relationships: []
      }
      user_role_assignments: {
        Row: {
          assigned_by: string | null
          branch_id: string | null
          created_at: string
          effective_from: string
          effective_to: string | null
          id: string
          is_active: boolean
          profile_id: string
          role_id: string
        }
        Insert: {
          assigned_by?: string | null
          branch_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_active?: boolean
          profile_id: string
          role_id: string
        }
        Update: {
          assigned_by?: string | null
          branch_id?: string | null
          created_at?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_active?: boolean
          profile_id?: string
          role_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_role_assignments_assigned_by_fkey"
            columns: ["assigned_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_role_assignments_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_role_assignments_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_role_assignments_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "system_roles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      bootstrap_admin: {
        Args: { p_email: string; p_full_name?: string }
        Returns: Json
      }
      create_staff_member: { Args: { p_input: Json }; Returns: Json }
      generate_prospect_no: { Args: never; Returns: string }
      generate_staff_no: { Args: never; Returns: string }
      generate_student_no: { Args: never; Returns: string }
      has_permission: { Args: { p_permission_code: string }; Returns: boolean }
      is_valid_prospect_transition: {
        Args: {
          p_from: Database["public"]["Enums"]["prospect_status"]
          p_to: Database["public"]["Enums"]["prospect_status"]
        }
        Returns: boolean
      }
      my_erp_context: { Args: never; Returns: Json }
      publish_business_rule_version: {
        Args: {
          p_domain: string
          p_payload: Json
          p_reason: string
          p_rule_key: string
        }
        Returns: Json
      }
      publish_setting_value: {
        Args: {
          p_branch_id?: string
          p_reason: string
          p_setting_code: string
          p_value: Json
        }
        Returns: Json
      }
      record_prospect_followup: { Args: { p_input: Json }; Returns: Json }
      set_role_permissions: {
        Args: {
          p_permission_codes: string[]
          p_reason: string
          p_role_code: string
        }
        Returns: Json
      }
      set_user_operational_roles: {
        Args: {
          p_branch_id?: string
          p_profile_id: string
          p_reason: string
          p_role_codes: string[]
        }
        Returns: Json
      }
      submit_public_interest: { Args: { p_payload: Json }; Returns: Json }
      validate_business_rule_payload: {
        Args: { p_domain: string; p_payload: Json; p_rule_key: string }
        Returns: boolean
      }
      validate_setting_value: {
        Args: { p_value: Json; p_value_type: string }
        Returns: boolean
      }
    }
    Enums: {
      approval_status: "PENDING" | "APPROVED" | "REJECTED" | "CANCELLED"
      enrollment_status: "ACTIVE" | "COMPLETED" | "WITHDRAWN" | "CANCELLED"
      profile_status: "ACTIVE" | "SUSPENDED" | "ARCHIVED"
      prospect_status:
        | "NEW"
        | "CONTACTED"
        | "COUNSELLING"
        | "TRIAL_SCHEDULED"
        | "TRIAL_ATTENDED"
        | "REGISTERED"
        | "CONVERTED"
        | "FUTURE_FOLLOW_UP"
        | "LOST"
      rule_status: "DRAFT" | "ACTIVE" | "RETIRED"
      staff_status:
        | "ACTIVE"
        | "ON_LEAVE"
        | "RESIGNED"
        | "TERMINATED"
        | "ARCHIVED"
      student_status:
        | "ACTIVE"
        | "INACTIVE"
        | "WITHDRAWN"
        | "GRADUATED"
        | "ARCHIVED"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      approval_status: ["PENDING", "APPROVED", "REJECTED", "CANCELLED"],
      enrollment_status: ["ACTIVE", "COMPLETED", "WITHDRAWN", "CANCELLED"],
      profile_status: ["ACTIVE", "SUSPENDED", "ARCHIVED"],
      prospect_status: [
        "NEW",
        "CONTACTED",
        "COUNSELLING",
        "TRIAL_SCHEDULED",
        "TRIAL_ATTENDED",
        "REGISTERED",
        "CONVERTED",
        "FUTURE_FOLLOW_UP",
        "LOST",
      ],
      rule_status: ["DRAFT", "ACTIVE", "RETIRED"],
      staff_status: [
        "ACTIVE",
        "ON_LEAVE",
        "RESIGNED",
        "TERMINATED",
        "ARCHIVED",
      ],
      student_status: [
        "ACTIVE",
        "INACTIVE",
        "WITHDRAWN",
        "GRADUATED",
        "ARCHIVED",
      ],
    },
  },
} as const
