begin;

create or replace function public.cast_vote(
  p_token text,
  p_client_id uuid,
  p_nim text,
  p_candidate_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
  v_result jsonb;
begin
  if public.lookup_device_id(p_token) is null then
    raise exception using errcode = '28000',
      message = 'Identitas perangkat tidak valid.';
  end if;

  perform 1 from public.election_settings where singleton for update;
  v_device_id := public.claim_voting_device(p_token, p_client_id);
  v_result := public.cast_vote(p_token, p_nim, p_candidate_id);

  if v_result ->> 'ok' = 'true' then
    perform public.assign_next_to_device(v_device_id);
  end if;

  return v_result;
end;
$$;

revoke all on function public.cast_vote(text, uuid, text, uuid)
  from public, anon, authenticated;
grant execute on function public.cast_vote(text, uuid, text, uuid)
  to anon, authenticated;

notify pgrst, 'reload schema';
commit;
