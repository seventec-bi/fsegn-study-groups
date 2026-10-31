create or replace function public.update_study_session(
  p_session_id uuid,
  p_topic text,
  p_description text,
  p_meeting_location text,
  p_start_time timestamptz,
  p_end_time timestamptz
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'You must be signed in.'; end if;
  if length(trim(coalesce(p_topic, ''))) = 0 or length(trim(p_topic)) > 120 then raise exception 'Enter a session topic (up to 120 characters).'; end if;
  if length(trim(coalesce(p_meeting_location, ''))) = 0 or length(trim(p_meeting_location)) > 200 then raise exception 'Enter a meeting place (up to 200 characters).'; end if;
  if p_start_time <= now() or p_end_time <= p_start_time then raise exception 'Choose a future start and an end time after it.'; end if;
  update public.study_sessions set topic = trim(p_topic), description = nullif(trim(coalesce(p_description, '')), ''), meeting_location = trim(p_meeting_location), start_time = p_start_time, end_time = p_end_time where id = p_session_id and created_by = auth.uid() and status = 'scheduled' and start_time > now();
  if not found then raise exception 'This session cannot be edited.'; end if;
end;
$$;
create or replace function public.cancel_study_session(p_session_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'You must be signed in.'; end if;
  update public.study_sessions set status = 'cancelled' where id = p_session_id and created_by = auth.uid() and status = 'scheduled' and start_time > now();
  if not found then raise exception 'This session cannot be cancelled.'; end if;
end;
$$;
create or replace function public.delete_study_session(p_session_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare session_owner uuid; session_start timestamptz; session_state text;
begin
  if auth.uid() is null then raise exception 'You must be signed in.'; end if;
  select created_by, start_time, status into session_owner, session_start, session_state from public.study_sessions where id = p_session_id for update;
  if not found or session_owner <> auth.uid() or session_start <= now() or session_state <> 'scheduled' then raise exception 'This session cannot be deleted.'; end if;
  if exists (select 1 from public.study_session_members where session_id = p_session_id and (attendance_confirmed = true or attendance_recorded_at is not null or coalesce(attendance_status, 'pending') <> 'pending')) then raise exception 'This session has sign-ups or attendance history. Cancel it to keep its history.'; end if;
  delete from public.study_sessions where id = p_session_id;
end;
$$;
revoke all on function public.update_study_session(uuid,text,text,text,timestamptz,timestamptz) from public, anon;
revoke all on function public.cancel_study_session(uuid) from public, anon;
revoke all on function public.delete_study_session(uuid) from public, anon;
grant execute on function public.update_study_session(uuid,text,text,text,timestamptz,timestamptz) to authenticated;
grant execute on function public.cancel_study_session(uuid) to authenticated;
grant execute on function public.delete_study_session(uuid) to authenticated;
notify pgrst, 'reload schema';
