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
begin
  v_device_id := public.lookup_device_id(p_token);
  if v_device_id is null then
    raise exception using errcode = '28000',
      message = 'Identitas perangkat tidak valid.';
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

  select * into v_voter
  from public.voters
  where nim = btrim(p_nim);
  if not found then
    return jsonb_build_object('ok', false, 'code', 'nim_not_found');
  end if;
  if not v_voter.eligible then
    return jsonb_build_object('ok', false, 'code', 'not_eligible');
  end if;
  if exists (
    select 1 from public.round_voter_participation p
    where p.round_id = v_settings.active_round_id and p.nim = v_voter.nim
  ) then
    return jsonb_build_object('ok', false, 'code', 'already_voted');
  end if;

  return jsonb_build_object('ok', true, 'voter', jsonb_build_object(
    'nama', v_voter.nama,
    'nim', v_voter.nim,
    'jenis_kelamin', v_voter.jenis_kelamin,
    'tanggal_masuk', v_voter.tanggal_masuk,
    'status_saat_ini', v_voter.status_saat_ini
  ));
end;
$$;

create or replace function public.get_candidates_for_device(p_token text, p_nim text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
  v_round_id uuid;
  v_nim text := btrim(p_nim);
begin
  v_device_id := public.lookup_device_id(p_token);
  if v_device_id is null then
    raise exception using errcode = '28000',
      message = 'Identitas perangkat tidak valid.';
  end if;

  select active_round_id into v_round_id
  from public.election_settings
  where singleton and election_state = 'open';
  if v_round_id is null or not exists (
    select 1 from public.voting_devices d
    join public.voters v on v.nim = v_nim and v.eligible
    where d.id = v_device_id and d.active
      and not exists (
        select 1 from public.round_voter_participation p
        where p.round_id = v_round_id and p.nim = v.nim
      )
  ) then
    raise exception using errcode = '42501',
      message = 'Pemilih tidak eligible, sudah memilih, atau perangkat tidak aktif.';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', rc.candidate_id,
      'name', rc.name,
      'vision', rc.vision,
      'mission', rc.mission,
      'image_url', rc.image_url
    ) order by rc.sort_order)
    from public.round_candidates rc
    where rc.round_id = v_round_id and rc.enabled
  ), '[]'::jsonb);
end;
$$;

create or replace function public.cast_vote(
  p_token text,
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
  v_round_id uuid;
  v_voter public.voters%rowtype;
  v_nim text := btrim(p_nim);
begin
  v_device_id := public.lookup_device_id(p_token);
  if v_device_id is null then
    raise exception using errcode = '28000',
      message = 'Identitas perangkat tidak valid.';
  end if;

  select active_round_id into v_round_id
  from public.election_settings
  where singleton and election_state = 'open'
  for update;
  if not found or v_round_id is null then
    return jsonb_build_object('ok', false, 'code', 'election_not_open');
  end if;

  perform 1 from public.voting_devices
  where id = v_device_id and active
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'device_inactive');
  end if;

  select * into v_voter
  from public.voters
  where nim = v_nim
  for update;
  if not found or not v_voter.eligible then
    return jsonb_build_object('ok', false, 'code', 'not_eligible');
  end if;
  if exists (
    select 1 from public.round_voter_participation p
    where p.round_id = v_round_id and p.nim = v_nim
  ) then
    return jsonb_build_object('ok', false, 'code', 'already_voted');
  end if;
  if not exists (
    select 1 from public.round_candidates rc
    where rc.round_id = v_round_id
      and rc.candidate_id = p_candidate_id
      and rc.enabled
  ) then
    return jsonb_build_object('ok', false, 'code', 'candidate_unavailable');
  end if;

  insert into public.ballots(round_id, candidate_id)
  values (v_round_id, p_candidate_id);
  insert into public.round_voter_participation(round_id, nim)
  values (v_round_id, v_nim);

  update public.voters
  set has_voted = true,
      queue_state = 'completed',
      updated_at = now()
  where nim = v_nim;
  update public.queue_assignments
  set state = 'completed',
      completed_at = now()
  where nim = v_nim and state = 'active';
  update public.voting_devices
  set last_seen_at = now()
  where id = v_device_id;

  perform public.write_audit(
    'vote_cast',
    jsonb_build_object('device_id', v_device_id, 'round_id', v_round_id)
  );
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.get_public_current_queue()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'device_name', d.name,
      'voter_suffix', right(v.nim, 3)
    )
    order by d.created_at, d.id
  ), '[]'::jsonb)
  from public.queue_assignments a
  join public.voting_devices d
    on d.id = a.device_id and d.active
  join public.voters v
    on v.nim = a.nim
   and v.queue_state = 'assigned'
   and v.eligible
   and not v.has_voted
  join public.election_settings e
    on e.singleton
  where a.state = 'active'
    and not exists (
      select 1
      from public.round_voter_participation p
      where p.round_id = e.active_round_id
        and p.nim = v.nim
    );
$$;

revoke all on function public.verify_voter_for_device(text, text)
  from public, anon, authenticated;
grant execute on function public.verify_voter_for_device(text, text)
  to anon, authenticated;
revoke all on function public.get_candidates_for_device(text, text)
  from public, anon, authenticated;
grant execute on function public.get_candidates_for_device(text, text)
  to anon, authenticated;
revoke all on function public.cast_vote(text, text, uuid)
  from public, anon, authenticated;
grant execute on function public.cast_vote(text, text, uuid)
  to anon, authenticated;
revoke all on function public.get_public_current_queue()
  from public, anon, authenticated;
grant execute on function public.get_public_current_queue()
  to anon, authenticated;

notify pgrst, 'reload schema';
commit;
