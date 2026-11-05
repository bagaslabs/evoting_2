begin;

create or replace function public.verify_voter_for_device(p_token text, p_nim text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
  v_settings public.election_settings%rowtype;
  v_voter public.voters%rowtype;
  v_nim_suffix text := btrim(coalesce(p_nim, ''));
  v_match_count integer;
  v_matches jsonb;
begin
  v_device_id := public.lookup_device_id(p_token);
  if v_device_id is null then
    raise exception using errcode = '28000',
      message = 'Identitas perangkat tidak valid.';
  end if;

  if v_nim_suffix !~ '^[0-9]{3}$' then
    return jsonb_build_object('ok', false, 'code', 'invalid_nim_suffix');
  end if;

  select * into v_settings
  from public.election_settings
  where singleton
  for update;
  perform 1 from public.voting_devices
  where id = v_device_id and active
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'device_inactive');
  end if;
  update public.voting_devices
  set last_seen_at = now()
  where id = v_device_id;

  if v_settings.election_state <> 'open'
     or v_settings.active_round_id is null then
    return jsonb_build_object('ok', false, 'code', 'election_not_open');
  end if;

  select count(*) into v_match_count
  from public.voters v
  where right(v.nim, 3) = v_nim_suffix
    and v.eligible
    and not exists (
      select 1 from public.round_voter_participation p
      where p.round_id = v_settings.active_round_id and p.nim = v.nim
    );

  if v_match_count = 0 then
    if not exists (
      select 1 from public.voters v where right(v.nim, 3) = v_nim_suffix
    ) then
      return jsonb_build_object('ok', false, 'code', 'nim_not_found');
    end if;
    if not exists (
      select 1 from public.voters v
      where right(v.nim, 3) = v_nim_suffix and v.eligible
    ) then
      return jsonb_build_object('ok', false, 'code', 'not_eligible');
    end if;
    return jsonb_build_object('ok', false, 'code', 'already_voted');
  end if;

  if v_match_count > 1 then
    select jsonb_agg(jsonb_build_object(
      'nama', v.nama,
      'nim', v.nim,
      'jenis_kelamin', v.jenis_kelamin,
      'tanggal_masuk', v.tanggal_masuk,
      'status_saat_ini', v.status_saat_ini
    ) order by v.nama, v.nim)
    into v_matches
    from public.voters v
    where right(v.nim, 3) = v_nim_suffix
      and v.eligible
      and not exists (
        select 1 from public.round_voter_participation p
        where p.round_id = v_settings.active_round_id and p.nim = v.nim
      );
    return jsonb_build_object(
      'ok', false,
      'code', 'nim_ambiguous',
      'voters', v_matches
    );
  end if;

  select * into v_voter
  from public.voters v
  where right(v.nim, 3) = v_nim_suffix
    and v.eligible
    and not exists (
      select 1 from public.round_voter_participation p
      where p.round_id = v_settings.active_round_id and p.nim = v.nim
    )
  limit 1;

  return jsonb_build_object('ok', true, 'voter', jsonb_build_object(
    'nama', v_voter.nama,
    'nim', v_voter.nim,
    'jenis_kelamin', v_voter.jenis_kelamin,
    'tanggal_masuk', v_voter.tanggal_masuk,
    'status_saat_ini', v_voter.status_saat_ini
  ));
end;
$$;

revoke all on function public.verify_voter_for_device(text, text)
  from public, anon, authenticated;
grant execute on function public.verify_voter_for_device(text, text)
  to anon, authenticated;

notify pgrst, 'reload schema';
commit;
