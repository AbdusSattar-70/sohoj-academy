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
          starts_on: string
        }
        Insert: {
          created_at?: string
          ends_on: string
          id?: string
          is_active?: boolean
          name: string
          starts_on: string
        }
        Update: {
          created_at?: string
          ends_on?: string
          id?: string
          is_active?: boolean
          name?: string
          starts_on?: string
        }
        Relationships: []
      }
      approval_requests: {
        Row: {
          correlation_id: string
          decided_at: string | null
          decided_by: string | null
          decision_note: string | null
          entity_id: string
          entity_type: string
          id: string
          payload_snapshot: Json | null
          request_note: string | null
          requested_action: string
          requested_at: string
          requested_by: string
          status: Database["public"]["Enums"]["approval_status"]
          workflow_type: string
        }
        Insert: {
          correlation_id?: string
          decided_at?: string | null
          decided_by?: string | null
          decision_note?: string | null
          entity_id: string
          entity_type: string
          id?: string
          payload_snapshot?: Json | null
          request_note?: string | null
          requested_action: string
          requested_at?: string
          requested_by: string
          status?: Database["public"]["Enums"]["approval_status"]
          workflow_type: string
        }
        Update: {
          correlation_id?: string
          decided_at?: string | null
          decided_by?: string | null
          decision_note?: string | null
          entity_id?: string
          entity_type?: string
          id?: string
          payload_snapshot?: Json | null
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
      assessment_results: {
        Row: {
          assessment_id: string
          marks: number
          remarks: string | null
          student_id: string
        }
        Insert: {
          assessment_id: string
          marks: number
          remarks?: string | null
          student_id: string
        }
        Update: {
          assessment_id?: string
          marks?: number
          remarks?: string | null
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "assessment_results_assessment_id_fkey"
            columns: ["assessment_id"]
            isOneToOne: false
            referencedRelation: "assessments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assessment_results_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      assessments: {
        Row: {
          academic_year_id: string
          assessment_type: string
          batch_id: string
          created_at: string
          created_by: string | null
          held_on: string
          id: string
          subject_id: string | null
          title: string
          total_marks: number
        }
        Insert: {
          academic_year_id: string
          assessment_type: string
          batch_id: string
          created_at?: string
          created_by?: string | null
          held_on: string
          id?: string
          subject_id?: string | null
          title: string
          total_marks: number
        }
        Update: {
          academic_year_id?: string
          assessment_type?: string
          batch_id?: string
          created_at?: string
          created_by?: string | null
          held_on?: string
          id?: string
          subject_id?: string | null
          title?: string
          total_marks?: number
        }
        Relationships: [
          {
            foreignKeyName: "assessments_academic_year_id_fkey"
            columns: ["academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assessments_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assessments_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assessments_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      attendance: {
        Row: {
          id: string
          marked_at: string
          marked_by: string | null
          remarks: string | null
          session_id: string
          status: Database["public"]["Enums"]["attendance_status"]
          student_id: string
        }
        Insert: {
          id?: string
          marked_at?: string
          marked_by?: string | null
          remarks?: string | null
          session_id: string
          status: Database["public"]["Enums"]["attendance_status"]
          student_id: string
        }
        Update: {
          id?: string
          marked_at?: string
          marked_by?: string | null
          remarks?: string | null
          session_id?: string
          status?: Database["public"]["Enums"]["attendance_status"]
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_marked_by_fkey"
            columns: ["marked_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "class_sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_events: {
        Row: {
          action: string
          actor_id: string | null
          actor_role: Database["public"]["Enums"]["app_role"] | null
          after_data: Json | null
          before_data: Json | null
          correlation_id: string
          entity_id: string
          entity_type: string
          id: number
          metadata: Json
          occurred_at: string
          reason: string | null
        }
        Insert: {
          action: string
          actor_id?: string | null
          actor_role?: Database["public"]["Enums"]["app_role"] | null
          after_data?: Json | null
          before_data?: Json | null
          correlation_id?: string
          entity_id: string
          entity_type: string
          id?: never
          metadata?: Json
          occurred_at?: string
          reason?: string | null
        }
        Update: {
          action?: string
          actor_id?: string | null
          actor_role?: Database["public"]["Enums"]["app_role"] | null
          after_data?: Json | null
          before_data?: Json | null
          correlation_id?: string
          entity_id?: string
          entity_type?: string
          id?: never
          metadata?: Json
          occurred_at?: string
          reason?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_logs: {
        Row: {
          action: string
          actor_id: string | null
          created_at: string
          id: number
          new_data: Json | null
          old_data: Json | null
          record_id: string | null
          table_name: string
        }
        Insert: {
          action: string
          actor_id?: string | null
          created_at?: string
          id?: never
          new_data?: Json | null
          old_data?: Json | null
          record_id?: string | null
          table_name: string
        }
        Update: {
          action?: string
          actor_id?: string | null
          created_at?: string
          id?: never
          new_data?: Json | null
          old_data?: Json | null
          record_id?: string | null
          table_name?: string
        }
        Relationships: []
      }
      batches: {
        Row: {
          academic_year_id: string
          capacity: number
          class_id: string
          id: string
          is_active: boolean
          name: string
          program_id: string | null
        }
        Insert: {
          academic_year_id: string
          capacity?: number
          class_id: string
          id?: string
          is_active?: boolean
          name: string
          program_id?: string | null
        }
        Update: {
          academic_year_id?: string
          capacity?: number
          class_id?: string
          id?: string
          is_active?: boolean
          name?: string
          program_id?: string | null
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
            foreignKeyName: "batches_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
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
      business_rule_versions: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          created_at: string
          created_by: string | null
          effective_from: string
          effective_to: string | null
          id: string
          notes: string | null
          rule_key: string
          status: string
          value: Json
          version: number
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          created_by?: string | null
          effective_from?: string
          effective_to?: string | null
          id?: string
          notes?: string | null
          rule_key: string
          status?: string
          value: Json
          version: number
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          created_by?: string | null
          effective_from?: string
          effective_to?: string | null
          id?: string
          notes?: string | null
          rule_key?: string
          status?: string
          value?: Json
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "business_rule_versions_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "business_rule_versions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      class_sessions: {
        Row: {
          batch_id: string
          classroom_id: string | null
          ends_at: string
          id: string
          notes: string | null
          session_date: string
          session_type: string
          starts_at: string
          subject_id: string | null
          teacher_id: string | null
        }
        Insert: {
          batch_id: string
          classroom_id?: string | null
          ends_at: string
          id?: string
          notes?: string | null
          session_date: string
          session_type?: string
          starts_at: string
          subject_id?: string | null
          teacher_id?: string | null
        }
        Update: {
          batch_id?: string
          classroom_id?: string | null
          ends_at?: string
          id?: string
          notes?: string | null
          session_date?: string
          session_type?: string
          starts_at?: string
          subject_id?: string | null
          teacher_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "class_sessions_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_sessions_classroom_id_fkey"
            columns: ["classroom_id"]
            isOneToOne: false
            referencedRelation: "classrooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_sessions_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_sessions_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "teachers"
            referencedColumns: ["id"]
          },
        ]
      }
      classes: {
        Row: {
          id: string
          name: string
          sort_order: number
        }
        Insert: {
          id?: string
          name: string
          sort_order?: number
        }
        Update: {
          id?: string
          name?: string
          sort_order?: number
        }
        Relationships: []
      }
      classrooms: {
        Row: {
          capacity: number | null
          id: string
          is_active: boolean
          name: string
        }
        Insert: {
          capacity?: number | null
          id?: string
          is_active?: boolean
          name: string
        }
        Update: {
          capacity?: number | null
          id?: string
          is_active?: boolean
          name?: string
        }
        Relationships: []
      }
      enrollments: {
        Row: {
          academic_year_id: string
          admission_date: string
          batch_id: string | null
          class_id: string
          discount: number
          effective_fee: number | null
          id: string
          is_active: boolean
          monthly_fee: number
          program_id: string | null
          student_id: string
        }
        Insert: {
          academic_year_id: string
          admission_date?: string
          batch_id?: string | null
          class_id: string
          discount?: number
          effective_fee?: number | null
          id?: string
          is_active?: boolean
          monthly_fee?: number
          program_id?: string | null
          student_id: string
        }
        Update: {
          academic_year_id?: string
          admission_date?: string
          batch_id?: string | null
          class_id?: string
          discount?: number
          effective_fee?: number | null
          id?: string
          is_active?: boolean
          monthly_fee?: number
          program_id?: string | null
          student_id?: string
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
            foreignKeyName: "enrollments_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
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
      fee_structures: {
        Row: {
          academic_year_id: string
          amount: number
          class_id: string | null
          effective_from: string
          effective_to: string | null
          frequency: string
          id: string
          program_id: string | null
          title: string
        }
        Insert: {
          academic_year_id: string
          amount: number
          class_id?: string | null
          effective_from: string
          effective_to?: string | null
          frequency?: string
          id?: string
          program_id?: string | null
          title: string
        }
        Update: {
          academic_year_id?: string
          amount?: number
          class_id?: string | null
          effective_from?: string
          effective_to?: string | null
          frequency?: string
          id?: string
          program_id?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "fee_structures_academic_year_id_fkey"
            columns: ["academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fee_structures_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fee_structures_program_id_fkey"
            columns: ["program_id"]
            isOneToOne: false
            referencedRelation: "programs"
            referencedColumns: ["id"]
          },
        ]
      }
      guardians: {
        Row: {
          address: string | null
          alternate_mobile: string | null
          created_at: string
          id: string
          mobile: string
          name: string
        }
        Insert: {
          address?: string | null
          alternate_mobile?: string | null
          created_at?: string
          id?: string
          mobile: string
          name: string
        }
        Update: {
          address?: string | null
          alternate_mobile?: string | null
          created_at?: string
          id?: string
          mobile?: string
          name?: string
        }
        Relationships: []
      }
      notices: {
        Row: {
          audience: string
          body: string
          created_at: string
          created_by: string | null
          id: string
          published_at: string | null
          title: string
        }
        Insert: {
          audience?: string
          body: string
          created_at?: string
          created_by?: string | null
          id?: string
          published_at?: string | null
          title: string
        }
        Update: {
          audience?: string
          body?: string
          created_at?: string
          created_by?: string | null
          id?: string
          published_at?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "notices_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      parent_communications: {
        Row: {
          communication_type: string
          guardian_id: string | null
          id: string
          next_follow_up: string | null
          notes: string
          occurred_at: string
          recorded_by: string | null
          student_id: string
        }
        Insert: {
          communication_type: string
          guardian_id?: string | null
          id?: string
          next_follow_up?: string | null
          notes: string
          occurred_at?: string
          recorded_by?: string | null
          student_id: string
        }
        Update: {
          communication_type?: string
          guardian_id?: string | null
          id?: string
          next_follow_up?: string | null
          notes?: string
          occurred_at?: string
          recorded_by?: string | null
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "parent_communications_guardian_id_fkey"
            columns: ["guardian_id"]
            isOneToOne: false
            referencedRelation: "guardians"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "parent_communications_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "parent_communications_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          amount: number
          collected_by: string | null
          created_at: string
          enrollment_id: string | null
          id: string
          method: string
          notes: string | null
          payment_date: string
          receipt_no: string
          status: Database["public"]["Enums"]["payment_status"]
          student_id: string
          void_reason: string | null
          voided_at: string | null
          voided_by: string | null
        }
        Insert: {
          amount: number
          collected_by?: string | null
          created_at?: string
          enrollment_id?: string | null
          id?: string
          method?: string
          notes?: string | null
          payment_date?: string
          receipt_no: string
          status?: Database["public"]["Enums"]["payment_status"]
          student_id: string
          void_reason?: string | null
          voided_at?: string | null
          voided_by?: string | null
        }
        Update: {
          amount?: number
          collected_by?: string | null
          created_at?: string
          enrollment_id?: string | null
          id?: string
          method?: string
          notes?: string | null
          payment_date?: string
          receipt_no?: string
          status?: Database["public"]["Enums"]["payment_status"]
          student_id?: string
          void_reason?: string | null
          voided_at?: string | null
          voided_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "payments_collected_by_fkey"
            columns: ["collected_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_enrollment_id_fkey"
            columns: ["enrollment_id"]
            isOneToOne: false
            referencedRelation: "enrollments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_voided_by_fkey"
            columns: ["voided_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          full_name: string
          guardian_id: string | null
          id: string
          role: Database["public"]["Enums"]["app_role"]
          student_id: string | null
        }
        Insert: {
          created_at?: string
          full_name: string
          guardian_id?: string | null
          id: string
          role: Database["public"]["Enums"]["app_role"]
          student_id?: string | null
        }
        Update: {
          created_at?: string
          full_name?: string
          guardian_id?: string | null
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          student_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "profiles_guardian_id_fkey"
            columns: ["guardian_id"]
            isOneToOne: false
            referencedRelation: "guardians"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      programs: {
        Row: {
          code: string | null
          created_at: string
          id: string
          is_active: boolean
          name: string
        }
        Insert: {
          code?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
        }
        Update: {
          code?: string | null
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
        }
        Relationships: []
      }
      recovery_logs: {
        Row: {
          created_at: string
          entity_id: string
          entity_type: string
          id: string
          reason: string
          recovered_by: string | null
          snapshot: Json | null
        }
        Insert: {
          created_at?: string
          entity_id: string
          entity_type: string
          id?: string
          reason: string
          recovered_by?: string | null
          snapshot?: Json | null
        }
        Update: {
          created_at?: string
          entity_id?: string
          entity_type?: string
          id?: string
          reason?: string
          recovered_by?: string | null
          snapshot?: Json | null
        }
        Relationships: [
          {
            foreignKeyName: "recovery_logs_recovered_by_fkey"
            columns: ["recovered_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      schools: {
        Row: {
          area: string | null
          created_at: string
          created_by: string | null
          district: string | null
          id: string
          is_active: boolean
          name: string
          name_bn: string | null
          updated_at: string
        }
        Insert: {
          area?: string | null
          created_at?: string
          created_by?: string | null
          district?: string | null
          id?: string
          is_active?: boolean
          name: string
          name_bn?: string | null
          updated_at?: string
        }
        Update: {
          area?: string | null
          created_at?: string
          created_by?: string | null
          district?: string | null
          id?: string
          is_active?: boolean
          name?: string
          name_bn?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "schools_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      student_fee_assignments: {
        Row: {
          amount: number
          discount: number
          effective_from: string
          effective_to: string | null
          enrollment_id: string
          fee_structure_id: string | null
          id: string
        }
        Insert: {
          amount: number
          discount?: number
          effective_from: string
          effective_to?: string | null
          enrollment_id: string
          fee_structure_id?: string | null
          id?: string
        }
        Update: {
          amount?: number
          discount?: number
          effective_from?: string
          effective_to?: string | null
          enrollment_id?: string
          fee_structure_id?: string | null
          id?: string
        }
        Relationships: [
          {
            foreignKeyName: "student_fee_assignments_enrollment_id_fkey"
            columns: ["enrollment_id"]
            isOneToOne: false
            referencedRelation: "enrollments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_fee_assignments_fee_structure_id_fkey"
            columns: ["fee_structure_id"]
            isOneToOne: false
            referencedRelation: "fee_structures"
            referencedColumns: ["id"]
          },
        ]
      }
      student_guardians: {
        Row: {
          guardian_id: string
          is_primary: boolean
          relationship: string
          student_id: string
        }
        Insert: {
          guardian_id: string
          is_primary?: boolean
          relationship: string
          student_id: string
        }
        Update: {
          guardian_id?: string
          is_primary?: boolean
          relationship?: string
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
          created_at: string
          date_of_birth: string | null
          gender: string | null
          id: string
          name: string
          name_bn: string | null
          school_id: string | null
          school_name: string | null
          school_roll: string | null
          status: Database["public"]["Enums"]["student_status"]
          student_no: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          date_of_birth?: string | null
          gender?: string | null
          id?: string
          name: string
          name_bn?: string | null
          school_id?: string | null
          school_name?: string | null
          school_roll?: string | null
          status?: Database["public"]["Enums"]["student_status"]
          student_no?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          date_of_birth?: string | null
          gender?: string | null
          id?: string
          name?: string
          name_bn?: string | null
          school_id?: string | null
          school_name?: string | null
          school_roll?: string | null
          status?: Database["public"]["Enums"]["student_status"]
          student_no?: string
          updated_at?: string
        }
        Relationships: [
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
          code: string | null
          id: string
          is_active: boolean
          name: string
        }
        Insert: {
          code?: string | null
          id?: string
          is_active?: boolean
          name: string
        }
        Update: {
          code?: string | null
          id?: string
          is_active?: boolean
          name?: string
        }
        Relationships: []
      }
      teacher_subjects: {
        Row: {
          subject_id: string
          teacher_id: string
        }
        Insert: {
          subject_id: string
          teacher_id: string
        }
        Update: {
          subject_id?: string
          teacher_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "teacher_subjects_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_subjects_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "teachers"
            referencedColumns: ["id"]
          },
        ]
      }
      teachers: {
        Row: {
          created_at: string
          id: string
          is_active: boolean
          mobile: string | null
          name: string
          profile_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean
          mobile?: string | null
          name: string
          profile_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean
          mobile?: string | null
          name?: string
          profile_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "teachers_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      weekly_monitoring: {
        Row: {
          homework_score: number | null
          id: string
          participation_score: number | null
          recorded_by: string | null
          remarks: string | null
          student_id: string
          test_score: number | null
          week_start: string
        }
        Insert: {
          homework_score?: number | null
          id?: string
          participation_score?: number | null
          recorded_by?: string | null
          remarks?: string | null
          student_id: string
          test_score?: number | null
          week_start: string
        }
        Update: {
          homework_score?: number | null
          id?: string
          participation_score?: number | null
          recorded_by?: string | null
          remarks?: string | null
          student_id?: string
          test_score?: number | null
          week_start?: string
        }
        Relationships: [
          {
            foreignKeyName: "weekly_monitoring_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "weekly_monitoring_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      create_admission: {
        Args: { p_enrollment: Json; p_guardian: Json; p_student: Json }
        Returns: Json
      }
      current_role: {
        Args: never
        Returns: Database["public"]["Enums"]["app_role"]
      }
      generate_receipt_no: { Args: never; Returns: string }
      generate_student_no: { Args: never; Returns: string }
      post_payment: {
        Args: {
          p_amount: number
          p_enrollment_id: string | null
          p_idempotency_key: string
          p_method: string
          p_notes: string | null
          p_payment_date: string
          p_student_id: string
        }
        Returns: Json
      }
      record_audit_event: {
        Args: {
          p_action: string
          p_after_data?: Json
          p_before_data?: Json
          p_correlation_id?: string
          p_entity_id: string
          p_entity_type: string
          p_metadata?: Json
          p_reason?: string
        }
        Returns: number
      }
      save_assessment_results: {
        Args: { p_assessment_id: string; p_entries: Json }
        Returns: number
      }
      save_attendance: {
        Args: { p_entries: Json; p_session_id: string }
        Returns: number
      }
    }
    Enums: {
      app_role: "ADMIN" | "OPERATOR" | "TEACHER" | "GUARDIAN" | "STUDENT"
      approval_status: "PENDING" | "APPROVED" | "REJECTED" | "CANCELLED"
      attendance_status: "PRESENT" | "ABSENT" | "LATE" | "EXCUSED"
      payment_status: "POSTED" | "VOID"
      student_status: "ACTIVE" | "INACTIVE" | "GRADUATED" | "WITHDRAWN"
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
      app_role: ["ADMIN", "OPERATOR", "TEACHER", "GUARDIAN", "STUDENT"],
      approval_status: ["PENDING", "APPROVED", "REJECTED", "CANCELLED"],
      attendance_status: ["PRESENT", "ABSENT", "LATE", "EXCUSED"],
      payment_status: ["POSTED", "VOID"],
      student_status: ["ACTIVE", "INACTIVE", "GRADUATED", "WITHDRAWN"],
    },
  },
} as const
