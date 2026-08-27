-- No More Copium — Cloud runtime for the Google-authenticated app
-- 1) Onboarding state columns on app_accounts
-- 2) Table grants for the payment/paused tables (policies already exist)
-- 3) Workout history UPDATE/DELETE for the client owner
-- 4) Chat write access for thread participants
-- 5) Helper RPCs for payment unlock + payout decisions (SECURITY DEFINER)

-- Helpers used above.
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


CREATE OR REPLACE FUNCTION public.is_chat_participant(thread_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.chat_threads t
    WHERE t.id = thread_id
      AND (t.client_id = public.current_account_id() OR t.coach_id = public.current_account_id())
  );
$$;

CREATE OR REPLACE FUNCTION public.can_write_chat(thread_id uuid, sender_account_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT sender_account_id = public.current_account_id()
     AND EXISTS (
       SELECT 1 FROM public.chat_threads t
       WHERE t.id = thread_id
         AND (t.client_id = public.current_account_id() OR t.coach_id = public.current_account_id())
     );
$$;


-- -------------------------------------------------------------
-- 1. Onboarding state on accounts
-- -------------------------------------------------------------
ALTER TABLE public.app_accounts
  ADD COLUMN IF NOT EXISTS onboarding_step integer NOT NULL DEFAULT 0
    CHECK (onboarding_step BETWEEN 0 AND 7),
  ADD COLUMN IF NOT EXISTS onboarding_completed_at timestamptz;

GRANT UPDATE (onboarding_step, onboarding_completed_at, assigned_program_id)
  ON public.app_accounts TO authenticated;

-- Clients may update their own onboarding fields (column grants limit the damage).
DROP POLICY IF EXISTS "Clients can update their own onboarding" ON public.app_accounts;
CREATE POLICY "Clients can update their own onboarding"
  ON public.app_accounts FOR UPDATE
  TO authenticated
  USING (auth_user_id = auth.uid() AND is_preview = false)
  WITH CHECK (auth_user_id = auth.uid() AND is_preview = false);

-- -------------------------------------------------------------
-- 2. Grants for payment + paused tables (policies exist in 20260806120000)
-- -------------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON public.payments TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.payouts TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.payment_started TO authenticated;
GRANT SELECT, UPDATE ON public.payment_settings TO authenticated;
GRANT SELECT, INSERT, DELETE ON public.paused_workouts TO authenticated;

-- Clients may read their own payment records (coach creates them).
DROP POLICY IF EXISTS payments_client_read ON public.payments;
CREATE POLICY payments_client_read ON public.payments
  FOR SELECT TO authenticated
  USING (client_id = public.current_account_id());

-- -------------------------------------------------------------
-- 3. Workout history: client owns their rows fully
-- -------------------------------------------------------------
GRANT UPDATE, DELETE ON public.workout_sessions TO authenticated;

DROP POLICY IF EXISTS "Clients can update their own workout history" ON public.workout_sessions;
CREATE POLICY "Clients can update their own workout history"
  ON public.workout_sessions FOR UPDATE
  TO authenticated
  USING (public.owns_app_account(client_id))
  WITH CHECK (public.owns_app_account(client_id));

DROP POLICY IF EXISTS "Clients can delete their own workout history" ON public.workout_sessions;
CREATE POLICY "Clients can delete their own workout history"
  ON public.workout_sessions FOR DELETE
  TO authenticated
  USING (public.owns_app_account(client_id));

-- -------------------------------------------------------------
-- 4. Chat writes for participants
-- -------------------------------------------------------------
GRANT INSERT ON public.chat_threads TO authenticated;
GRANT INSERT ON public.chat_messages TO authenticated;
GRANT INSERT, UPDATE ON public.chat_reads TO authenticated;

-- A client creates their own thread with the coach.
DROP POLICY IF EXISTS "Clients can create their own chat thread" ON public.chat_threads;
CREATE POLICY "Clients can create their own chat thread"
  ON public.chat_threads FOR INSERT
  TO authenticated
  WITH CHECK (public.owns_app_account(client_id));

-- Participants can post messages in their thread.
DROP POLICY IF EXISTS "Chat participants can insert messages" ON public.chat_messages;
CREATE POLICY "Chat participants can insert messages"
  ON public.chat_messages FOR INSERT
  TO authenticated
  WITH CHECK (public.can_write_chat(thread_id, sender_account_id));

-- Participants can record their own read state.
DROP POLICY IF EXISTS "Chat participants can write their read state" ON public.chat_reads;
CREATE POLICY "Chat participants can write their read state"
  ON public.chat_reads FOR INSERT
  TO authenticated
  WITH CHECK (public.is_chat_participant(thread_id) AND account_id = public.current_account_id());

DROP POLICY IF EXISTS "Chat participants can update their read state" ON public.chat_reads;
CREATE POLICY "Chat participants can update their read state"
  ON public.chat_reads FOR UPDATE
  TO authenticated
  USING (public.is_chat_participant(thread_id) AND account_id = public.current_account_id())
  WITH CHECK (public.is_chat_participant(thread_id) AND account_id = public.current_account_id());

-- -------------------------------------------------------------
-- 5. Payment + payout RPCs (SECURITY DEFINER — service-role authority)
-- -------------------------------------------------------------

-- Coach records a confirmed payment for a client (by username) and unlocks them.
CREATE OR REPLACE FUNCTION public.record_payment_and_unlock(
  p_client_username text,
  p_amount_usd numeric,
  p_note text,
  p_recorded_by uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client public.app_accounts%ROWTYPE;
  v_tag text;
  v_payment_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.app_accounts WHERE id = p_recorded_by AND role = 'coach' AND is_preview = false) THEN
    RAISE EXCEPTION 'A Coach account is required.';
  END IF;
  SELECT * INTO v_client FROM public.app_accounts
    WHERE lower(username) = lower(p_client_username) AND role = 'client' AND is_preview = false
    LIMIT 1;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'No client account found with that username.';
  END IF;

  v_tag := 'new_user';
  IF EXISTS (SELECT 1 FROM public.payments WHERE client_id = v_client.id) THEN
    v_tag := 'membership';
  END IF;

  INSERT INTO public.payments (client_id, client_username, client_name, amount_usd, tag, note, recorded_by)
  VALUES (v_client.id, v_client.username, v_client.name, p_amount_usd, v_tag, NULLIF(btrim(coalesce(p_note, '')), ''), p_recorded_by)
  RETURNING id INTO v_payment_id;

  UPDATE public.app_accounts
  SET onboarding_step = 7, onboarding_completed_at = now()
  WHERE id = v_client.id;

  DELETE FROM public.payment_started WHERE client_id = v_client.id;

  RETURN v_payment_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_payment_and_unlock(text, numeric, text, uuid) TO authenticated;

-- Payment manager / coach submit a payout.
CREATE OR REPLACE FUNCTION public.submit_payout(
  p_amount_usd numeric,
  p_screenshot_id text,
  p_note text,
  p_submitted_by uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_payout_id uuid;
BEGIN
  IF p_amount_usd <= 0 THEN RAISE EXCEPTION 'Enter a payout amount greater than zero.'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.app_accounts WHERE id = p_submitted_by AND role IN ('coach', 'payment_manager') AND is_preview = false) THEN
    RAISE EXCEPTION 'A Coach or Payment Manager account is required.';
  END IF;
  INSERT INTO public.payouts (amount_usd, screenshot_id, note, submitted_by)
  VALUES (p_amount_usd, NULLIF(btrim(coalesce(p_screenshot_id, '')), ''), NULLIF(btrim(coalesce(p_note, '')), ''), p_submitted_by)
  RETURNING id INTO v_payout_id;
  RETURN v_payout_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_payout(numeric, text, text, uuid) TO authenticated;

-- Coach decides a payout.
CREATE OR REPLACE FUNCTION public.decide_payout(
  p_payout_id uuid,
  p_decision text,
  p_coach_id uuid,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.app_accounts WHERE id = p_coach_id AND role = 'coach' AND is_preview = false) THEN
    RAISE EXCEPTION 'A Coach account is required.';
  END IF;
  IF p_decision NOT IN ('approved', 'rejected') THEN RAISE EXCEPTION 'Invalid decision.'; END IF;
  UPDATE public.payouts
  SET status = p_decision,
      decided_at = now(),
      decided_by_coach_id = p_coach_id,
      rejection_reason = CASE WHEN p_decision = 'rejected' THEN NULLIF(btrim(coalesce(p_reason, '')), '') ELSE NULL END
  WHERE id = p_payout_id AND status = 'pending';
END;
$$;

GRANT EXECUTE ON FUNCTION public.decide_payout(uuid, text, uuid, text) TO authenticated;

-- Client records that they started a payment (card/paypal).
CREATE OR REPLACE FUNCTION public.record_payment_started(p_client_id uuid, p_method text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client public.app_accounts%ROWTYPE;
BEGIN
  IF p_client_id <> public.current_account_id() THEN
    RAISE EXCEPTION 'You can only start a payment for your own account.';
  END IF;
  SELECT * INTO v_client FROM public.app_accounts WHERE id = p_client_id AND is_preview = false;
  IF v_client.id IS NULL THEN RAISE EXCEPTION 'Client account not found.'; END IF;
  IF p_method NOT IN ('card', 'paypal') THEN RAISE EXCEPTION 'Invalid payment method.'; END IF;
  DELETE FROM public.payment_started WHERE client_id = p_client_id;
  INSERT INTO public.payment_started (client_id, client_username, client_name, method)
  VALUES (v_client.id, v_client.username, v_client.name, p_method);
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_payment_started(uuid, text) TO authenticated;

-- Coach upserts payment settings (single row).
CREATE OR REPLACE FUNCTION public.upsert_payment_settings(p_card_url text, p_paypal_url text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.app_accounts WHERE auth_user_id = auth.uid() AND role = 'coach' AND is_preview = false) THEN
    RAISE EXCEPTION 'A Coach account is required.';
  END IF;
  INSERT INTO public.payment_settings (id, card_url, paypal_url, updated_at)
  VALUES (1, coalesce(p_card_url, ''), coalesce(p_paypal_url, ''), now())
  ON CONFLICT (id) DO UPDATE
  SET card_url = EXCLUDED.card_url, paypal_url = EXCLUDED.paypal_url, updated_at = now();
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_payment_settings(text, text) TO authenticated;

-- Unread counts for the chat badge (rows: thread_id, client_id, unread).
CREATE OR REPLACE FUNCTION public.unread_counts(p_account_id uuid)
RETURNS TABLE (thread_id uuid, client_id uuid, unread bigint)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH my_threads AS (
    SELECT id, client_id FROM public.chat_threads
    WHERE client_id = p_account_id OR coach_id = p_account_id
  ),
  my_reads AS (
    SELECT thread_id, last_read_at FROM public.chat_reads WHERE account_id = p_account_id
  )
  SELECT t.id, t.client_id, COUNT(m.id)::bigint AS unread
  FROM my_threads t
  JOIN public.chat_messages m ON m.thread_id = t.id
  LEFT JOIN my_reads r ON r.thread_id = t.id
  WHERE m.sender_account_id <> p_account_id
    AND (r.last_read_at IS NULL OR m.created_at > r.last_read_at)
  GROUP BY t.id, t.client_id;
$$;

GRANT EXECUTE ON FUNCTION public.unread_counts(uuid) TO authenticated;

-- Client appends their onboarding script messages (client answer + coach replies).
CREATE OR REPLACE FUNCTION public.append_onboarding_messages(
  p_client uuid,
  p_messages jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_thread public.chat_threads%ROWTYPE;
  v_message jsonb;
  v_sender uuid;
  v_body text;
  v_created timestamptz;
BEGIN
  IF p_client <> public.current_account_id() THEN
    RAISE EXCEPTION 'Onboarding messages can only be appended to your own thread.';
  END IF;

  SELECT * INTO v_thread FROM public.chat_threads WHERE client_id = p_client LIMIT 1;
  IF v_thread.id IS NULL THEN
    SELECT * INTO v_thread FROM public.chat_threads WHERE client_id = p_client LIMIT 1;
  END IF;
  IF v_thread.id IS NULL THEN
    RAISE EXCEPTION 'No chat thread exists for this client.';
  END IF;

  FOR v_message IN SELECT * FROM jsonb_array_elements(p_messages) LOOP
    v_sender := (v_message->>'sender')::uuid;
    v_body := btrim(coalesce(v_message->>'body', ''));
    v_created := coalesce((v_message->>'created_at')::timestamptz, now());
    IF v_body = '' OR char_length(v_body) > 2000 THEN
      CONTINUE;
    END IF;
    IF v_sender <> p_client AND v_sender <> v_thread.coach_id THEN
      CONTINUE;
    END IF;
    INSERT INTO public.chat_messages (thread_id, sender_account_id, body, created_at)
    VALUES (v_thread.id, v_sender, v_body, v_created);
    UPDATE public.chat_threads
    SET last_message_body = v_body,
        last_message_sender_id = v_sender,
        last_message_at = v_created
    WHERE id = v_thread.id;
  END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION public.append_onboarding_messages(uuid, jsonb) TO authenticated;

-- No More Copium — Access codes (one-time vouchers) + manual onboarding foundation

-- 1. Access codes (one-time vouchers)
CREATE TABLE IF NOT EXISTS public.access_codes (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code_hash         text NOT NULL UNIQUE,
  code_prefix       text NOT NULL,
  note              text NOT NULL DEFAULT '',
  created_by        uuid NOT NULL REFERENCES public.app_accounts(id),
  expires_at        timestamptz NOT NULL,
  failed_attempts   integer NOT NULL DEFAULT 0 CHECK (failed_attempts >= 0),
  redeemed_at       timestamptz,
  ticket_hash       text,
  ticket_expires_at timestamptz,
  used_at           timestamptz,
  used_by           uuid REFERENCES public.app_accounts(id),
  revoked_at        timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS access_codes_prefix_idx ON public.access_codes (code_prefix);
CREATE INDEX IF NOT EXISTS access_codes_expires_idx ON public.access_codes (expires_at);

-- 2. Attempt log (per-IP rate limiting + per-code lockout)
CREATE TABLE IF NOT EXISTS public.access_code_attempts (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ip_hash      text NOT NULL,
  code_id      uuid REFERENCES public.access_codes(id),
  outcome      text NOT NULL,
  attempted_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS access_code_attempts_ip_window
  ON public.access_code_attempts (ip_hash, attempted_at);

-- 3. Audit events (coach-visible history)
CREATE TABLE IF NOT EXISTS public.access_code_events (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code_id     uuid REFERENCES public.access_codes(id),
  code_prefix text,
  event       text NOT NULL,
  actor       text NOT NULL,
  ip_hash     text,
  detail      text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS access_code_events_created_idx
  ON public.access_code_events (created_at DESC);

-- 4. Per-client program snapshot (coach-published)
CREATE TABLE IF NOT EXISTS public.client_program_bundles (
  client_id    uuid PRIMARY KEY REFERENCES public.app_accounts(id) ON DELETE CASCADE,
  bundle       jsonb NOT NULL,
  published_by uuid NOT NULL REFERENCES public.app_accounts(id),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- 5. No client-side access to the new tables (service-role only)
REVOKE ALL ON public.access_codes FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.access_code_attempts FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.access_code_events FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.client_program_bundles FROM PUBLIC, anon, authenticated;

ALTER TABLE public.access_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.access_code_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.access_code_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_program_bundles ENABLE ROW LEVEL SECURITY;

-- The ONLY rules on these tables:
--   * bundles: a client may SELECT their own row (RLS + table grant; own-row only).
--   * everything else: service-role only — no table access at all.
GRANT SELECT ON public.client_program_bundles TO authenticated;

DROP POLICY IF EXISTS "Clients can read their own program bundle" ON public.client_program_bundles;
CREATE POLICY "Clients can read their own program bundle"
  ON public.client_program_bundles FOR SELECT
  TO authenticated
  USING (client_id = public.current_account_id());

-- 6. Account approval gate
ALTER TABLE public.app_accounts
  ADD COLUMN IF NOT EXISTS approved_at timestamptz;

-- 7. Username rule: lowercase a–z, 0–9, underscore ONLY, 3–30 chars
ALTER TABLE public.app_accounts
  DROP CONSTRAINT IF EXISTS app_accounts_username_check;
ALTER TABLE public.app_accounts
  ADD CONSTRAINT app_accounts_username_check CHECK (
    char_length(username) BETWEEN 3 AND 30
    AND username ~ '^[a-z0-9_]+$'
  );

-- 8. Retire client self-driven onboarding
REVOKE UPDATE (onboarding_step, onboarding_completed_at) ON public.app_accounts FROM authenticated;
DROP POLICY IF EXISTS "Clients can update their own onboarding" ON public.app_accounts;

-- 9. RPCs (SECURITY DEFINER — the only way the new state changes)
-- 9.1 Coach approves a client → full access.
CREATE OR REPLACE FUNCTION public.approve_client(p_client_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_coach_id uuid;
  v_client   public.app_accounts%ROWTYPE;
BEGIN
  SELECT id INTO v_coach_id
  FROM public.app_accounts
  WHERE auth_user_id = auth.uid() AND role = 'coach' AND is_preview = false
  LIMIT 1;
  IF v_coach_id IS NULL THEN
    RAISE EXCEPTION 'A Coach account is required.';
  END IF;

  SELECT * INTO v_client
  FROM public.app_accounts
  WHERE id = p_client_id AND role = 'client' AND is_preview = false;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Client account was not found.';
  END IF;

  IF v_client.assigned_program_id IS NULL THEN
    RAISE EXCEPTION 'Assign a training program before approving this client.';
  END IF;

  UPDATE public.app_accounts
  SET approved_at = now()
  WHERE id = p_client_id;

  DELETE FROM public.payment_started WHERE client_id = p_client_id;
END;
$$;

-- 9.2 Coach publishes the client's program snapshot from the global library.
CREATE OR REPLACE FUNCTION public.publish_client_program(p_client_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_coach_id      uuid;
  v_client        public.app_accounts%ROWTYPE;
  v_programs      jsonb;
  v_workouts_all  jsonb;
  v_exercises_all jsonb;
  v_units         jsonb;
  v_program       jsonb;
  v_workout_ids   text[] := ARRAY[]::text[];
  v_workouts      jsonb := '[]'::jsonb;
  v_exercises     jsonb := '[]'::jsonb;
  v_bundle        jsonb;
BEGIN
  SELECT id INTO v_coach_id
  FROM public.app_accounts
  WHERE auth_user_id = auth.uid() AND role = 'coach' AND is_preview = false
  LIMIT 1;
  IF v_coach_id IS NULL THEN
    RAISE EXCEPTION 'A Coach account is required.';
  END IF;

  SELECT * INTO v_client
  FROM public.app_accounts
  WHERE id = p_client_id AND role = 'client' AND is_preview = false;
  IF v_client.id IS NULL THEN
    RAISE EXCEPTION 'Client account was not found.';
  END IF;
  IF v_client.assigned_program_id IS NULL THEN
    RAISE EXCEPTION 'Assign a training program before publishing.';
  END IF;

  SELECT programs, workouts, exercises, weight_units
  INTO v_programs, v_workouts_all, v_exercises_all, v_units
  FROM public.app_state
  WHERE id = 'global';

  IF v_programs IS NULL OR jsonb_typeof(v_programs) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'The program library is empty.';
  END IF;

  SELECT item.value INTO v_program
  FROM jsonb_array_elements(v_programs) AS item
  WHERE item.value->>'id' = v_client.assigned_program_id
  LIMIT 1;
  IF v_program IS NULL THEN
    RAISE EXCEPTION 'The assigned program was not found in the library.';
  END IF;

  SELECT COALESCE(array_agg(DISTINCT assignment.value->>'workoutId'), ARRAY[]::text[])
  INTO v_workout_ids
  FROM jsonb_each(
    CASE WHEN v_program ? 'dayAssignments' THEN v_program->'dayAssignments' ELSE '{}'::jsonb END
  ) AS assignment(key, value)
  WHERE assignment.value->>'type' = 'workout'
    AND assignment.value->>'workoutId' IS NOT NULL;

  SELECT COALESCE(jsonb_agg(item.value), '[]'::jsonb)
  INTO v_workouts
  FROM jsonb_array_elements(v_workouts_all) AS item
  WHERE item.value->>'id' = ANY (v_workout_ids);

  SELECT COALESCE(jsonb_agg(item.value), '[]'::jsonb)
  INTO v_exercises
  FROM jsonb_array_elements(v_exercises_all) AS item
  WHERE item.value->>'id' IN (
    SELECT DISTINCT prescription.value->>'exerciseId'
    FROM jsonb_array_elements(v_workouts) AS workout
    CROSS JOIN LATERAL jsonb_array_elements(
      COALESCE(workout.value->'exercises', '[]'::jsonb)
    ) AS prescription
    WHERE prescription.value->>'exerciseId' IS NOT NULL
  );

  v_bundle := jsonb_build_object(
    'program', v_program,
    'workouts', v_workouts,
    'exercises', v_exercises,
    'weight_units', COALESCE(v_units, '[]'::jsonb)
  );

  INSERT INTO public.client_program_bundles (client_id, bundle, published_by, updated_at)
  VALUES (p_client_id, v_bundle, v_coach_id, now())
  ON CONFLICT (client_id) DO UPDATE
  SET bundle = EXCLUDED.bundle,
      published_by = EXCLUDED.published_by,
      updated_at = now();
END;
$$;

-- 9.3 Client reads their own snapshot (NULL until approved/published).
CREATE OR REPLACE FUNCTION public.get_client_program_bundle()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_id uuid;
  v_approved  boolean;
  v_bundle    jsonb;
BEGIN
  v_client_id := public.current_account_id();
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Sign in to load your program.';
  END IF;

  SELECT approved_at IS NOT NULL INTO v_approved
  FROM public.app_accounts
  WHERE id = v_client_id AND role = 'client' AND is_preview = false;

  IF v_approved IS NOT TRUE THEN
    RETURN NULL;
  END IF;

  SELECT bundle INTO v_bundle
  FROM public.client_program_bundles
  WHERE client_id = v_client_id;

  RETURN v_bundle;
END;
$$;

-- 9.4 Seed the ONE onboarding greeting (idempotent, server-side text only).
CREATE OR REPLACE FUNCTION public.append_onboarding_greeting(p_client_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_client_name text;
  v_thread_id   uuid;
  v_coach_id    uuid;
  v_greeted     boolean;
  v_body        text;
BEGIN
  IF p_client_id <> public.current_account_id() THEN
    RAISE EXCEPTION 'Onboarding can only be opened on your own account.';
  END IF;

  SELECT name INTO v_client_name
  FROM public.app_accounts
  WHERE id = p_client_id AND role = 'client' AND is_preview = false;
  IF v_client_name IS NULL THEN
    RAISE EXCEPTION 'Client account was not found.';
  END IF;

  v_thread_id := public.get_or_create_chat_thread(p_client_id);
  SELECT coach_id INTO v_coach_id
  FROM public.chat_threads
  WHERE id = v_thread_id;
  IF v_coach_id IS NULL THEN
    RAISE EXCEPTION 'Coach account was not found.';
  END IF;

  v_body := 'Welcome to No More Copium, ' || v_client_name
         || '. How many times a week do you usually work out right now, brother?';

  SELECT EXISTS (
    SELECT 1
    FROM public.chat_messages existing
    WHERE existing.thread_id = v_thread_id
      AND existing.sender_account_id = v_coach_id
      AND existing.body LIKE 'Welcome to No More Copium,%'
  ) INTO v_greeted;
  IF v_greeted THEN
    RETURN;
  END IF;

  INSERT INTO public.chat_messages (id, thread_id, sender_account_id, body)
  VALUES (gen_random_uuid(), v_thread_id, v_coach_id, v_body);

  UPDATE public.chat_threads
  SET last_message_body = v_body,
      last_message_sender_id = v_coach_id,
      last_message_at = now()
  WHERE id = v_thread_id;
END;
$$;

-- 10. Grants (authenticated execution only; anon/public get nothing)
REVOKE ALL ON FUNCTION public.approve_client(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.publish_client_program(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_client_program_bundle() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.append_onboarding_greeting(uuid) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.approve_client(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.publish_client_program(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_client_program_bundle() TO authenticated;
GRANT EXECUTE ON FUNCTION public.append_onboarding_greeting(uuid) TO authenticated;

-- 11. Chat thread creation hardening (shadow-safe)
CREATE OR REPLACE FUNCTION public.get_or_create_chat_thread(p_client_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_thread_id uuid;
  v_coach_id  uuid;
BEGIN
  IF NOT (public.owns_app_account(p_client_id) OR public.is_app_coach()) THEN
    RAISE EXCEPTION 'You cannot access this Client conversation';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.app_accounts
    WHERE id = p_client_id AND role = 'client'
  ) THEN
    RAISE EXCEPTION 'Client account was not found';
  END IF;

  SELECT id INTO v_coach_id
  FROM public.app_accounts
  WHERE role = 'coach' AND is_preview = false
  LIMIT 1;
  IF v_coach_id IS NULL THEN
    RAISE EXCEPTION 'Coach account was not found';
  END IF;

  SELECT id INTO v_thread_id
  FROM public.chat_threads
  WHERE client_id = p_client_id;
  IF v_thread_id IS NULL THEN
    INSERT INTO public.chat_threads (client_id, coach_id)
    VALUES (p_client_id, v_coach_id)
    ON CONFLICT (client_id) DO NOTHING
    RETURNING id INTO v_thread_id;
    IF v_thread_id IS NULL THEN
      SELECT id INTO v_thread_id
      FROM public.chat_threads
      WHERE client_id = p_client_id;
    END IF;
  END IF;

  INSERT INTO public.chat_reads (thread_id, account_id)
  VALUES (v_thread_id, p_client_id), (v_thread_id, v_coach_id)
  ON CONFLICT (thread_id, account_id) DO NOTHING;
  RETURN v_thread_id;
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_create_chat_thread(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_chat_thread(uuid) TO authenticated;

-- No More Copium — Data isolation (B6: clients read ONLY their own snapshot)

-- 1. app_state: coach-only read
DROP POLICY IF EXISTS "Authenticated users can read app state"
  ON public.app_state;
DROP POLICY IF EXISTS "Clients can read their coach library"
  ON public.app_state;

CREATE POLICY "Coach can read app state"
  ON public.app_state FOR SELECT
  TO authenticated
  USING (public.is_app_coach());

-- 2. program-covers bucket: coach-only read
DROP POLICY IF EXISTS "Authenticated users can read program covers"
  ON storage.objects;
DROP POLICY IF EXISTS "Prototype program covers can be read"
  ON storage.objects;

CREATE POLICY "Coach can read program covers"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'program-covers'
    AND public.is_app_coach()
  );