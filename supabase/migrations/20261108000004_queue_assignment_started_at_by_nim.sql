begin;

create or replace function public.verify_voter_for_device(
  p_token text,
  p_client_id uuid,
  p_nim text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if public.lookup_device_id(p_token) is null then
    raise exception using errcode = '28000',
      message = 'Identitas perangkat tidak valid.';
  end if;

  perform 1 from public.election_settings where singleton for update;
  perform public.claim_voting_device(p_token, p_client_id);
  v_result := public.verify_voter_for_device(p_token, p_nim);

  if coalesce((v_result ->> 'ok')::boolean, false) then
    update public.queue_assignments
    set voter_started_at = coalesce(voter_started_at, now())
    where nim = v_result #>> '{voter,nim}' and state = 'active';
  end if;

  return v_result;
end;
$$;

create function public.clear_voter_started_for_device(
  p_token text,
  p_client_id uuid,
  p_nim text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if public.lookup_device_id(p_token) is null then
    raise exception using errcode = '28000',
      message = 'Identitas perangkat tidak valid.';
  end if;

  perform 1 from public.election_settings where singleton for update;
  perform public.claim_voting_device(p_token, p_client_id);

  update public.queue_assignments
  set voter_started_at = null
  where nim = p_nim and state = 'active';
end;
$$;

revoke all on function public.clear_voter_started_for_device(text, uuid, text)
  from public, anon, authenticated;
grant execute on function public.clear_voter_started_for_device(text, uuid, text)
  to anon, authenticated;

notify pgrst, 'reload schema';
commit;
