-- Persisted, option-only Client onboarding inside the existing Coach chat.
-- Every Client account, including the Coach-owned preview Client, completes this once.

-- The fresh-Cloud migration tool omitted chat_reads from Realtime in one generated
-- migration copy. Repair that safely whether or not the canonical migration added it.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'chat_reads'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_reads';
  END IF;
END;
$$;

ALTER TABLE public.app_accounts
  ADD COLUMN onboarding_step smallint NOT NULL DEFAULT 0,
  ADD COLUMN onboarding_completed_at timestamptz;

ALTER TABLE public.app_accounts
  ADD CONSTRAINT app_accounts_onboarding_step_check CHECK (
    onboarding_step BETWEEN 0 AND 5
  ),
  ADD CONSTRAINT app_accounts_onboarding_completion_check CHECK (
    onboarding_completed_at IS NULL OR onboarding_step = 5
  );

CREATE OR REPLACE FUNCTION public.initialize_client_onboarding(p_client_id uuid)
RETURNS TABLE (
  thread_id uuid,
  onboarding_step smallint,
  onboarding_completed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
#variable_conflict use_column
DECLARE
  client_name text;
  current_step smallint;
  completed_at timestamptz;
  target_thread_id uuid;
  coach_account_id uuid;
  message_time timestamptz;
BEGIN
  IF NOT public.owns_app_account(p_client_id) THEN
    RAISE EXCEPTION 'You cannot initialize onboarding for this Client account';
  END IF;

  SELECT account.name, account.onboarding_step, account.onboarding_completed_at
  INTO client_name, current_step, completed_at
  FROM public.app_accounts account
  WHERE account.id = p_client_id
    AND account.role = 'client'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Client account was not found';
  END IF;

  target_thread_id := public.get_or_create_chat_thread(p_client_id);

  IF current_step = 0 AND completed_at IS NULL THEN
    SELECT conversation.coach_id
    INTO coach_account_id
    FROM public.chat_threads conversation
    WHERE conversation.id = target_thread_id;

    IF coach_account_id IS NULL THEN
      RAISE EXCEPTION 'Coach account was not found';
    END IF;

    message_time := clock_timestamp();
    INSERT INTO public.chat_messages (
      id, thread_id, sender_account_id, body, created_at
    ) VALUES
      (
        gen_random_uuid(),
        target_thread_id,
        coach_account_id,
        format('Welcome to No More Copium, %s.', client_name),
        message_time
      ),
      (
        gen_random_uuid(),
        target_thread_id,
        coach_account_id,
        'How many times a week do you usually train?',
        message_time + interval '1 millisecond'
      );

    UPDATE public.app_accounts
    SET onboarding_step = 1
    WHERE id = p_client_id;
    current_step := 1;
  END IF;

  RETURN QUERY SELECT target_thread_id, current_step, completed_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.advance_client_onboarding(
  p_client_id uuid,
  p_answer text
)
RETURNS TABLE (
  thread_id uuid,
  onboarding_step smallint,
  onboarding_completed_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
#variable_conflict use_column
DECLARE
  current_step smallint;
  completed_at timestamptz;
  normalized_answer text;
  next_message text;
  next_step smallint;
  target_thread_id uuid;
  coach_account_id uuid;
  message_time timestamptz;
BEGIN
  IF NOT public.owns_app_account(p_client_id) THEN
    RAISE EXCEPTION 'You cannot answer onboarding for this Client account';
  END IF;

  SELECT account.onboarding_step, account.onboarding_completed_at
  INTO current_step, completed_at
  FROM public.app_accounts account
  WHERE account.id = p_client_id
    AND account.role = 'client'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Client account was not found';
  END IF;
  IF completed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Onboarding is already complete';
  END IF;
  IF current_step NOT BETWEEN 1 AND 4 THEN
    RAISE EXCEPTION 'This onboarding answer is not currently expected';
  END IF;

  normalized_answer := btrim(COALESCE(p_answer, ''));
  CASE current_step
    WHEN 1 THEN
      IF normalized_answer NOT IN (
        '0–2 times a week',
        '3–4 times a week',
        '5–6 times a week'
      ) THEN
        RAISE EXCEPTION 'Choose one of the available training-frequency options';
      END IF;
      next_message := 'Do you work out at the gym or at home with no equipment?';
    WHEN 2 THEN
      IF normalized_answer NOT IN ('Gym', 'Home') THEN
        RAISE EXCEPTION 'Choose Gym or Home';
      END IF;
      next_message := 'How long is your usual workout?';
    WHEN 3 THEN
      IF normalized_answer NOT IN (
        'Below 30 minutes',
        'Around one hour',
        '1.5–2 hours'
      ) THEN
        RAISE EXCEPTION 'Choose one of the available workout-duration options';
      END IF;
      next_message := 'How is your exercise technique/form?';
    WHEN 4 THEN
      IF normalized_answer NOT IN (
        'Beginner / not the best',
        'Experienced / correct form and technique'
      ) THEN
        RAISE EXCEPTION 'Choose one of the available technique options';
      END IF;
      next_message := E'placeholder\nplaceholder';
  END CASE;

  target_thread_id := public.get_or_create_chat_thread(p_client_id);
  SELECT conversation.coach_id
  INTO coach_account_id
  FROM public.chat_threads conversation
  WHERE conversation.id = target_thread_id;
  IF coach_account_id IS NULL THEN
    RAISE EXCEPTION 'Coach account was not found';
  END IF;

  message_time := clock_timestamp();
  INSERT INTO public.chat_messages (
    id, thread_id, sender_account_id, body, created_at
  ) VALUES
    (
      gen_random_uuid(),
      target_thread_id,
      p_client_id,
      normalized_answer,
      message_time
    ),
    (
      gen_random_uuid(),
      target_thread_id,
      coach_account_id,
      next_message,
      message_time + interval '1 millisecond'
    );

  next_step := current_step + 1;
  UPDATE public.app_accounts
  SET onboarding_step = next_step
  WHERE id = p_client_id;

  RETURN QUERY SELECT target_thread_id, next_step, completed_at;
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_client_onboarding(p_client_id uuid)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  completed_at timestamptz;
BEGIN
  IF NOT public.owns_app_account(p_client_id) THEN
    RAISE EXCEPTION 'You cannot complete onboarding for this Client account';
  END IF;

  UPDATE public.app_accounts
  SET onboarding_completed_at = COALESCE(onboarding_completed_at, now())
  WHERE id = p_client_id
    AND role = 'client'
    AND onboarding_step = 5
  RETURNING onboarding_completed_at INTO completed_at;

  IF completed_at IS NULL THEN
    RAISE EXCEPTION 'Answer every onboarding question before entering the app';
  END IF;
  RETURN completed_at;
END;
$$;

-- Free-form Client chat remains unavailable until the option-only onboarding is complete.
CREATE OR REPLACE FUNCTION public.send_chat_message(
  p_message_id uuid,
  p_sender_account_id uuid,
  p_client_id uuid,
  p_body text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_thread_id uuid;
BEGIN
  IF NOT public.owns_app_account(p_sender_account_id) THEN
    RAISE EXCEPTION 'You cannot send messages as this account';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.app_accounts sender
    WHERE sender.id = p_sender_account_id
      AND sender.role = 'client'
      AND sender.onboarding_completed_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Complete onboarding before sending free-form messages';
  END IF;
  IF p_body IS NULL OR char_length(btrim(p_body)) NOT BETWEEN 1 AND 2000 THEN
    RAISE EXCEPTION 'Message must be between 1 and 2000 characters';
  END IF;

  target_thread_id := public.get_or_create_chat_thread(p_client_id);
  IF NOT EXISTS (
    SELECT 1 FROM public.chat_threads
    WHERE id = target_thread_id
      AND p_sender_account_id IN (client_id, coach_id)
  ) THEN
    RAISE EXCEPTION 'Message sender is not a participant in this chat';
  END IF;

  INSERT INTO public.chat_messages (id, thread_id, sender_account_id, body)
  VALUES (p_message_id, target_thread_id, p_sender_account_id, btrim(p_body))
  ON CONFLICT (id) DO NOTHING;

  IF NOT EXISTS (
    SELECT 1 FROM public.chat_messages existing_message
    WHERE existing_message.id = p_message_id
      AND existing_message.thread_id = target_thread_id
      AND existing_message.sender_account_id = p_sender_account_id
      AND existing_message.body = btrim(p_body)
  ) THEN
    RAISE EXCEPTION 'Message ID conflicts with another message';
  END IF;

  RETURN p_message_id;
END;
$$;

REVOKE ALL ON FUNCTION public.initialize_client_onboarding(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.advance_client_onboarding(uuid, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_client_onboarding(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.send_chat_message(uuid, uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.initialize_client_onboarding(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.advance_client_onboarding(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_client_onboarding(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_chat_message(uuid, uuid, uuid, text) TO authenticated;

-- No More Copium — Cloud reactivation prep
-- 1) Username rules: A–Z, a–z, 0–9, underscore only (case preserved), 3–30 chars.
-- 2) New tables for the payment system and paused workouts (mirrors the local models).

-- ---------------------------------------------------------------
-- 1. Username rules
-- ---------------------------------------------------------------
ALTER TABLE public.app_accounts
  DROP CONSTRAINT IF EXISTS app_accounts_username_check;

ALTER TABLE public.app_accounts
  ADD CONSTRAINT app_accounts_username_check CHECK (
    char_length(username) BETWEEN 3 AND 30
    AND username ~ '^[A-Za-z0-9_]+$'
  );

-- Case-insensitive uniqueness: "John" and "john" collide.
DROP INDEX IF EXISTS app_accounts_username_lower_unique;
CREATE UNIQUE INDEX app_accounts_username_lower_unique
  ON public.app_accounts (lower(username))
  WHERE is_preview = false;

-- ---------------------------------------------------------------
-- 2. Payment system tables
-- ---------------------------------------------------------------

-- Every confirmed client payment. Unlock is idempotent on this row.
CREATE TABLE IF NOT EXISTS public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.app_accounts(id) ON DELETE CASCADE,
  client_username text NOT NULL,
  client_name text NOT NULL,
  amount_usd numeric(10,2) NOT NULL DEFAULT 29 CHECK (amount_usd > 0),
  tag text NOT NULL CHECK (tag IN ('new_user', 'membership')),
  note text,
  recorded_by uuid NOT NULL REFERENCES public.app_accounts(id),
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payments_client_idx ON public.payments (client_id);
CREATE INDEX IF NOT EXISTS payments_recorded_at_idx ON public.payments (recorded_at DESC);

-- Payouts submitted by the US Payment Manager, decided by the coach.
CREATE TABLE IF NOT EXISTS public.payouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  amount_usd numeric(10,2) NOT NULL CHECK (amount_usd > 0),
  screenshot_id text,
  note text,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  submitted_by uuid NOT NULL REFERENCES public.app_accounts(id),
  submitted_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  decided_by_coach_id uuid REFERENCES public.app_accounts(id),
  rejection_reason text
);

CREATE INDEX IF NOT EXISTS payouts_status_idx ON public.payouts (status);
CREATE INDEX IF NOT EXISTS payouts_submitted_at_idx ON public.payouts (submitted_at DESC);

-- "Payment started" claims from the onboarding payment box.
CREATE TABLE IF NOT EXISTS public.payment_started (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.app_accounts(id) ON DELETE CASCADE,
  client_username text NOT NULL,
  client_name text NOT NULL,
  method text NOT NULL CHECK (method IN ('card', 'paypal')),
  started_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payment_started_client_idx ON public.payment_started (client_id);

-- Coach-editable payment links (single row).
CREATE TABLE IF NOT EXISTS public.payment_settings (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  card_url text NOT NULL DEFAULT '',
  paypal_url text NOT NULL DEFAULT '',
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Paused workout sessions (resume same day, auto-finalize next day).
CREATE TABLE IF NOT EXISTS public.paused_workouts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL REFERENCES public.app_accounts(id) ON DELETE CASCADE,
  program_id uuid,
  workout_id text NOT NULL,
  workout_name text NOT NULL,
  paused_at timestamptz NOT NULL DEFAULT now(),
  elapsed_seconds integer NOT NULL DEFAULT 0 CHECK (elapsed_seconds >= 0),
  results jsonb NOT NULL DEFAULT '{}'::jsonb,
  has_working_progress boolean NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS paused_workouts_client_idx
  ON public.paused_workouts (client_id, workout_id);

-- ---------------------------------------------------------------
-- 3. Row Level Security
-- ---------------------------------------------------------------

-- Helpers resolving the current authenticated user's app account.
CREATE OR REPLACE FUNCTION public.current_account_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM public.app_accounts
  WHERE auth_user_id = auth.uid() AND is_preview = false
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_coach()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.app_accounts
    WHERE auth_user_id = auth.uid() AND role = 'coach' AND is_preview = false
  );
$$;

CREATE OR REPLACE FUNCTION public.is_payment_manager()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.app_accounts
    WHERE auth_user_id = auth.uid() AND role = 'payment_manager' AND is_preview = false
  );
$$;

-- payments: coach-managed records.
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS payments_coach_all ON public.payments;
CREATE POLICY payments_coach_all ON public.payments
  FOR ALL TO authenticated USING (public.is_coach()) WITH CHECK (public.is_coach());

-- payouts: payment manager submits, coach decides.
ALTER TABLE public.payouts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS payouts_manager_select ON public.payouts;
CREATE POLICY payouts_manager_select ON public.payouts
  FOR SELECT TO authenticated USING (public.is_coach() OR public.is_payment_manager());
DROP POLICY IF EXISTS payouts_manager_insert ON public.payouts;
CREATE POLICY payouts_manager_insert ON public.payouts
  FOR INSERT TO authenticated WITH CHECK (public.is_payment_manager());
DROP POLICY IF EXISTS payouts_coach_update ON public.payouts;
CREATE POLICY payouts_coach_update ON public.payouts
  FOR UPDATE TO authenticated USING (public.is_coach()) WITH CHECK (public.is_coach());

-- payment_started: any authenticated user may read/write claims (coach reads, clients write).
ALTER TABLE public.payment_started ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS payment_started_authenticated ON public.payment_started;
CREATE POLICY payment_started_authenticated ON public.payment_started
  FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- payment_settings: everyone reads (client needs to know if a method is configured), coach updates.
ALTER TABLE public.payment_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS payment_settings_select ON public.payment_settings;
CREATE POLICY payment_settings_select ON public.payment_settings
  FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS payment_settings_coach_update ON public.payment_settings;
CREATE POLICY payment_settings_coach_update ON public.payment_settings
  FOR UPDATE TO authenticated USING (public.is_coach()) WITH CHECK (public.is_coach());

-- paused_workouts: clients own their own rows.
ALTER TABLE public.paused_workouts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS paused_workouts_client_all ON public.paused_workouts;
CREATE POLICY paused_workouts_client_all ON public.paused_workouts
  FOR ALL TO authenticated
  USING (client_id = public.current_account_id())
  WITH CHECK (client_id = public.current_account_id());