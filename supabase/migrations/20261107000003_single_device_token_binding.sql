begin;

alter table public.voting_devices
  add column device_client_id uuid;

create function public.claim_voting_device(p_token text, p_client_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
begin
  if p_client_id is null then
    raise exception using errcode = '22023',
      message = 'Identitas perangkat tidak valid.';
  end if;

  v_device_id := public.lookup_device_id(p_token);
  if v_device_id is null then
    raise exception using errcode = '28000',
      message = 'Identitas perangkat tidak valid.';
  end if;

  update public.voting_devices d
  set device_client_id = coalesce(d.device_client_id, p_client_id)
  where d.id = v_device_id
    and d.token_hash = extensions.digest(p_token, 'sha256')
    and (d.device_client_id is null or d.device_client_id = p_client_id)
  returning d.id into v_device_id;

  if v_device_id is null then
    if public.lookup_device_id(p_token) is null then
      raise exception using errcode = '28000',
        message = 'Identitas perangkat tidak valid.';
    end if;
    raise exception using errcode = '55000',
      message = 'Token ini sudah terhubung ke perangkat lain. Hubungi admin untuk mengganti token.';
  end if;

  return v_device_id;
end;
$$;

create function public.clear_device_client_binding_on_token_rotation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.token_hash is distinct from old.token_hash then
    new.device_client_id := null;
  end if;
  return new;
end;
$$;

create trigger voting_devices_clear_client_binding_on_token_rotation
before update of token_hash on public.voting_devices
for each row
execute function public.clear_device_client_binding_on_token_rotation();

create function public.poll_voting_device(p_token text, p_client_id uuid)
returns jsonb
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
  return public.poll_voting_device(p_token);
end;
$$;

create function public.verify_voter_for_device(
  p_token text,
  p_client_id uuid,
  p_nim text
)
returns jsonb
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
  return public.verify_voter_for_device(p_token, p_nim);
end;
$$;

create function public.get_candidates_for_device(
  p_token text,
  p_client_id uuid,
  p_nim text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.claim_voting_device(p_token, p_client_id);
  return public.get_candidates_for_device(p_token, p_nim);
end;
$$;

create function public.cast_vote(
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
begin
  if public.lookup_device_id(p_token) is null then
    raise exception using errcode = '28000',
      message = 'Identitas perangkat tidak valid.';
  end if;
  perform 1 from public.election_settings where singleton for update;
  perform public.claim_voting_device(p_token, p_client_id);
  return public.cast_vote(p_token, p_nim, p_candidate_id);
end;
$$;

revoke all on function public.claim_voting_device(text, uuid)
  from public, anon, authenticated;

revoke all on function public.clear_device_client_binding_on_token_rotation()
  from public, anon, authenticated;

revoke all on function public.poll_voting_device(text)
  from public, anon, authenticated;
revoke all on function public.verify_voter_for_device(text, text)
  from public, anon, authenticated;
revoke all on function public.get_candidates_for_device(text, text)
  from public, anon, authenticated;
revoke all on function public.cast_vote(text, text, uuid)
  from public, anon, authenticated;

revoke all on function public.poll_voting_device(text, uuid)
  from public, anon, authenticated;
revoke all on function public.verify_voter_for_device(text, uuid, text)
  from public, anon, authenticated;
revoke all on function public.get_candidates_for_device(text, uuid, text)
  from public, anon, authenticated;
revoke all on function public.cast_vote(text, uuid, text, uuid)
  from public, anon, authenticated;

grant execute on function public.poll_voting_device(text, uuid)
  to anon, authenticated;
grant execute on function public.verify_voter_for_device(text, uuid, text)
  to anon, authenticated;
grant execute on function public.get_candidates_for_device(text, uuid, text)
  to anon, authenticated;
grant execute on function public.cast_vote(text, uuid, text, uuid)
  to anon, authenticated;

notify pgrst, 'reload schema';
commit;
