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
    PostgrestVersion: "14.17"
  }
  public: {
    Tables: {
      access_code_attempts: {
        Row: {
          attempted_at: string
          code_id: string | null
          id: number
          ip_hash: string
          outcome: string
        }
        Insert: {
          attempted_at?: string
          code_id?: string | null
          id?: never
          ip_hash: string
          outcome: string
        }
        Update: {
          attempted_at?: string
          code_id?: string | null
          id?: never
          ip_hash?: string
          outcome?: string
        }
        Relationships: [
          {
            foreignKeyName: "access_code_attempts_code_id_fkey"
            columns: ["code_id"]
            isOneToOne: false
            referencedRelation: "access_codes"
            referencedColumns: ["id"]
          },
        ]
      }
      access_code_events: {
        Row: {
          actor: string
          code_id: string | null
          code_prefix: string | null
          created_at: string
          detail: string | null
          event: string
          id: number
          ip_hash: string | null
        }
        Insert: {
          actor: string
          code_id?: string | null
          code_prefix?: string | null
          created_at?: string
          detail?: string | null
          event: string
          id?: never
          ip_hash?: string | null
        }
        Update: {
          actor?: string
          code_id?: string | null
          code_prefix?: string | null
          created_at?: string
          detail?: string | null
          event?: string
          id?: never
          ip_hash?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "access_code_events_code_id_fkey"
            columns: ["code_id"]
            isOneToOne: false
            referencedRelation: "access_codes"
            referencedColumns: ["id"]
          },
        ]
      }
      access_codes: {
        Row: {
          code_hash: string
          code_prefix: string
          created_at: string
          created_by: string
          expires_at: string
          failed_attempts: number
          id: string
          note: string
          redeemed_at: string | null
          revoked_at: string | null
          ticket_expires_at: string | null
          ticket_hash: string | null
          used_at: string | null
          used_by: string | null
        }
        Insert: {
          code_hash: string
          code_prefix: string
          created_at?: string
          created_by: string
          expires_at: string
          failed_attempts?: number
          id?: string
          note?: string
          redeemed_at?: string | null
          revoked_at?: string | null
          ticket_expires_at?: string | null
          ticket_hash?: string | null
          used_at?: string | null
          used_by?: string | null
        }
        Update: {
          code_hash?: string
          code_prefix?: string
          created_at?: string
          created_by?: string
          expires_at?: string
          failed_attempts?: number
          id?: string
          note?: string
          redeemed_at?: string | null
          revoked_at?: string | null
          ticket_expires_at?: string | null
          ticket_hash?: string | null
          used_at?: string | null
          used_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "access_codes_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "access_codes_used_by_fkey"
            columns: ["used_by"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      app_accounts: {
        Row: {
          approved_at: string | null
          assigned_program_id: string | null
          auth_user_id: string
          created_at: string
          id: string
          is_preview: boolean
          name: string
          onboarding_completed_at: string | null
          onboarding_step: number
          role: string
          updated_at: string
          username: string
        }
        Insert: {
          approved_at?: string | null
          assigned_program_id?: string | null
          auth_user_id: string
          created_at?: string
          id?: string
          is_preview?: boolean
          name: string
          onboarding_completed_at?: string | null
          onboarding_step?: number
          role: string
          updated_at?: string
          username: string
        }
        Update: {
          approved_at?: string | null
          assigned_program_id?: string | null
          auth_user_id?: string
          created_at?: string
          id?: string
          is_preview?: boolean
          name?: string
          onboarding_completed_at?: string | null
          onboarding_step?: number
          role?: string
          updated_at?: string
          username?: string
        }
        Relationships: []
      }
      app_state: {
        Row: {
          exercises: Json
          id: string
          programs: Json
          updated_at: string
          weight_units: Json
          workouts: Json
        }
        Insert: {
          exercises?: Json
          id?: string
          programs?: Json
          updated_at?: string
          weight_units?: Json
          workouts?: Json
        }
        Update: {
          exercises?: Json
          id?: string
          programs?: Json
          updated_at?: string
          weight_units?: Json
          workouts?: Json
        }
        Relationships: []
      }
      chat_messages: {
        Row: {
          body: string
          created_at: string
          id: string
          sender_account_id: string
          thread_id: string
        }
        Insert: {
          body: string
          created_at?: string
          id: string
          sender_account_id: string
          thread_id: string
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          sender_account_id?: string
          thread_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "chat_messages_sender_account_id_fkey"
            columns: ["sender_account_id"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_messages_thread_id_fkey"
            columns: ["thread_id"]
            isOneToOne: false
            referencedRelation: "chat_threads"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_reads: {
        Row: {
          account_id: string
          last_read_at: string
          thread_id: string
          updated_at: string
        }
        Insert: {
          account_id: string
          last_read_at?: string
          thread_id: string
          updated_at?: string
        }
        Update: {
          account_id?: string
          last_read_at?: string
          thread_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "chat_reads_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_reads_thread_id_fkey"
            columns: ["thread_id"]
            isOneToOne: false
            referencedRelation: "chat_threads"
            referencedColumns: ["id"]
          },
        ]
      }
      chat_threads: {
        Row: {
          client_id: string
          coach_id: string
          created_at: string
          id: string
          last_message_at: string | null
          last_message_body: string | null
          last_message_sender_id: string | null
          updated_at: string
        }
        Insert: {
          client_id: string
          coach_id: string
          created_at?: string
          id?: string
          last_message_at?: string | null
          last_message_body?: string | null
          last_message_sender_id?: string | null
          updated_at?: string
        }
        Update: {
          client_id?: string
          coach_id?: string
          created_at?: string
          id?: string
          last_message_at?: string | null
          last_message_body?: string | null
          last_message_sender_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "chat_threads_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: true
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_threads_coach_id_fkey"
            columns: ["coach_id"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "chat_threads_last_message_sender_id_fkey"
            columns: ["last_message_sender_id"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      client_program_bundles: {
        Row: {
          bundle: Json
          client_id: string
          published_by: string
          updated_at: string
        }
        Insert: {
          bundle: Json
          client_id: string
          published_by: string
          updated_at?: string
        }
        Update: {
          bundle?: Json
          client_id?: string
          published_by?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "client_program_bundles_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: true
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "client_program_bundles_published_by_fkey"
            columns: ["published_by"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      paused_workouts: {
        Row: {
          client_id: string
          elapsed_seconds: number
          has_working_progress: boolean
          id: string
          paused_at: string
          program_id: string | null
          results: Json
          workout_id: string
          workout_name: string
        }
        Insert: {
          client_id: string
          elapsed_seconds?: number
          has_working_progress?: boolean
          id?: string
          paused_at?: string
          program_id?: string | null
          results?: Json
          workout_id: string
          workout_name: string
        }
        Update: {
          client_id?: string
          elapsed_seconds?: number
          has_working_progress?: boolean
          id?: string
          paused_at?: string
          program_id?: string | null
          results?: Json
          workout_id?: string
          workout_name?: string
        }
        Relationships: [
          {
            foreignKeyName: "paused_workouts_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_settings: {
        Row: {
          card_url: string
          id: number
          paypal_url: string
          updated_at: string
        }
        Insert: {
          card_url?: string
          id?: number
          paypal_url?: string
          updated_at?: string
        }
        Update: {
          card_url?: string
          id?: number
          paypal_url?: string
          updated_at?: string
        }
        Relationships: []
      }
      payment_started: {
        Row: {
          client_id: string
          client_name: string
          client_username: string
          id: string
          method: string
          started_at: string
        }
        Insert: {
          client_id: string
          client_name: string
          client_username: string
          id?: string
          method: string
          started_at?: string
        }
        Update: {
          client_id?: string
          client_name?: string
          client_username?: string
          id?: string
          method?: string
          started_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_started_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          amount_usd: number
          client_id: string
          client_name: string
          client_username: string
          id: string
          note: string | null
          recorded_at: string
          recorded_by: string
          tag: string
        }
        Insert: {
          amount_usd?: number
          client_id: string
          client_name: string
          client_username: string
          id?: string
          note?: string | null
          recorded_at?: string
          recorded_by: string
          tag: string
        }
        Update: {
          amount_usd?: number
          client_id?: string
          client_name?: string
          client_username?: string
          id?: string
          note?: string | null
          recorded_at?: string
          recorded_by?: string
          tag?: string
        }
        Relationships: [
          {
            foreignKeyName: "payments_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      payouts: {
        Row: {
          amount_usd: number
          decided_at: string | null
          decided_by_coach_id: string | null
          id: string
          note: string | null
          rejection_reason: string | null
          screenshot_id: string | null
          status: string
          submitted_at: string
          submitted_by: string
        }
        Insert: {
          amount_usd: number
          decided_at?: string | null
          decided_by_coach_id?: string | null
          id?: string
          note?: string | null
          rejection_reason?: string | null
          screenshot_id?: string | null
          status?: string
          submitted_at?: string
          submitted_by: string
        }
        Update: {
          amount_usd?: number
          decided_at?: string | null
          decided_by_coach_id?: string | null
          id?: string
          note?: string | null
          rejection_reason?: string | null
          screenshot_id?: string | null
          status?: string
          submitted_at?: string
          submitted_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "payouts_decided_by_coach_id_fkey"
            columns: ["decided_by_coach_id"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payouts_submitted_by_fkey"
            columns: ["submitted_by"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
      progress_picture_batches: {
        Row: {
          capture_date: string
          client_id: string
          created_at: string
          id: string
          preview_picture_id: string | null
          timezone: string
          updated_at: string
        }
        Insert: {
          capture_date: string
          client_id: string
          created_at?: string
          id: string
          preview_picture_id?: string | null
          timezone: string
          updated_at?: string
        }
        Update: {
          capture_date?: string
          client_id?: string
          created_at?: string
          id?: string
          preview_picture_id?: string | null
          timezone?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "progress_picture_batches_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "progress_picture_batches_preview_picture_fkey"
            columns: ["preview_picture_id"]
            isOneToOne: false
            referencedRelation: "progress_pictures"
            referencedColumns: ["id"]
          },
        ]
      }
      progress_pictures: {
        Row: {
          batch_id: string
          byte_size: number
          created_at: string
          display_order: number
          height: number
          id: string
          mime_type: string
          storage_path: string
          width: number
        }
        Insert: {
          batch_id: string
          byte_size: number
          created_at?: string
          display_order: number
          height: number
          id: string
          mime_type?: string
          storage_path: string
          width: number
        }
        Update: {
          batch_id?: string
          byte_size?: number
          created_at?: string
          display_order?: number
          height?: number
          id?: string
          mime_type?: string
          storage_path?: string
          width?: number
        }
        Relationships: [
          {
            foreignKeyName: "progress_pictures_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "progress_picture_batches"
            referencedColumns: ["id"]
          },
        ]
      }
      workout_sessions: {
        Row: {
          client_id: string
          completed_at: string
          completed_sets: number
          created_at: string
          duration_seconds: number
          id: string
          program_id: string | null
          session_data: Json
          started_at: string
          total_reps: number
          total_sets: number
          volume_by_unit: Json
          workout_id: string
          workout_name: string
        }
        Insert: {
          client_id: string
          completed_at?: string
          completed_sets: number
          created_at?: string
          duration_seconds: number
          id?: string
          program_id?: string | null
          session_data: Json
          started_at: string
          total_reps: number
          total_sets: number
          volume_by_unit?: Json
          workout_id: string
          workout_name: string
        }
        Update: {
          client_id?: string
          completed_at?: string
          completed_sets?: number
          created_at?: string
          duration_seconds?: number
          id?: string
          program_id?: string | null
          session_data?: Json
          started_at?: string
          total_reps?: number
          total_sets?: number
          volume_by_unit?: Json
          workout_id?: string
          workout_name?: string
        }
        Relationships: [
          {
            foreignKeyName: "workout_sessions_client_id_fkey"
            columns: ["client_id"]
            isOneToOne: false
            referencedRelation: "app_accounts"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      advance_client_onboarding: {
        Args: { p_answer: string; p_client_id: string }
        Returns: {
          onboarding_completed_at: string
          onboarding_step: number
          thread_id: string
        }[]
      }
      append_onboarding_greeting: {
        Args: { p_client_id: string }
        Returns: undefined
      }
      append_onboarding_messages: {
        Args: { p_client: string; p_messages: Json }
        Returns: undefined
      }
      append_progress_pictures_to_batch: {
        Args: { p_batch_id: string; p_client_id: string; p_pictures: Json }
        Returns: string
      }
      approve_client: { Args: { p_client_id: string }; Returns: undefined }
      can_access_chat_thread: {
        Args: { p_thread_id: string }
        Returns: boolean
      }
      can_read_client_account: {
        Args: { p_client_id: string }
        Returns: boolean
      }
      can_write_chat: {
        Args: { sender_account_id: string; thread_id: string }
        Returns: boolean
      }
      complete_client_onboarding: {
        Args: { p_client_id: string }
        Returns: string
      }
      create_progress_picture_batch: {
        Args: {
          p_batch_id: string
          p_capture_date: string
          p_client_id: string
          p_pictures: Json
          p_preview_picture_id: string
          p_timezone: string
        }
        Returns: string
      }
      current_account_id: { Args: never; Returns: string }
      decide_payout: {
        Args: {
          p_coach_id: string
          p_decision: string
          p_payout_id: string
          p_reason: string
        }
        Returns: undefined
      }
      get_chat_unread_counts: {
        Args: { p_account_id: string }
        Returns: {
          client_id: string
          unread_messages: number
        }[]
      }
      get_client_program_bundle: { Args: never; Returns: Json }
      get_coach_profile: {
        Args: never
        Returns: {
          assigned_program_id: string
          created_at: string
          id: string
          is_preview: boolean
          name: string
          role: string
          username: string
        }[]
      }
      get_or_create_chat_thread: {
        Args: { p_client_id: string }
        Returns: string
      }
      initialize_client_onboarding: {
        Args: { p_client_id: string }
        Returns: {
          onboarding_completed_at: string
          onboarding_step: number
          thread_id: string
        }[]
      }
      is_app_coach: { Args: never; Returns: boolean }
      is_chat_participant: { Args: { thread_id: string }; Returns: boolean }
      is_coach: { Args: never; Returns: boolean }
      is_payment_manager: { Args: never; Returns: boolean }
      is_progress_picture_storage_path: {
        Args: { object_name: string }
        Returns: boolean
      }
      mark_chat_read: {
        Args: { p_account_id: string; p_client_id: string }
        Returns: undefined
      }
      owns_app_account: { Args: { p_account_id: string }; Returns: boolean }
      publish_client_program: {
        Args: { p_client_id: string }
        Returns: undefined
      }
      record_payment_and_unlock: {
        Args: {
          p_amount_usd: number
          p_client_username: string
          p_note: string
          p_recorded_by: string
        }
        Returns: string
      }
      record_payment_started: {
        Args: { p_client_id: string; p_method: string }
        Returns: undefined
      }
      send_chat_message: {
        Args: {
          p_body: string
          p_client_id: string
          p_message_id: string
          p_sender_account_id: string
        }
        Returns: string
      }
      set_progress_picture_preview: {
        Args: { p_batch_id: string; p_client_id: string; p_picture_id: string }
        Returns: undefined
      }
      submit_payout: {
        Args: {
          p_amount_usd: number
          p_note: string
          p_screenshot_id: string
          p_submitted_by: string
        }
        Returns: string
      }
      unread_counts: {
        Args: { p_account_id: string }
        Returns: {
          client_id: string
          thread_id: string
          unread: number
        }[]
      }
      upsert_payment_settings: {
        Args: { p_card_url: string; p_paypal_url: string }
        Returns: undefined
      }
    }
    Enums: {
      [_ in never]: never
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
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
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
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
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
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
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
