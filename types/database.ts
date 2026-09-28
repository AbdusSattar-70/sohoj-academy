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
      academic_assessments: {
        Row: {
          assessment_date: string
          author_id: string
          batch_id: string
          created_at: string
          id: string
          max_marks: number
          published_at: string | null
          status: string
          subject_id: string
          title: string
        }
        Insert: {
          assessment_date: string
          author_id: string
          batch_id: string
          created_at?: string
          id?: string
          max_marks: number
          published_at?: string | null
          status?: string
          subject_id: string
          title: string
        }
        Update: {
          assessment_date?: string
          author_id?: string
          batch_id?: string
          created_at?: string
          id?: string
          max_marks?: number
          published_at?: string | null
          status?: string
          subject_id?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "academic_assessments_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "academic_assessments_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "academic_assessments_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      academic_groups: {
        Row: {
          code: string
          id: string
          is_active: boolean
          name: string
          organization_id: string
        }
        Insert: {
          code: string
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
        }
        Update: {
          code?: string
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "academic_groups_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      academic_rooms: {
        Row: {
          branch_id: string
          capacity: number
          created_at: string
          created_by: string
          id: string
          name: string
        }
        Insert: {
          branch_id: string
          capacity: number
          created_at?: string
          created_by: string
          id?: string
          name: string
        }
        Update: {
          branch_id?: string
          capacity?: number
          created_at?: string
          created_by?: string
          id?: string
          name?: string
        }
        Relationships: [
          {
            foreignKeyName: "academic_rooms_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "academic_rooms_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      academic_routines: {
        Row: {
          batch_id: string
          created_at: string
          created_by: string
          end_time: string
          ends_on: string
          id: string
          retired_at: string | null
          room_id: string
          start_time: string
          starts_on: string
          subject_id: string
          teacher_id: string
          weekday: number
        }
        Insert: {
          batch_id: string
          created_at?: string
          created_by: string
          end_time: string
          ends_on: string
          id?: string
          retired_at?: string | null
          room_id: string
          start_time: string
          starts_on: string
          subject_id: string
          teacher_id: string
          weekday: number
        }
        Update: {
          batch_id?: string
          created_at?: string
          created_by?: string
          end_time?: string
          ends_on?: string
          id?: string
          retired_at?: string | null
          room_id?: string
          start_time?: string
          starts_on?: string
          subject_id?: string
          teacher_id?: string
          weekday?: number
        }
        Relationships: [
          {
            foreignKeyName: "academic_routines_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "academic_routines_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "academic_routines_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "academic_rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "academic_routines_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "academic_routines_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
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
      admission_cancellations: {
        Row: {
          admission_id: string
          approval_id: string
          cancelled_at: string
          settlement: string
        }
        Insert: {
          admission_id: string
          approval_id: string
          cancelled_at?: string
          settlement: string
        }
        Update: {
          admission_id?: string
          approval_id?: string
          cancelled_at?: string
          settlement?: string
        }
        Relationships: [
          {
            foreignKeyName: "admission_cancellations_admission_id_fkey"
            columns: ["admission_id"]
            isOneToOne: true
            referencedRelation: "admission_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_cancellations_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: true
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      admission_cases: {
        Row: {
          activation_policy_version_id: string | null
          admission_no: string
          batch_id: string
          capacity_policy_version_id: string | null
          consent_required: boolean
          created_at: string
          created_by: string
          enrollment_id: string | null
          existing_student: boolean
          fee_plan_version_id: string
          id: string
          identity_snapshot: Json
          prospect_id: string | null
          status: string
          student_id: string | null
          updated_at: string
        }
        Insert: {
          activation_policy_version_id?: string | null
          admission_no?: string
          batch_id: string
          capacity_policy_version_id?: string | null
          consent_required?: boolean
          created_at?: string
          created_by: string
          enrollment_id?: string | null
          existing_student?: boolean
          fee_plan_version_id: string
          id?: string
          identity_snapshot: Json
          prospect_id?: string | null
          status?: string
          student_id?: string | null
          updated_at?: string
        }
        Update: {
          activation_policy_version_id?: string | null
          admission_no?: string
          batch_id?: string
          capacity_policy_version_id?: string | null
          consent_required?: boolean
          created_at?: string
          created_by?: string
          enrollment_id?: string | null
          existing_student?: boolean
          fee_plan_version_id?: string
          id?: string
          identity_snapshot?: Json
          prospect_id?: string | null
          status?: string
          student_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "admission_cases_activation_policy_version_id_fkey"
            columns: ["activation_policy_version_id"]
            isOneToOne: false
            referencedRelation: "business_rule_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_cases_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_cases_capacity_policy_version_id_fkey"
            columns: ["capacity_policy_version_id"]
            isOneToOne: false
            referencedRelation: "business_rule_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_cases_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_cases_enrollment_id_fkey"
            columns: ["enrollment_id"]
            isOneToOne: true
            referencedRelation: "enrollments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_cases_fee_plan_version_id_fkey"
            columns: ["fee_plan_version_id"]
            isOneToOne: false
            referencedRelation: "fee_plan_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_cases_prospect_id_fkey"
            columns: ["prospect_id"]
            isOneToOne: false
            referencedRelation: "prospects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_cases_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      admission_command_keys: {
        Row: {
          actor_id: string
          created_at: string
          payload: Json
          request_id: string
          result: Json
        }
        Insert: {
          actor_id: string
          created_at?: string
          payload: Json
          request_id: string
          result: Json
        }
        Update: {
          actor_id?: string
          created_at?: string
          payload?: Json
          request_id?: string
          result?: Json
        }
        Relationships: [
          {
            foreignKeyName: "admission_command_keys_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      admission_consent_documents: {
        Row: {
          admission_id: string
          file_size: number
          guardian_signed_on: string
          id: string
          mime_type: string
          received_at: string
          received_by: string
          sha256: string
          storage_path: string
          student_signed: boolean
          version: number
        }
        Insert: {
          admission_id: string
          file_size: number
          guardian_signed_on: string
          id?: string
          mime_type: string
          received_at?: string
          received_by: string
          sha256: string
          storage_path: string
          student_signed?: boolean
          version: number
        }
        Update: {
          admission_id?: string
          file_size?: number
          guardian_signed_on?: string
          id?: string
          mime_type?: string
          received_at?: string
          received_by?: string
          sha256?: string
          storage_path?: string
          student_signed?: boolean
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "admission_consent_documents_admission_id_fkey"
            columns: ["admission_id"]
            isOneToOne: false
            referencedRelation: "admission_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_consent_documents_received_by_fkey"
            columns: ["received_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      admission_discounts: {
        Row: {
          admission_id: string
          approval_id: string
          created_at: string
          ends_on: string
          id: string
          kind: string
          starts_on: string
          value: number
        }
        Insert: {
          admission_id: string
          approval_id: string
          created_at?: string
          ends_on: string
          id?: string
          kind: string
          starts_on: string
          value: number
        }
        Update: {
          admission_id?: string
          approval_id?: string
          created_at?: string
          ends_on?: string
          id?: string
          kind?: string
          starts_on?: string
          value?: number
        }
        Relationships: [
          {
            foreignKeyName: "admission_discounts_admission_id_fkey"
            columns: ["admission_id"]
            isOneToOne: false
            referencedRelation: "admission_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_discounts_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: true
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
        ]
      }
      admission_invoice_lines: {
        Row: {
          amount: number
          charge_type: string
          fee_component_id: string
          id: string
          invoice_id: string
          name: string
        }
        Insert: {
          amount: number
          charge_type: string
          fee_component_id: string
          id?: string
          invoice_id: string
          name: string
        }
        Update: {
          amount?: number
          charge_type?: string
          fee_component_id?: string
          id?: string
          invoice_id?: string
          name?: string
        }
        Relationships: [
          {
            foreignKeyName: "admission_invoice_lines_fee_component_id_fkey"
            columns: ["fee_component_id"]
            isOneToOne: false
            referencedRelation: "fee_plan_components"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_invoice_lines_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "admission_invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      admission_invoices: {
        Row: {
          admission_id: string
          billing_period: string
          currency_code: string
          due_on: string
          fee_plan_version_id: string
          id: string
          invoice_kind: string
          invoice_no: string
          issued_on: string
          posted_at: string
          posted_by: string
          student_id: string
          total: number
        }
        Insert: {
          admission_id: string
          billing_period: string
          currency_code: string
          due_on: string
          fee_plan_version_id: string
          id?: string
          invoice_kind?: string
          invoice_no?: string
          issued_on: string
          posted_at?: string
          posted_by: string
          student_id: string
          total: number
        }
        Update: {
          admission_id?: string
          billing_period?: string
          currency_code?: string
          due_on?: string
          fee_plan_version_id?: string
          id?: string
          invoice_kind?: string
          invoice_no?: string
          issued_on?: string
          posted_at?: string
          posted_by?: string
          student_id?: string
          total?: number
        }
        Relationships: [
          {
            foreignKeyName: "admission_invoices_admission_id_fkey"
            columns: ["admission_id"]
            isOneToOne: false
            referencedRelation: "admission_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_invoices_fee_plan_version_id_fkey"
            columns: ["fee_plan_version_id"]
            isOneToOne: false
            referencedRelation: "fee_plan_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_invoices_posted_by_fkey"
            columns: ["posted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_invoices_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      admission_payment_allocations: {
        Row: {
          amount: number
          invoice_id: string
          payment_id: string
        }
        Insert: {
          amount: number
          invoice_id: string
          payment_id: string
        }
        Update: {
          amount?: number
          invoice_id?: string
          payment_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "admission_payment_allocations_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "admission_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_payment_allocations_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: true
            referencedRelation: "admission_payments"
            referencedColumns: ["id"]
          },
        ]
      }
      admission_payments: {
        Row: {
          amount: number
          currency_code: string
          external_reference: string | null
          id: string
          payment_method_id: string
          posted_at: string
          posted_by: string
          reason: string
          receipt_no: string
          student_id: string
        }
        Insert: {
          amount: number
          currency_code: string
          external_reference?: string | null
          id?: string
          payment_method_id: string
          posted_at?: string
          posted_by: string
          reason: string
          receipt_no?: string
          student_id: string
        }
        Update: {
          amount?: number
          currency_code?: string
          external_reference?: string | null
          id?: string
          payment_method_id?: string
          posted_at?: string
          posted_by?: string
          reason?: string
          receipt_no?: string
          student_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "admission_payments_payment_method_id_fkey"
            columns: ["payment_method_id"]
            isOneToOne: false
            referencedRelation: "payment_methods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_payments_posted_by_fkey"
            columns: ["posted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_payments_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      admission_physical_consent_receipts: {
        Row: {
          admission_id: string
          guardian_signed_on: string
          id: string
          physical_copy_reference: string | null
          reason: string
          received_at: string
          received_by: string
          request_id: string
          request_payload: Json
          student_signed: boolean
          version: number
        }
        Insert: {
          admission_id: string
          guardian_signed_on: string
          id?: string
          physical_copy_reference?: string | null
          reason: string
          received_at?: string
          received_by: string
          request_id: string
          request_payload: Json
          student_signed?: boolean
          version: number
        }
        Update: {
          admission_id?: string
          guardian_signed_on?: string
          id?: string
          physical_copy_reference?: string | null
          reason?: string
          received_at?: string
          received_by?: string
          request_id?: string
          request_payload?: Json
          student_signed?: boolean
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "admission_physical_consent_receipts_admission_id_fkey"
            columns: ["admission_id"]
            isOneToOne: false
            referencedRelation: "admission_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_physical_consent_receipts_received_by_fkey"
            columns: ["received_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      admission_referrals: {
        Row: {
          admission_id: string
          captured_at: string
          captured_by: string
          reason: string
          referrer_id: string | null
          source: string
        }
        Insert: {
          admission_id: string
          captured_at?: string
          captured_by: string
          reason: string
          referrer_id?: string | null
          source: string
        }
        Update: {
          admission_id?: string
          captured_at?: string
          captured_by?: string
          reason?: string
          referrer_id?: string | null
          source?: string
        }
        Relationships: [
          {
            foreignKeyName: "admission_referrals_admission_id_fkey"
            columns: ["admission_id"]
            isOneToOne: true
            referencedRelation: "admission_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_referrals_captured_by_fkey"
            columns: ["captured_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_referrals_referrer_id_fkey"
            columns: ["referrer_id"]
            isOneToOne: false
            referencedRelation: "referral_people"
            referencedColumns: ["id"]
          },
        ]
      }
      admission_requirement_reviews: {
        Row: {
          application_id: string
          id: string
          note: string
          requirement_label: string
          reviewed_at: string
          reviewed_by: string
          revision: number
          status: string
        }
        Insert: {
          application_id: string
          id?: string
          note?: string
          requirement_label: string
          reviewed_at?: string
          reviewed_by: string
          revision: number
          status: string
        }
        Update: {
          application_id?: string
          id?: string
          note?: string
          requirement_label?: string
          reviewed_at?: string
          reviewed_by?: string
          revision?: number
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "admission_requirement_reviews_application_id_fkey"
            columns: ["application_id"]
            isOneToOne: false
            referencedRelation: "public_admission_applications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admission_requirement_reviews_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
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
      assessment_result_submissions: {
        Row: {
          assessment_id: string
          author_id: string
          created_at: string
          entries: Json
          id: string
          review_note: string | null
          reviewed_at: string | null
          reviewer_id: string | null
          revision: number
          status: string
          submitted_at: string | null
        }
        Insert: {
          assessment_id: string
          author_id: string
          created_at?: string
          entries: Json
          id?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewer_id?: string | null
          revision: number
          status?: string
          submitted_at?: string | null
        }
        Update: {
          assessment_id?: string
          author_id?: string
          created_at?: string
          entries?: Json
          id?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewer_id?: string | null
          revision?: number
          status?: string
          submitted_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "assessment_result_submissions_assessment_id_fkey"
            columns: ["assessment_id"]
            isOneToOne: false
            referencedRelation: "academic_assessments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assessment_result_submissions_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assessment_result_submissions_reviewer_id_fkey"
            columns: ["reviewer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      attendance_submissions: {
        Row: {
          approval_id: string | null
          created_at: string
          entries: Json
          id: string
          reason: string
          recorded_by: string
          revision: number
          session_id: string
          status: string
        }
        Insert: {
          approval_id?: string | null
          created_at?: string
          entries: Json
          id?: string
          reason: string
          recorded_by: string
          revision: number
          session_id: string
          status?: string
        }
        Update: {
          approval_id?: string | null
          created_at?: string
          entries?: Json
          id?: string
          reason?: string
          recorded_by?: string
          revision?: number
          session_id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_submissions_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: true
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_submissions_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_submissions_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "class_sessions"
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
          capacity_policy_version_id: string | null
          class_id: string
          code: string
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean
          name: string
          offering_id: string | null
          organization_id: string
          program_id: string | null
          updated_at: string
        }
        Insert: {
          academic_year_id: string
          branch_id?: string | null
          capacity: number
          capacity_policy_version_id?: string | null
          class_id: string
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          name: string
          offering_id?: string | null
          organization_id: string
          program_id?: string | null
          updated_at?: string
        }
        Update: {
          academic_year_id?: string
          branch_id?: string | null
          capacity?: number
          capacity_policy_version_id?: string | null
          class_id?: string
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          name?: string
          offering_id?: string | null
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
            foreignKeyName: "batches_capacity_policy_version_id_fkey"
            columns: ["capacity_policy_version_id"]
            isOneToOne: false
            referencedRelation: "business_rule_versions"
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
            foreignKeyName: "batches_offering_id_fkey"
            columns: ["offering_id"]
            isOneToOne: false
            referencedRelation: "programme_offerings"
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
      billing_runs: {
        Row: {
          gross_total: number
          id: string
          invoice_count: number
          period: string
          posted_at: string
          posted_by: string
          reason: string
          term_id: string | null
        }
        Insert: {
          gross_total: number
          id: string
          invoice_count: number
          period: string
          posted_at?: string
          posted_by: string
          reason: string
          term_id?: string | null
        }
        Update: {
          gross_total?: number
          id?: string
          invoice_count?: number
          period?: string
          posted_at?: string
          posted_by?: string
          reason?: string
          term_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "billing_runs_posted_by_fkey"
            columns: ["posted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "billing_runs_term_id_fkey"
            columns: ["term_id"]
            isOneToOne: false
            referencedRelation: "billing_terms"
            referencedColumns: ["id"]
          },
        ]
      }
      billing_terms: {
        Row: {
          academic_year_id: string
          created_at: string
          created_by: string
          due_on: string
          ends_on: string
          id: string
          name: string
          starts_on: string
        }
        Insert: {
          academic_year_id: string
          created_at?: string
          created_by: string
          due_on: string
          ends_on: string
          id?: string
          name: string
          starts_on: string
        }
        Update: {
          academic_year_id?: string
          created_at?: string
          created_by?: string
          due_on?: string
          ends_on?: string
          id?: string
          name?: string
          starts_on?: string
        }
        Relationships: [
          {
            foreignKeyName: "billing_terms_academic_year_id_fkey"
            columns: ["academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "billing_terms_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
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
      class_logs: {
        Row: {
          authored_by: string
          class_summary: string
          created_at: string
          homework: string
          id: string
          next_session_plan: string
          previous_log_id: string | null
          reason: string
          revision: number
          session_id: string
          status: string
          submitted_at: string | null
          unfinished_reason: string
          unit_progress: Json
        }
        Insert: {
          authored_by: string
          class_summary: string
          created_at?: string
          homework?: string
          id?: string
          next_session_plan?: string
          previous_log_id?: string | null
          reason: string
          revision: number
          session_id: string
          status: string
          submitted_at?: string | null
          unfinished_reason?: string
          unit_progress?: Json
        }
        Update: {
          authored_by?: string
          class_summary?: string
          created_at?: string
          homework?: string
          id?: string
          next_session_plan?: string
          previous_log_id?: string | null
          reason?: string
          revision?: number
          session_id?: string
          status?: string
          submitted_at?: string | null
          unfinished_reason?: string
          unit_progress?: Json
        }
        Relationships: [
          {
            foreignKeyName: "class_logs_authored_by_fkey"
            columns: ["authored_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_logs_previous_log_id_fkey"
            columns: ["previous_log_id"]
            isOneToOne: false
            referencedRelation: "class_logs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_logs_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "class_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      class_sessions: {
        Row: {
          batch_id: string
          cancellation_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          created_at: string
          created_by: string
          curriculum_version_id: string | null
          ends_at: string
          id: string
          planned_scope: string
          room_id: string
          routine_id: string | null
          session_date: string
          starts_at: string
          status: string
          subject_id: string
          teacher_id: string
        }
        Insert: {
          batch_id: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          created_at?: string
          created_by: string
          curriculum_version_id?: string | null
          ends_at: string
          id?: string
          planned_scope: string
          room_id: string
          routine_id?: string | null
          session_date: string
          starts_at: string
          status?: string
          subject_id: string
          teacher_id: string
        }
        Update: {
          batch_id?: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          created_at?: string
          created_by?: string
          curriculum_version_id?: string | null
          ends_at?: string
          id?: string
          planned_scope?: string
          room_id?: string
          routine_id?: string | null
          session_date?: string
          starts_at?: string
          status?: string
          subject_id?: string
          teacher_id?: string
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
            foreignKeyName: "class_sessions_cancelled_by_fkey"
            columns: ["cancelled_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_sessions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_sessions_curriculum_version_id_fkey"
            columns: ["curriculum_version_id"]
            isOneToOne: false
            referencedRelation: "curriculum_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_sessions_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "academic_rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_sessions_routine_id_fkey"
            columns: ["routine_id"]
            isOneToOne: false
            referencedRelation: "academic_routines"
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
            referencedRelation: "staff"
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
      curriculum_versions: {
        Row: {
          batch_id: string
          id: string
          published_at: string
          published_by: string
          reason: string
          subject_id: string
          title: string
          units: Json
          version: number
        }
        Insert: {
          batch_id: string
          id?: string
          published_at?: string
          published_by: string
          reason: string
          subject_id: string
          title: string
          units: Json
          version: number
        }
        Update: {
          batch_id?: string
          id?: string
          published_at?: string
          published_by?: string
          reason?: string
          subject_id?: string
          title?: string
          units?: Json
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "curriculum_versions_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "curriculum_versions_published_by_fkey"
            columns: ["published_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "curriculum_versions_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      enrollment_transfers: {
        Row: {
          admission_id: string
          approval_id: string
          capacity_policy_version_id: string
          created_at: string
          from_batch_id: string
          from_enrollment_id: string
          id: string
          student_id: string
          to_batch_id: string
          to_enrollment_id: string
          transferred_on: string
        }
        Insert: {
          admission_id: string
          approval_id: string
          capacity_policy_version_id: string
          created_at?: string
          from_batch_id: string
          from_enrollment_id: string
          id?: string
          student_id: string
          to_batch_id: string
          to_enrollment_id: string
          transferred_on: string
        }
        Update: {
          admission_id?: string
          approval_id?: string
          capacity_policy_version_id?: string
          created_at?: string
          from_batch_id?: string
          from_enrollment_id?: string
          id?: string
          student_id?: string
          to_batch_id?: string
          to_enrollment_id?: string
          transferred_on?: string
        }
        Relationships: [
          {
            foreignKeyName: "enrollment_transfers_admission_id_fkey"
            columns: ["admission_id"]
            isOneToOne: false
            referencedRelation: "admission_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollment_transfers_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: true
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollment_transfers_capacity_policy_version_id_fkey"
            columns: ["capacity_policy_version_id"]
            isOneToOne: false
            referencedRelation: "business_rule_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollment_transfers_from_batch_id_fkey"
            columns: ["from_batch_id"]
            isOneToOne: false
            referencedRelation: "batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollment_transfers_from_enrollment_id_fkey"
            columns: ["from_enrollment_id"]
            isOneToOne: true
            referencedRelation: "enrollments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollment_transfers_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollment_transfers_to_batch_id_fkey"
            columns: ["to_batch_id"]
            isOneToOne: false
            referencedRelation: "batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "enrollment_transfers_to_enrollment_id_fkey"
            columns: ["to_enrollment_id"]
            isOneToOne: true
            referencedRelation: "enrollments"
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
      fee_plan_components: {
        Row: {
          amount: number
          charge_type: string
          code: string
          fee_plan_version_id: string
          id: string
          name: string
          recurrence: string
          sort_order: number
        }
        Insert: {
          amount: number
          charge_type: string
          code: string
          fee_plan_version_id: string
          id?: string
          name: string
          recurrence: string
          sort_order?: number
        }
        Update: {
          amount?: number
          charge_type?: string
          code?: string
          fee_plan_version_id?: string
          id?: string
          name?: string
          recurrence?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "fee_plan_components_fee_plan_version_id_fkey"
            columns: ["fee_plan_version_id"]
            isOneToOne: false
            referencedRelation: "fee_plan_versions"
            referencedColumns: ["id"]
          },
        ]
      }
      fee_plan_versions: {
        Row: {
          billing_cycle: string
          change_reason: string
          created_at: string
          created_by: string
          currency_code: string
          due_day: number | null
          effective_from: string
          effective_to: string | null
          id: string
          offering_id: string
          status: Database["public"]["Enums"]["rule_status"]
          version: number
        }
        Insert: {
          billing_cycle: string
          change_reason: string
          created_at?: string
          created_by: string
          currency_code?: string
          due_day?: number | null
          effective_from: string
          effective_to?: string | null
          id?: string
          offering_id: string
          status?: Database["public"]["Enums"]["rule_status"]
          version: number
        }
        Update: {
          billing_cycle?: string
          change_reason?: string
          created_at?: string
          created_by?: string
          currency_code?: string
          due_day?: number | null
          effective_from?: string
          effective_to?: string | null
          id?: string
          offering_id?: string
          status?: Database["public"]["Enums"]["rule_status"]
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "fee_plan_versions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fee_plan_versions_offering_id_fkey"
            columns: ["offering_id"]
            isOneToOne: false
            referencedRelation: "programme_offerings"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_account_reconciliations: {
        Row: {
          account_id: string
          difference: number
          id: string
          ledger_balance: number
          note: string
          reconciled_at: string | null
          reconciled_by: string | null
          statement_balance: number
          statement_date: string
          statement_reference: string
          status: string
        }
        Insert: {
          account_id: string
          difference: number
          id?: string
          ledger_balance: number
          note: string
          reconciled_at?: string | null
          reconciled_by?: string | null
          statement_balance: number
          statement_date: string
          statement_reference: string
          status: string
        }
        Update: {
          account_id?: string
          difference?: number
          id?: string
          ledger_balance?: number
          note?: string
          reconciled_at?: string | null
          reconciled_by?: string | null
          statement_balance?: number
          statement_date?: string
          statement_reference?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_account_reconciliations_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_account_reconciliations_reconciled_by_fkey"
            columns: ["reconciled_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_accounts: {
        Row: {
          account_subtype: string
          account_type: string
          code: string
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean
          is_control_account: boolean
          name: string
          organization_id: string
          parent_id: string | null
        }
        Insert: {
          account_subtype: string
          account_type: string
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          is_control_account?: boolean
          name: string
          organization_id: string
          parent_id?: string | null
        }
        Update: {
          account_subtype?: string
          account_type?: string
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          is_control_account?: boolean
          name?: string
          organization_id?: string
          parent_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "finance_accounts_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_accounts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_accounts_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_advance_movements: {
        Row: {
          advance_id: string
          amount: number
          created_at: string
          created_by: string
          id: string
          movement_type: string
          payable_id: string | null
          payment_account_id: string | null
          reason: string
          source_id: string | null
          source_type: string | null
        }
        Insert: {
          advance_id: string
          amount: number
          created_at?: string
          created_by: string
          id?: string
          movement_type: string
          payable_id?: string | null
          payment_account_id?: string | null
          reason: string
          source_id?: string | null
          source_type?: string | null
        }
        Update: {
          advance_id?: string
          amount?: number
          created_at?: string
          created_by?: string
          id?: string
          movement_type?: string
          payable_id?: string | null
          payment_account_id?: string | null
          reason?: string
          source_id?: string | null
          source_type?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "finance_advance_movements_advance_id_fkey"
            columns: ["advance_id"]
            isOneToOne: false
            referencedRelation: "finance_advances"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_advance_movements_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_advance_movements_payable_id_fkey"
            columns: ["payable_id"]
            isOneToOne: false
            referencedRelation: "finance_payables"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_advance_movements_payment_account_id_fkey"
            columns: ["payment_account_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_advances: {
        Row: {
          advance_no: string
          approval_id: string | null
          approved_amount: number | null
          beneficiary_type: string
          created_at: string
          expected_settlement_date: string | null
          id: string
          organization_id: string
          project_reference: string | null
          purpose: string
          requested_amount: number
          requested_by: string
          staff_id: string | null
          status: string
          vendor_id: string | null
        }
        Insert: {
          advance_no?: string
          approval_id?: string | null
          approved_amount?: number | null
          beneficiary_type: string
          created_at?: string
          expected_settlement_date?: string | null
          id?: string
          organization_id: string
          project_reference?: string | null
          purpose: string
          requested_amount: number
          requested_by: string
          staff_id?: string | null
          status?: string
          vendor_id?: string | null
        }
        Update: {
          advance_no?: string
          approval_id?: string | null
          approved_amount?: number | null
          beneficiary_type?: string
          created_at?: string
          expected_settlement_date?: string | null
          id?: string
          organization_id?: string
          project_reference?: string | null
          purpose?: string
          requested_amount?: number
          requested_by?: string
          staff_id?: string | null
          status?: string
          vendor_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "finance_advances_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: true
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_advances_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_advances_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_advances_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_advances_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_cost_centres: {
        Row: {
          batch_id: string | null
          branch_id: string | null
          code: string
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean
          name: string
          organization_id: string
          program_id: string | null
        }
        Insert: {
          batch_id?: string | null
          branch_id?: string | null
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
          program_id?: string | null
        }
        Update: {
          batch_id?: string | null
          branch_id?: string | null
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
          program_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "finance_cost_centres_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_cost_centres_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_cost_centres_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_cost_centres_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_cost_centres_program_id_fkey"
            columns: ["program_id"]
            isOneToOne: false
            referencedRelation: "programs"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_expense_categories: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          expense_account_id: string
          id: string
          is_active: boolean
          name: string
          organization_id: string
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          expense_account_id: string
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          expense_account_id?: string
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_expense_categories_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_expense_categories_expense_account_id_fkey"
            columns: ["expense_account_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_expense_categories_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_expense_reconciliations: {
        Row: {
          expense_id: string
          id: string
          matched_amount: number
          note: string
          reconciled_at: string
          reconciled_by: string
          statement_reference: string
        }
        Insert: {
          expense_id: string
          id?: string
          matched_amount: number
          note: string
          reconciled_at?: string
          reconciled_by: string
          statement_reference: string
        }
        Update: {
          expense_id?: string
          id?: string
          matched_amount?: number
          note?: string
          reconciled_at?: string
          reconciled_by?: string
          statement_reference?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_expense_reconciliations_expense_id_fkey"
            columns: ["expense_id"]
            isOneToOne: true
            referencedRelation: "finance_expenses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_expense_reconciliations_reconciled_by_fkey"
            columns: ["reconciled_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_expenses: {
        Row: {
          amount: number
          approval_id: string | null
          category_id: string
          created_at: string
          description: string
          expense_account_id: string
          expense_date: string
          expense_no: string
          id: string
          organization_id: string
          payable_id: string | null
          payment_account_id: string | null
          payment_mode: string
          posted_at: string | null
          posted_by: string | null
          receipt_reference: string | null
          staff_id: string | null
          status: string
          submitted_by: string
          vendor_id: string | null
        }
        Insert: {
          amount: number
          approval_id?: string | null
          category_id: string
          created_at?: string
          description: string
          expense_account_id: string
          expense_date: string
          expense_no?: string
          id?: string
          organization_id: string
          payable_id?: string | null
          payment_account_id?: string | null
          payment_mode: string
          posted_at?: string | null
          posted_by?: string | null
          receipt_reference?: string | null
          staff_id?: string | null
          status?: string
          submitted_by: string
          vendor_id?: string | null
        }
        Update: {
          amount?: number
          approval_id?: string | null
          category_id?: string
          created_at?: string
          description?: string
          expense_account_id?: string
          expense_date?: string
          expense_no?: string
          id?: string
          organization_id?: string
          payable_id?: string | null
          payment_account_id?: string | null
          payment_mode?: string
          posted_at?: string | null
          posted_by?: string | null
          receipt_reference?: string | null
          staff_id?: string | null
          status?: string
          submitted_by?: string
          vendor_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "finance_expenses_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: true
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_expenses_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "finance_expense_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_expenses_expense_account_id_fkey"
            columns: ["expense_account_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_expenses_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_expenses_payable_id_fkey"
            columns: ["payable_id"]
            isOneToOne: false
            referencedRelation: "finance_payables"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_expenses_payment_account_id_fkey"
            columns: ["payment_account_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_expenses_posted_by_fkey"
            columns: ["posted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_expenses_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_expenses_submitted_by_fkey"
            columns: ["submitted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_expenses_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_fee_revenue_map: {
        Row: {
          account_id: string
          charge_type: string
          created_at: string
          id: string
          organization_id: string
        }
        Insert: {
          account_id: string
          charge_type: string
          created_at?: string
          id?: string
          organization_id: string
        }
        Update: {
          account_id?: string
          charge_type?: string
          created_at?: string
          id?: string
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_fee_revenue_map_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_fee_revenue_map_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_payable_settlements: {
        Row: {
          advance_id: string | null
          amount: number
          external_reference: string | null
          id: string
          payable_id: string
          payment_account_id: string | null
          reason: string
          settled_at: string
          settled_by: string
        }
        Insert: {
          advance_id?: string | null
          amount: number
          external_reference?: string | null
          id?: string
          payable_id: string
          payment_account_id?: string | null
          reason: string
          settled_at?: string
          settled_by: string
        }
        Update: {
          advance_id?: string | null
          amount?: number
          external_reference?: string | null
          id?: string
          payable_id?: string
          payment_account_id?: string | null
          reason?: string
          settled_at?: string
          settled_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_payable_settlements_advance_id_fkey"
            columns: ["advance_id"]
            isOneToOne: false
            referencedRelation: "finance_advances"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_payable_settlements_payable_id_fkey"
            columns: ["payable_id"]
            isOneToOne: false
            referencedRelation: "finance_payables"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_payable_settlements_payment_account_id_fkey"
            columns: ["payment_account_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_payable_settlements_settled_by_fkey"
            columns: ["settled_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_payables: {
        Row: {
          created_at: string
          created_by: string
          due_on: string | null
          id: string
          organization_id: string
          original_amount: number
          payable_account_id: string
          payable_no: string
          payable_type: string
          referrer_id: string | null
          source_id: string
          source_type: string
          staff_id: string | null
          status: string
          vendor_id: string | null
        }
        Insert: {
          created_at?: string
          created_by: string
          due_on?: string | null
          id?: string
          organization_id: string
          original_amount: number
          payable_account_id: string
          payable_no?: string
          payable_type: string
          referrer_id?: string | null
          source_id: string
          source_type: string
          staff_id?: string | null
          status?: string
          vendor_id?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string
          due_on?: string | null
          id?: string
          organization_id?: string
          original_amount?: number
          payable_account_id?: string
          payable_no?: string
          payable_type?: string
          referrer_id?: string | null
          source_id?: string
          source_type?: string
          staff_id?: string | null
          status?: string
          vendor_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "finance_payables_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_payables_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_payables_payable_account_id_fkey"
            columns: ["payable_account_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_payables_referrer_id_fkey"
            columns: ["referrer_id"]
            isOneToOne: false
            referencedRelation: "referral_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_payables_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_payables_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["id"]
          },
        ]
      }
      finance_payment_account_map: {
        Row: {
          account_id: string
          created_at: string
          payment_method_id: string
        }
        Insert: {
          account_id: string
          created_at?: string
          payment_method_id: string
        }
        Update: {
          account_id?: string
          created_at?: string
          payment_method_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "finance_payment_account_map_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "finance_payment_account_map_payment_method_id_fkey"
            columns: ["payment_method_id"]
            isOneToOne: true
            referencedRelation: "payment_methods"
            referencedColumns: ["id"]
          },
        ]
      }
      general_ledger_journals: {
        Row: {
          created_at: string
          description: string
          id: string
          journal_date: string
          journal_no: string
          journal_type: string
          organization_id: string
          posted_at: string
          posted_by: string
          source_id: string
          source_type: string
          status: string
        }
        Insert: {
          created_at?: string
          description: string
          id?: string
          journal_date: string
          journal_no?: string
          journal_type: string
          organization_id: string
          posted_at?: string
          posted_by: string
          source_id: string
          source_type: string
          status?: string
        }
        Update: {
          created_at?: string
          description?: string
          id?: string
          journal_date?: string
          journal_no?: string
          journal_type?: string
          organization_id?: string
          posted_at?: string
          posted_by?: string
          source_id?: string
          source_type?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "general_ledger_journals_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "general_ledger_journals_posted_by_fkey"
            columns: ["posted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      general_ledger_lines: {
        Row: {
          account_id: string
          batch_id: string | null
          branch_id: string | null
          cost_centre_id: string | null
          created_at: string
          credit: number
          debit: number
          id: string
          journal_id: string
          line_no: number
          memo: string | null
          program_id: string | null
        }
        Insert: {
          account_id: string
          batch_id?: string | null
          branch_id?: string | null
          cost_centre_id?: string | null
          created_at?: string
          credit?: number
          debit?: number
          id?: string
          journal_id: string
          line_no: number
          memo?: string | null
          program_id?: string | null
        }
        Update: {
          account_id?: string
          batch_id?: string | null
          branch_id?: string | null
          cost_centre_id?: string | null
          created_at?: string
          credit?: number
          debit?: number
          id?: string
          journal_id?: string
          line_no?: number
          memo?: string | null
          program_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "general_ledger_lines_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "general_ledger_lines_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "general_ledger_lines_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "general_ledger_lines_cost_centre_id_fkey"
            columns: ["cost_centre_id"]
            isOneToOne: false
            referencedRelation: "finance_cost_centres"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "general_ledger_lines_journal_id_fkey"
            columns: ["journal_id"]
            isOneToOne: false
            referencedRelation: "general_ledger_journals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "general_ledger_lines_program_id_fkey"
            columns: ["program_id"]
            isOneToOne: false
            referencedRelation: "programs"
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
      homework_checks: {
        Row: {
          class_log_id: string
          enrollment_id: string
          feedback: string
          id: string
          recorded_at: string
          recorded_by: string
          revision: number
          status: string
          submitted_on: string | null
        }
        Insert: {
          class_log_id: string
          enrollment_id: string
          feedback?: string
          id?: string
          recorded_at?: string
          recorded_by: string
          revision: number
          status: string
          submitted_on?: string | null
        }
        Update: {
          class_log_id?: string
          enrollment_id?: string
          feedback?: string
          id?: string
          recorded_at?: string
          recorded_by?: string
          revision?: number
          status?: string
          submitted_on?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "homework_checks_class_log_id_fkey"
            columns: ["class_log_id"]
            isOneToOne: false
            referencedRelation: "class_logs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "homework_checks_enrollment_id_fkey"
            columns: ["enrollment_id"]
            isOneToOne: false
            referencedRelation: "enrollments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "homework_checks_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      invoice_credits: {
        Row: {
          amount: number
          approval_id: string
          created_at: string
          discount_id: string | null
          id: string
          invoice_id: string
          kind: string
        }
        Insert: {
          amount: number
          approval_id: string
          created_at?: string
          discount_id?: string | null
          id?: string
          invoice_id: string
          kind: string
        }
        Update: {
          amount?: number
          approval_id?: string
          created_at?: string
          discount_id?: string | null
          id?: string
          invoice_id?: string
          kind?: string
        }
        Relationships: [
          {
            foreignKeyName: "invoice_credits_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoice_credits_discount_id_fkey"
            columns: ["discount_id"]
            isOneToOne: false
            referencedRelation: "admission_discounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoice_credits_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "admission_invoices"
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
      programme_offering_public_versions: {
        Row: {
          change_reason: string
          content: Json
          created_at: string
          created_by: string
          id: string
          offering_id: string
          published_at: string | null
          published_by: string | null
          status: string
          submitted_at: string | null
          submitted_by: string | null
          version: number
        }
        Insert: {
          change_reason: string
          content: Json
          created_at?: string
          created_by: string
          id?: string
          offering_id: string
          published_at?: string | null
          published_by?: string | null
          status?: string
          submitted_at?: string | null
          submitted_by?: string | null
          version: number
        }
        Update: {
          change_reason?: string
          content?: Json
          created_at?: string
          created_by?: string
          id?: string
          offering_id?: string
          published_at?: string | null
          published_by?: string | null
          status?: string
          submitted_at?: string | null
          submitted_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "programme_offering_public_versions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "programme_offering_public_versions_offering_id_fkey"
            columns: ["offering_id"]
            isOneToOne: false
            referencedRelation: "programme_offerings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "programme_offering_public_versions_published_by_fkey"
            columns: ["published_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "programme_offering_public_versions_submitted_by_fkey"
            columns: ["submitted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      programme_offering_subjects: {
        Row: {
          offering_id: string
          sort_order: number
          subject_id: string
        }
        Insert: {
          offering_id: string
          sort_order?: number
          subject_id: string
        }
        Update: {
          offering_id?: string
          sort_order?: number
          subject_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "programme_offering_subjects_offering_id_fkey"
            columns: ["offering_id"]
            isOneToOne: false
            referencedRelation: "programme_offerings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "programme_offering_subjects_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      programme_offerings: {
        Row: {
          academic_year_id: string
          admission_policy: string | null
          admission_policy_bn: string | null
          applications_close_on: string | null
          applications_open_on: string | null
          branch_id: string
          class_id: string
          code: string
          created_at: string
          created_by: string
          group_id: string | null
          id: string
          is_accepting_applications: boolean
          is_public_showcase: boolean
          is_website_visible: boolean
          name: string
          organization_id: string
          program_id: string
          public_requirements: string | null
          public_requirements_bn: string | null
          public_schedule: string | null
          public_schedule_bn: string | null
          showcase_description: string | null
          showcase_description_bn: string | null
          showcase_eyebrow: string | null
          showcase_eyebrow_bn: string | null
          showcase_icon: string | null
          showcase_sort_order: number
          showcase_title: string | null
          showcase_title_bn: string | null
          status: Database["public"]["Enums"]["offering_status"]
          updated_at: string
        }
        Insert: {
          academic_year_id: string
          admission_policy?: string | null
          admission_policy_bn?: string | null
          applications_close_on?: string | null
          applications_open_on?: string | null
          branch_id: string
          class_id: string
          code: string
          created_at?: string
          created_by: string
          group_id?: string | null
          id?: string
          is_accepting_applications?: boolean
          is_public_showcase?: boolean
          is_website_visible?: boolean
          name: string
          organization_id: string
          program_id: string
          public_requirements?: string | null
          public_requirements_bn?: string | null
          public_schedule?: string | null
          public_schedule_bn?: string | null
          showcase_description?: string | null
          showcase_description_bn?: string | null
          showcase_eyebrow?: string | null
          showcase_eyebrow_bn?: string | null
          showcase_icon?: string | null
          showcase_sort_order?: number
          showcase_title?: string | null
          showcase_title_bn?: string | null
          status?: Database["public"]["Enums"]["offering_status"]
          updated_at?: string
        }
        Update: {
          academic_year_id?: string
          admission_policy?: string | null
          admission_policy_bn?: string | null
          applications_close_on?: string | null
          applications_open_on?: string | null
          branch_id?: string
          class_id?: string
          code?: string
          created_at?: string
          created_by?: string
          group_id?: string | null
          id?: string
          is_accepting_applications?: boolean
          is_public_showcase?: boolean
          is_website_visible?: boolean
          name?: string
          organization_id?: string
          program_id?: string
          public_requirements?: string | null
          public_requirements_bn?: string | null
          public_schedule?: string | null
          public_schedule_bn?: string | null
          showcase_description?: string | null
          showcase_description_bn?: string | null
          showcase_eyebrow?: string | null
          showcase_eyebrow_bn?: string | null
          showcase_icon?: string | null
          showcase_sort_order?: number
          showcase_title?: string | null
          showcase_title_bn?: string | null
          status?: Database["public"]["Enums"]["offering_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "programme_offerings_academic_year_id_fkey"
            columns: ["academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "programme_offerings_branch_id_fkey"
            columns: ["branch_id"]
            isOneToOne: false
            referencedRelation: "branches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "programme_offerings_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "programme_offerings_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "programme_offerings_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "academic_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "programme_offerings_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "programme_offerings_program_id_fkey"
            columns: ["program_id"]
            isOneToOne: false
            referencedRelation: "programs"
            referencedColumns: ["id"]
          },
        ]
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
          date_of_birth: string | null
          gender: string | null
          guardian_address: string | null
          guardian_name: string
          guardian_relationship_id: string | null
          guardian_relationship_snapshot: string | null
          id: string
          interested_offering_id: string | null
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
          school_roll: string | null
          source_id: string | null
          status: Database["public"]["Enums"]["prospect_status"]
          student_name: string
          student_name_bn: string | null
          submission_intent: string
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
          date_of_birth?: string | null
          gender?: string | null
          guardian_address?: string | null
          guardian_name: string
          guardian_relationship_id?: string | null
          guardian_relationship_snapshot?: string | null
          id?: string
          interested_offering_id?: string | null
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
          school_roll?: string | null
          source_id?: string | null
          status?: Database["public"]["Enums"]["prospect_status"]
          student_name: string
          student_name_bn?: string | null
          submission_intent?: string
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
          date_of_birth?: string | null
          gender?: string | null
          guardian_address?: string | null
          guardian_name?: string
          guardian_relationship_id?: string | null
          guardian_relationship_snapshot?: string | null
          id?: string
          interested_offering_id?: string | null
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
          school_roll?: string | null
          source_id?: string | null
          status?: Database["public"]["Enums"]["prospect_status"]
          student_name?: string
          student_name_bn?: string | null
          submission_intent?: string
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
            foreignKeyName: "prospects_interested_offering_id_fkey"
            columns: ["interested_offering_id"]
            isOneToOne: false
            referencedRelation: "programme_offerings"
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
      public_admission_applications: {
        Row: {
          academic_background: string | null
          fee_plan_version_id: string | null
          guardian_address: string
          id: string
          offering_id: string
          policy_acknowledged: boolean
          prospect_id: string
          published_terms_snapshot: Json
          requirements_acknowledged: boolean
          submitted_at: string
        }
        Insert: {
          academic_background?: string | null
          fee_plan_version_id?: string | null
          guardian_address: string
          id?: string
          offering_id: string
          policy_acknowledged: boolean
          prospect_id: string
          published_terms_snapshot: Json
          requirements_acknowledged: boolean
          submitted_at?: string
        }
        Update: {
          academic_background?: string | null
          fee_plan_version_id?: string | null
          guardian_address?: string
          id?: string
          offering_id?: string
          policy_acknowledged?: boolean
          prospect_id?: string
          published_terms_snapshot?: Json
          requirements_acknowledged?: boolean
          submitted_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "public_admission_applications_fee_plan_version_id_fkey"
            columns: ["fee_plan_version_id"]
            isOneToOne: false
            referencedRelation: "fee_plan_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "public_admission_applications_offering_id_fkey"
            columns: ["offering_id"]
            isOneToOne: false
            referencedRelation: "programme_offerings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "public_admission_applications_prospect_id_fkey"
            columns: ["prospect_id"]
            isOneToOne: true
            referencedRelation: "prospects"
            referencedColumns: ["id"]
          },
        ]
      }
      public_admission_corrections: {
        Row: {
          application_id: string
          id: string
          prospect_id: string
          requested_changes: string
          reviewed_at: string | null
          reviewed_by: string | null
          staff_note: string
          status: string
          submitted_at: string
          submitted_mobile: string
        }
        Insert: {
          application_id: string
          id?: string
          prospect_id: string
          requested_changes: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          staff_note?: string
          status?: string
          submitted_at?: string
          submitted_mobile: string
        }
        Update: {
          application_id?: string
          id?: string
          prospect_id?: string
          requested_changes?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          staff_note?: string
          status?: string
          submitted_at?: string
          submitted_mobile?: string
        }
        Relationships: [
          {
            foreignKeyName: "public_admission_corrections_application_id_fkey"
            columns: ["application_id"]
            isOneToOne: false
            referencedRelation: "public_admission_applications"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "public_admission_corrections_prospect_id_fkey"
            columns: ["prospect_id"]
            isOneToOne: false
            referencedRelation: "prospects"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "public_admission_corrections_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      question_bank_items: {
        Row: {
          answer_key: string
          author_id: string
          batch_id: string
          choices: Json
          created_at: string
          curriculum_version_id: string | null
          difficulty: string
          explanation: string | null
          id: string
          prompt: string
          question_type: string
          review_note: string | null
          reviewed_at: string | null
          reviewer_id: string | null
          revision: number
          root_id: string | null
          status: string
          subject_id: string
          submitted_at: string | null
          topic: string
        }
        Insert: {
          answer_key: string
          author_id: string
          batch_id: string
          choices?: Json
          created_at?: string
          curriculum_version_id?: string | null
          difficulty: string
          explanation?: string | null
          id?: string
          prompt: string
          question_type: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewer_id?: string | null
          revision?: number
          root_id?: string | null
          status?: string
          subject_id: string
          submitted_at?: string | null
          topic: string
        }
        Update: {
          answer_key?: string
          author_id?: string
          batch_id?: string
          choices?: Json
          created_at?: string
          curriculum_version_id?: string | null
          difficulty?: string
          explanation?: string | null
          id?: string
          prompt?: string
          question_type?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewer_id?: string | null
          revision?: number
          root_id?: string | null
          status?: string
          subject_id?: string
          submitted_at?: string | null
          topic?: string
        }
        Relationships: [
          {
            foreignKeyName: "question_bank_items_author_id_fkey"
            columns: ["author_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "question_bank_items_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "question_bank_items_curriculum_version_id_fkey"
            columns: ["curriculum_version_id"]
            isOneToOne: false
            referencedRelation: "curriculum_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "question_bank_items_reviewer_id_fkey"
            columns: ["reviewer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "question_bank_items_root_id_fkey"
            columns: ["root_id"]
            isOneToOne: false
            referencedRelation: "question_bank_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "question_bank_items_subject_id_fkey"
            columns: ["subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["id"]
          },
        ]
      }
      referral_bonus_awards: {
        Row: {
          admission_id: string
          amount: number
          approval_id: string
          bonus_percent: number
          created_at: string
          id: string
          net_collected: number
          payable_id: string | null
          period_start: string
          policy_version_id: string
          referrer_id: string
          requested_by: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
        }
        Insert: {
          admission_id: string
          amount: number
          approval_id: string
          bonus_percent: number
          created_at?: string
          id?: string
          net_collected: number
          payable_id?: string | null
          period_start: string
          policy_version_id: string
          referrer_id: string
          requested_by: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
        }
        Update: {
          admission_id?: string
          amount?: number
          approval_id?: string
          bonus_percent?: number
          created_at?: string
          id?: string
          net_collected?: number
          payable_id?: string | null
          period_start?: string
          policy_version_id?: string
          referrer_id?: string
          requested_by?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "referral_bonus_awards_admission_id_fkey"
            columns: ["admission_id"]
            isOneToOne: false
            referencedRelation: "admission_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_bonus_awards_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: true
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_bonus_awards_payable_id_fkey"
            columns: ["payable_id"]
            isOneToOne: true
            referencedRelation: "finance_payables"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_bonus_awards_policy_version_id_fkey"
            columns: ["policy_version_id"]
            isOneToOne: false
            referencedRelation: "business_rule_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_bonus_awards_referrer_id_fkey"
            columns: ["referrer_id"]
            isOneToOne: false
            referencedRelation: "referral_people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_bonus_awards_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_bonus_awards_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      referral_people: {
        Row: {
          contact_note: string | null
          created_at: string
          created_by: string | null
          full_name: string
          id: string
          mobile: string | null
          organization_id: string
          relationship_note: string | null
          staff_id: string | null
        }
        Insert: {
          contact_note?: string | null
          created_at?: string
          created_by?: string | null
          full_name: string
          id?: string
          mobile?: string | null
          organization_id: string
          relationship_note?: string | null
          staff_id?: string | null
        }
        Update: {
          contact_note?: string | null
          created_at?: string
          created_by?: string | null
          full_name?: string
          id?: string
          mobile?: string | null
          organization_id?: string
          relationship_note?: string | null
          staff_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "referral_people_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_people_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referral_people_staff_id_fkey"
            columns: ["staff_id"]
            isOneToOne: true
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      refund_authorizations: {
        Row: {
          amount: number
          approval_id: string
          created_at: string
          id: string
          invoice_id: string
          payment_id: string
        }
        Insert: {
          amount: number
          approval_id: string
          created_at?: string
          id?: string
          invoice_id: string
          payment_id: string
        }
        Update: {
          amount?: number
          approval_id?: string
          created_at?: string
          id?: string
          invoice_id?: string
          payment_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "refund_authorizations_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: true
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refund_authorizations_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "admission_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refund_authorizations_payment_id_fkey"
            columns: ["payment_id"]
            isOneToOne: false
            referencedRelation: "admission_payments"
            referencedColumns: ["id"]
          },
        ]
      }
      refund_payouts: {
        Row: {
          authorization_id: string
          external_reference: string | null
          id: string
          payment_method_id: string
          posted_at: string
          posted_by: string
          reason: string
          refund_no: string
        }
        Insert: {
          authorization_id: string
          external_reference?: string | null
          id?: string
          payment_method_id: string
          posted_at?: string
          posted_by: string
          reason: string
          refund_no?: string
        }
        Update: {
          authorization_id?: string
          external_reference?: string | null
          id?: string
          payment_method_id?: string
          posted_at?: string
          posted_by?: string
          reason?: string
          refund_no?: string
        }
        Relationships: [
          {
            foreignKeyName: "refund_payouts_authorization_id_fkey"
            columns: ["authorization_id"]
            isOneToOne: true
            referencedRelation: "refund_authorizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refund_payouts_payment_method_id_fkey"
            columns: ["payment_method_id"]
            isOneToOne: false
            referencedRelation: "payment_methods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refund_payouts_posted_by_fkey"
            columns: ["posted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
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
      staff_admission_intake_requests: {
        Row: {
          actor_id: string
          admission_id: string
          created_at: string
          payload: Json
          prospect_id: string
          request_id: string
        }
        Insert: {
          actor_id: string
          admission_id: string
          created_at?: string
          payload: Json
          prospect_id: string
          request_id: string
        }
        Update: {
          actor_id?: string
          admission_id?: string
          created_at?: string
          payload?: Json
          prospect_id?: string
          request_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "staff_admission_intake_requests_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_admission_intake_requests_admission_id_fkey"
            columns: ["admission_id"]
            isOneToOne: false
            referencedRelation: "admission_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "staff_admission_intake_requests_prospect_id_fkey"
            columns: ["prospect_id"]
            isOneToOne: false
            referencedRelation: "prospects"
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
      student_merges: {
        Row: {
          approval_id: string
          created_at: string
          id: string
          source_id: string
          source_snapshot: Json
          target_id: string
          target_snapshot: Json
        }
        Insert: {
          approval_id: string
          created_at?: string
          id?: string
          source_id: string
          source_snapshot: Json
          target_id: string
          target_snapshot: Json
        }
        Update: {
          approval_id?: string
          created_at?: string
          id?: string
          source_id?: string
          source_snapshot?: Json
          target_id?: string
          target_snapshot?: Json
        }
        Relationships: [
          {
            foreignKeyName: "student_merges_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: true
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_merges_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: true
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "student_merges_target_id_fkey"
            columns: ["target_id"]
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
          merged_into_id: string | null
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
          merged_into_id?: string | null
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
          merged_into_id?: string | null
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
            foreignKeyName: "students_merged_into_id_fkey"
            columns: ["merged_into_id"]
            isOneToOne: false
            referencedRelation: "students"
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
      teacher_compensation_adjustments: {
        Row: {
          adjustment_type: string
          amount: number
          approval_id: string | null
          approved_at: string | null
          approved_by: string | null
          created_at: string
          effective_period: string
          id: string
          reason: string
          requested_by: string
          status: string
          teacher_id: string
        }
        Insert: {
          adjustment_type: string
          amount: number
          approval_id?: string | null
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          effective_period: string
          id?: string
          reason: string
          requested_by: string
          status?: string
          teacher_id: string
        }
        Update: {
          adjustment_type?: string
          amount?: number
          approval_id?: string | null
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          effective_period?: string
          id?: string
          reason?: string
          requested_by?: string
          status?: string
          teacher_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "teacher_compensation_adjustments_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: true
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_adjustments_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_adjustments_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_adjustments_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      teacher_compensation_claims: {
        Row: {
          claimed_at: string
          id: string
          line_id: string
          run_id: string
          source_id: string
          source_type: string
          teacher_id: string
        }
        Insert: {
          claimed_at?: string
          id?: string
          line_id: string
          run_id: string
          source_id: string
          source_type: string
          teacher_id: string
        }
        Update: {
          claimed_at?: string
          id?: string
          line_id?: string
          run_id?: string
          source_id?: string
          source_type?: string
          teacher_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "teacher_compensation_claims_line_id_fkey"
            columns: ["line_id"]
            isOneToOne: true
            referencedRelation: "teacher_compensation_lines"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_claims_run_id_fkey"
            columns: ["run_id"]
            isOneToOne: false
            referencedRelation: "teacher_compensation_runs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_claims_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      teacher_compensation_events: {
        Row: {
          admission_id: string | null
          amount: number
          created_at: string
          event_key: string
          event_period: string
          event_type: string
          id: string
          teacher_id: string
        }
        Insert: {
          admission_id?: string | null
          amount: number
          created_at?: string
          event_key: string
          event_period: string
          event_type: string
          id?: string
          teacher_id: string
        }
        Update: {
          admission_id?: string | null
          amount?: number
          created_at?: string
          event_key?: string
          event_period?: string
          event_type?: string
          id?: string
          teacher_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "teacher_compensation_events_admission_id_fkey"
            columns: ["admission_id"]
            isOneToOne: false
            referencedRelation: "admission_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_events_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      teacher_compensation_lines: {
        Row: {
          admission_id: string | null
          amount: number
          calculation: Json
          created_at: string
          id: string
          line_type: string
          run_id: string
          source_id: string
          source_type: string
          teacher_id: string
        }
        Insert: {
          admission_id?: string | null
          amount: number
          calculation?: Json
          created_at?: string
          id?: string
          line_type: string
          run_id: string
          source_id: string
          source_type: string
          teacher_id: string
        }
        Update: {
          admission_id?: string | null
          amount?: number
          calculation?: Json
          created_at?: string
          id?: string
          line_type?: string
          run_id?: string
          source_id?: string
          source_type?: string
          teacher_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "teacher_compensation_lines_admission_id_fkey"
            columns: ["admission_id"]
            isOneToOne: false
            referencedRelation: "admission_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_lines_run_id_fkey"
            columns: ["run_id"]
            isOneToOne: false
            referencedRelation: "teacher_compensation_runs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_lines_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      teacher_compensation_runs: {
        Row: {
          approval_id: string | null
          approved_at: string | null
          approved_by: string | null
          created_at: string
          id: string
          organization_id: string
          period_end: string
          period_start: string
          policy_version_id: string
          run_no: string
          status: string
          submitted_by: string
          total_amount: number
        }
        Insert: {
          approval_id?: string | null
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          id?: string
          organization_id: string
          period_end: string
          period_start: string
          policy_version_id: string
          run_no?: string
          status?: string
          submitted_by: string
          total_amount?: number
        }
        Update: {
          approval_id?: string | null
          approved_at?: string | null
          approved_by?: string | null
          created_at?: string
          id?: string
          organization_id?: string
          period_end?: string
          period_start?: string
          policy_version_id?: string
          run_no?: string
          status?: string
          submitted_by?: string
          total_amount?: number
        }
        Relationships: [
          {
            foreignKeyName: "teacher_compensation_runs_approval_id_fkey"
            columns: ["approval_id"]
            isOneToOne: true
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_runs_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_runs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_runs_policy_version_id_fkey"
            columns: ["policy_version_id"]
            isOneToOne: false
            referencedRelation: "business_rule_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_runs_submitted_by_fkey"
            columns: ["submitted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      teacher_compensation_settlements: {
        Row: {
          advance_offset: number
          cash_paid: number
          external_reference: string | null
          gross_amount: number
          id: string
          payable_id: string
          payment_account_id: string | null
          reason: string
          run_id: string
          settled_at: string
          settled_by: string
          teacher_id: string
        }
        Insert: {
          advance_offset?: number
          cash_paid?: number
          external_reference?: string | null
          gross_amount: number
          id?: string
          payable_id: string
          payment_account_id?: string | null
          reason: string
          run_id: string
          settled_at?: string
          settled_by: string
          teacher_id: string
        }
        Update: {
          advance_offset?: number
          cash_paid?: number
          external_reference?: string | null
          gross_amount?: number
          id?: string
          payable_id?: string
          payment_account_id?: string | null
          reason?: string
          run_id?: string
          settled_at?: string
          settled_by?: string
          teacher_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "teacher_compensation_settlements_payable_id_fkey"
            columns: ["payable_id"]
            isOneToOne: true
            referencedRelation: "finance_payables"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_settlements_payment_account_id_fkey"
            columns: ["payment_account_id"]
            isOneToOne: false
            referencedRelation: "finance_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_settlements_run_id_fkey"
            columns: ["run_id"]
            isOneToOne: false
            referencedRelation: "teacher_compensation_runs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_settlements_settled_by_fkey"
            columns: ["settled_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_compensation_settlements_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
      }
      teacher_referrals: {
        Row: {
          admission_id: string
          captured_at: string
          captured_by: string
          id: string
          reason: string
          teacher_id: string
        }
        Insert: {
          admission_id: string
          captured_at?: string
          captured_by: string
          id?: string
          reason: string
          teacher_id: string
        }
        Update: {
          admission_id?: string
          captured_at?: string
          captured_by?: string
          id?: string
          reason?: string
          teacher_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "teacher_referrals_admission_id_fkey"
            columns: ["admission_id"]
            isOneToOne: true
            referencedRelation: "admission_cases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_referrals_captured_by_fkey"
            columns: ["captured_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_referrals_teacher_id_fkey"
            columns: ["teacher_id"]
            isOneToOne: false
            referencedRelation: "staff"
            referencedColumns: ["id"]
          },
        ]
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
      vendors: {
        Row: {
          address: string | null
          created_at: string
          created_by: string | null
          email: string | null
          id: string
          is_active: boolean
          mobile: string | null
          name: string
          organization_id: string
          service_category: string | null
          updated_at: string
          vendor_no: string
        }
        Insert: {
          address?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          id?: string
          is_active?: boolean
          mobile?: string | null
          name: string
          organization_id: string
          service_category?: string | null
          updated_at?: string
          vendor_no?: string
        }
        Update: {
          address?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          id?: string
          is_active?: boolean
          mobile?: string | null
          name?: string
          organization_id?: string
          service_category?: string | null
          updated_at?: string
          vendor_no?: string
        }
        Relationships: [
          {
            foreignKeyName: "vendors_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vendors_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      academic_command: { Args: { p_input: Json }; Returns: Json }
      academic_workspace: {
        Args: { p_from: string; p_to: string }
        Returns: Json
      }
      admission_command: { Args: { p_input: Json }; Returns: Json }
      admission_payment_satisfied: {
        Args: { p_admission_id: string }
        Returns: boolean
      }
      admission_workspace: { Args: never; Returns: Json }
      advance_balance: { Args: { p_advance_id: string }; Returns: number }
      advance_paid: { Args: { p_advance_id: string }; Returns: number }
      apply_invoice_discounts: {
        Args: { p_invoice_id: string }
        Returns: undefined
      }
      assessment_command: { Args: { p_input: Json }; Returns: Json }
      assessment_workspace: { Args: never; Returns: Json }
      batch_command: { Args: { p_input: Json }; Returns: Json }
      billing_preview: {
        Args: { p_period: string; p_term_id?: string }
        Returns: Json
      }
      bootstrap_admin: {
        Args: { p_email: string; p_full_name?: string }
        Returns: Json
      }
      can_access_assessment: {
        Args: { p_batch: string; p_subject: string }
        Returns: boolean
      }
      can_access_class_session: {
        Args: { p_session: string }
        Returns: boolean
      }
      class_log_command: { Args: { p_input: Json }; Returns: Json }
      class_log_workspace: { Args: { p_session_id: string }; Returns: Json }
      class_session_workspace: { Args: { p_session_id: string }; Returns: Json }
      create_programme_offering: { Args: { p_input: Json }; Returns: Json }
      create_programme_offering_public_version: {
        Args: { p_input: Json }
        Returns: Json
      }
      create_staff_admission_intake: { Args: { p_input: Json }; Returns: Json }
      create_staff_member: { Args: { p_input: Json }; Returns: Json }
      finance_account_balance: {
        Args: { p_account_id: string; p_as_of?: string }
        Returns: number
      }
      finance_accounting_command: { Args: { p_input: Json }; Returns: Json }
      finance_command: { Args: { p_input: Json }; Returns: Json }
      finance_net_collected_tuition: {
        Args: { p_from: string; p_to: string }
        Returns: {
          admission_id: string
          batch_id: string
          billing_period: string
          tuition_collected: number
        }[]
      }
      finance_post_journal: {
        Args: {
          p_description: string
          p_journal_date: string
          p_journal_type: string
          p_lines: Json
          p_organization_id: string
          p_posted_by: string
          p_source_id: string
          p_source_type: string
        }
        Returns: string
      }
      finance_read_account_balance: {
        Args: { p_account_id: string; p_as_of?: string }
        Returns: number
      }
      finance_sync_invoice: { Args: { p_invoice_id: string }; Returns: string }
      finance_sync_invoice_credit: {
        Args: { p_credit_id: string }
        Returns: string
      }
      finance_sync_payment: { Args: { p_payment_id: string }; Returns: string }
      finance_sync_refund: { Args: { p_payout_id: string }; Returns: string }
      finance_workspace: { Args: never; Returns: Json }
      generate_prospect_no: { Args: never; Returns: string }
      generate_staff_no: { Args: never; Returns: string }
      generate_student_no: { Args: never; Returns: string }
      has_permission: { Args: { p_permission_code: string }; Returns: boolean }
      homework_command: { Args: { p_input: Json }; Returns: Json }
      homework_workspace: { Args: { p_session_id: string }; Returns: Json }
      invoice_balance: {
        Args: { p_invoice_id: string }
        Returns: {
          credit_balance: number
          credits: number
          due: number
          gross: number
          net: number
          paid: number
          refunded: number
          reserved_refunds: number
        }[]
      }
      is_valid_prospect_transition: {
        Args: {
          p_from: Database["public"]["Enums"]["prospect_status"]
          p_to: Database["public"]["Enums"]["prospect_status"]
        }
        Returns: boolean
      }
      link_staff_profile_by_email: {
        Args: { p_email: string }
        Returns: string
      }
      list_public_programme_offerings: { Args: never; Returns: Json }
      list_public_programme_showcase: { Args: never; Returns: Json }
      manage_crm_master_record: { Args: { p_input: Json }; Returns: Json }
      my_erp_context: { Args: never; Returns: Json }
      post_admission_payment: { Args: { p_input: Json }; Returns: Json }
      publish_business_rule_version: {
        Args: {
          p_domain: string
          p_payload: Json
          p_reason: string
          p_rule_key: string
        }
        Returns: Json
      }
      publish_fee_plan: { Args: { p_input: Json }; Returns: Json }
      publish_programme_offering_public_version: {
        Args: { p_input: Json }
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
      question_bank_command: { Args: { p_input: Json }; Returns: Json }
      question_bank_workspace: { Args: never; Returns: Json }
      record_admission_consent: { Args: { p_input: Json }; Returns: Json }
      record_physical_admission_consent: {
        Args: { p_input: Json }
        Returns: Json
      }
      record_prospect_followup: { Args: { p_input: Json }; Returns: Json }
      referral_command: { Args: { p_input: Json }; Returns: Json }
      review_admission_requirement: { Args: { p_input: Json }; Returns: Json }
      review_applicant_correction: { Args: { p_input: Json }; Returns: Json }
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
      student_command: { Args: { p_input: Json }; Returns: Json }
      student_profile_workspace: {
        Args: { p_student_id: string }
        Returns: Json
      }
      submit_applicant_correction: { Args: { p_payload: Json }; Returns: Json }
      submit_programme_offering_public_version: {
        Args: { p_input: Json }
        Returns: Json
      }
      submit_public_interest: { Args: { p_payload: Json }; Returns: Json }
      teacher_compensation_preview: {
        Args: { p_from: string; p_to: string }
        Returns: Json
      }
      update_programme_offering: { Args: { p_input: Json }; Returns: Json }
      update_programme_offering_public_controls: {
        Args: { p_input: Json }
        Returns: Json
      }
      update_programme_offering_showcase: {
        Args: { p_input: Json }
        Returns: Json
      }
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
      offering_status: "DRAFT" | "ACTIVE" | "RETIRED"
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
      offering_status: ["DRAFT", "ACTIVE", "RETIRED"],
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
