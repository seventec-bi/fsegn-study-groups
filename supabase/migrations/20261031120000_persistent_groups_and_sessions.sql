-- Persistent study communities with optional, repeatable in-person sessions.
-- Existing group ids, members and messages are retained. Each legacy scheduled
-- group is represented as its first session so attendance history remains linked.

ALTER TABLE public.study_groups
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS cover_image_path TEXT;

UPDATE public.study_groups
SET name = left(btrim(topic), 80)
WHERE name IS NULL OR btrim(name) = '';

ALTER TABLE public.study_groups
  ALTER COLUMN name SET NOT NULL,
  ALTER COLUMN name SET DEFAULT 'Groupe de révision',
  ALTER COLUMN meeting_location DROP NOT NULL,
  ALTER COLUMN start_time DROP NOT NULL,
  ALTER COLUMN end_time DROP NOT NULL,
  DROP CONSTRAINT IF EXISTS chk_time_window;

ALTER TABLE public.study_groups
  ADD CONSTRAINT study_groups_name_length CHECK (char_length(btrim(name)) BETWEEN 2 AND 80),
  ADD CONSTRAINT study_groups_optional_meeting_location_length CHECK (
    meeting_location IS NULL OR char_length(btrim(meeting_location)) BETWEEN 2 AND 120
  ),
  ADD CONSTRAINT study_groups_optional_time_window CHECK (
    (start_time IS NULL AND end_time IS NULL) OR
    (start_time IS NOT NULL AND end_time IS NOT NULL AND end_time > start_time)
  );

CREATE OR REPLACE FUNCTION public.ensure_group_capacity_not_below_members()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
DECLARE v_count INT;
BEGIN
  IF NEW.capacity IS DISTINCT FROM OLD.capacity THEN
    SELECT count(*) INTO v_count FROM public.group_members WHERE group_id=NEW.id;
    IF NEW.capacity < v_count THEN
      RAISE EXCEPTION 'Member limit cannot be lower than the current membership (%)', v_count;
    END IF;
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER study_groups_capacity_floor
  BEFORE UPDATE OF capacity ON public.study_groups
  FOR EACH ROW EXECUTE FUNCTION public.ensure_group_capacity_not_below_members();

CREATE TABLE IF NOT EXISTS public.study_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.study_groups(id) ON DELETE CASCADE,
  topic TEXT NOT NULL CHECK (char_length(btrim(topic)) BETWEEN 2 AND 150),
  description TEXT CHECK (description IS NULL OR char_length(description) <= 800),
  meeting_location TEXT NOT NULL CHECK (char_length(btrim(meeting_location)) BETWEEN 2 AND 120),
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'cancelled', 'completed')),
  created_by UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT study_sessions_time_window CHECK (end_time > start_time)
);
CREATE INDEX IF NOT EXISTS idx_study_sessions_group_time
  ON public.study_sessions(group_id, start_time DESC);

-- Private group art; uploads are scoped to the creating member and group.
INSERT INTO storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
VALUES ('group-covers', 'group-covers', false, 5242880, ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO NOTHING;
CREATE POLICY "Group creators upload their group cover"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'group-covers' AND EXISTS (
    SELECT 1 FROM public.study_groups g
    WHERE g.id::text = (storage.foldername(name))[1]
      AND g.creator_id = (SELECT auth.uid())
  ));
CREATE POLICY "Group members can read group covers"
  ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'group-covers' AND EXISTS (
    SELECT 1 FROM public.study_groups g
    WHERE g.id::text = (storage.foldername(name))[1]
  ));
CREATE POLICY "Group creators replace their group cover"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'group-covers' AND EXISTS (
    SELECT 1 FROM public.study_groups g
    WHERE g.id::text = (storage.foldername(name))[1] AND g.creator_id = (SELECT auth.uid())
  ))
  WITH CHECK (bucket_id = 'group-covers' AND EXISTS (
    SELECT 1 FROM public.study_groups g
    WHERE g.id::text = (storage.foldername(name))[1] AND g.creator_id = (SELECT auth.uid())
  ));

CREATE TABLE IF NOT EXISTS public.study_session_members (
  session_id UUID NOT NULL REFERENCES public.study_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  attendance_confirmed BOOLEAN NOT NULL DEFAULT false,
  attendance_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (attendance_status IN ('pending', 'attended', 'absent', 'unconfirmed')),
  attendance_recorded_at TIMESTAMPTZ,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (session_id, user_id)
);

-- Backfill each existing scheduled group as its first in-person session.
INSERT INTO public.study_sessions
  (group_id, topic, description, meeting_location, start_time, end_time, status, created_by, created_at)
SELECT g.id, g.topic, g.description, g.meeting_location, g.start_time, g.end_time,
  CASE WHEN g.status = 'cancelled' THEN 'cancelled'
       WHEN g.end_time <= now() THEN 'completed'
       ELSE 'scheduled' END,
  g.creator_id, g.created_at
FROM public.study_groups g
WHERE g.start_time IS NOT NULL AND g.end_time IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM public.study_sessions s WHERE s.group_id = g.id);

INSERT INTO public.study_session_members
  (session_id, user_id, attendance_confirmed, attendance_status, attendance_recorded_at, joined_at)
SELECT s.id, gm.user_id, gm.attendance_confirmed, gm.attendance_status,
       gm.attendance_recorded_at, gm.joined_at
FROM public.study_sessions s
JOIN public.group_members gm ON gm.group_id = s.group_id
ON CONFLICT (session_id, user_id) DO NOTHING;

ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_session_members ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.study_sessions, public.study_session_members TO authenticated;

CREATE POLICY "Authenticated users can view study sessions"
  ON public.study_sessions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Group members can create study sessions"
  ON public.study_sessions FOR INSERT TO authenticated
  WITH CHECK (
    created_by = (SELECT auth.uid()) AND EXISTS (
      SELECT 1 FROM public.group_members gm
      WHERE gm.group_id = study_sessions.group_id AND gm.user_id = (SELECT auth.uid())
    )
  );
CREATE POLICY "Session creators can update their sessions"
  ON public.study_sessions FOR UPDATE TO authenticated
  USING (created_by = (SELECT auth.uid()))
  WITH CHECK (created_by = (SELECT auth.uid()));
REVOKE INSERT, UPDATE, DELETE ON public.study_sessions FROM authenticated, anon;
CREATE POLICY "Authenticated users can view session participants"
  ON public.study_session_members FOR SELECT TO authenticated USING (
    user_id=(SELECT auth.uid()) OR EXISTS (SELECT 1 FROM public.study_sessions s
      JOIN public.group_members gm ON gm.group_id=s.group_id
      WHERE s.id=study_session_members.session_id AND gm.user_id=(SELECT auth.uid()))
  );
CREATE POLICY "Group members can join a session"
  ON public.study_session_members FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid()) AND EXISTS (
      SELECT 1 FROM public.study_sessions s
      JOIN public.group_members gm ON gm.group_id = s.group_id
      WHERE s.id = study_session_members.session_id AND gm.user_id = (SELECT auth.uid())
    )
  );
REVOKE INSERT, UPDATE, DELETE ON public.study_session_members FROM authenticated, anon;

-- New community creation no longer requires a meeting. Legacy columns remain
-- nullable during transition and scheduled meetings live in study_sessions.
CREATE OR REPLACE FUNCTION public.join_study_group(p_group_id UUID)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_user_id UUID := auth.uid(); v_group RECORD; v_count INT;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT id, status, capacity INTO v_group FROM public.study_groups
  WHERE id = p_group_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Study group not found'; END IF;
  IF v_group.status = 'cancelled' THEN RAISE EXCEPTION 'This group is no longer active'; END IF;
  IF EXISTS (SELECT 1 FROM public.group_members WHERE group_id=p_group_id AND user_id=v_user_id) THEN
    RAISE EXCEPTION 'You are already a member of this group';
  END IF;
  SELECT count(*) INTO v_count FROM public.group_members WHERE group_id=p_group_id;
  IF v_count >= v_group.capacity THEN RAISE EXCEPTION 'Group is full (capacity % reached)', v_group.capacity; END IF;
  INSERT INTO public.group_members(group_id,user_id,role) VALUES(p_group_id,v_user_id,'member');
  INSERT INTO public.study_session_members(session_id,user_id)
  SELECT s.id,v_user_id FROM public.study_sessions s
  WHERE s.group_id=p_group_id AND s.start_time > now() AND s.status='scheduled'
  ON CONFLICT (session_id,user_id) DO NOTHING;
  RETURN json_build_object('success',true,'message','Joined study group successfully');
END; $$;

-- New session creation and participation are transactional with the existing
-- group membership. Attendance can be collected independently per meetup.
CREATE OR REPLACE FUNCTION public.create_study_session(
  p_group_id UUID, p_topic TEXT, p_description TEXT, p_meeting_location TEXT,
  p_start_time TIMESTAMPTZ, p_end_time TIMESTAMPTZ
) RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  IF p_start_time <= now() OR p_end_time <= p_start_time THEN
    RAISE EXCEPTION 'Choose a future start time and a later end time';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.group_members WHERE group_id=p_group_id AND user_id=auth.uid()) THEN
    RAISE EXCEPTION 'Only group members can schedule a session';
  END IF;
  INSERT INTO public.study_sessions(group_id,topic,description,meeting_location,start_time,end_time,created_by)
  VALUES(p_group_id,btrim(p_topic),NULLIF(btrim(p_description),''),btrim(p_meeting_location),p_start_time,p_end_time,auth.uid())
  RETURNING id INTO v_id;
  INSERT INTO public.study_session_members(session_id,user_id) SELECT v_id,user_id FROM public.group_members WHERE group_id=p_group_id;
  RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION public.set_study_session_confirmation(p_session_id UUID, p_confirmed BOOLEAN)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  UPDATE public.study_session_members sm
  SET attendance_confirmed=p_confirmed
  FROM public.study_sessions s
  JOIN public.group_members gm ON gm.group_id=s.group_id AND gm.user_id=auth.uid()
  WHERE sm.session_id=p_session_id AND sm.user_id=auth.uid() AND s.id=sm.session_id
    AND s.start_time > now() AND s.status='scheduled';
  IF NOT FOUND THEN RAISE EXCEPTION 'Join the group and confirm before the session starts'; END IF;
  RETURN json_build_object('success',true,'confirmed',p_confirmed);
END; $$;

CREATE OR REPLACE FUNCTION public.record_study_session_attendance(p_session_id UUID, p_attended BOOLEAN)
RETURNS JSON LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row public.study_session_members%ROWTYPE; v_score INT; v_delta INT := 0;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  SELECT sm.* INTO v_row FROM public.study_session_members sm
  JOIN public.study_sessions s ON s.id=sm.session_id
  JOIN public.group_members gm ON gm.group_id=s.group_id AND gm.user_id=auth.uid()
  WHERE sm.session_id=p_session_id AND sm.user_id=auth.uid() AND s.end_time <= now()
  FOR UPDATE OF sm;
  IF NOT FOUND THEN RAISE EXCEPTION 'Session is not over or you are not a participant'; END IF;
  IF v_row.attendance_recorded_at IS NOT NULL OR v_row.attendance_status <> 'pending' THEN
    RAISE EXCEPTION 'Attendance has already been recorded';
  END IF;
  IF v_row.attendance_confirmed THEN v_delta := CASE WHEN p_attended THEN 5 ELSE -15 END; END IF;
  SELECT reliability_score INTO v_score FROM public.profiles WHERE id=auth.uid() FOR UPDATE;
  v_score := GREATEST(0, LEAST(100, v_score + v_delta));
  UPDATE public.profiles SET reliability_score=v_score, updated_at=now() WHERE id=auth.uid();
  UPDATE public.study_session_members SET attendance_status=CASE WHEN p_attended THEN 'attended' ELSE 'absent' END,
    attendance_recorded_at=now() WHERE session_id=p_session_id AND user_id=auth.uid();
  RETURN json_build_object('success',true,'attended',p_attended,'score_delta',v_delta,'new_score',v_score);
END; $$;

REVOKE EXECUTE ON FUNCTION public.create_study_session(UUID,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_study_session(UUID,TEXT,TEXT,TEXT,TIMESTAMPTZ,TIMESTAMPTZ) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.join_study_group(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_study_group(UUID) TO authenticated;
-- Old group-scoped attendance RPCs are unsafe once groups have no single time.
REVOKE EXECUTE ON FUNCTION public.set_attendance_confirmation(UUID,BOOLEAN) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.record_my_attendance(UUID,BOOLEAN) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.set_study_session_confirmation(UUID,BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_study_session_confirmation(UUID,BOOLEAN) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.record_study_session_attendance(UUID,BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.record_study_session_attendance(UUID,BOOLEAN) TO authenticated;

NOTIFY pgrst, 'reload schema';
