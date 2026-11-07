begin;

alter table public.candidates
  add column if not exists show_vision_mission boolean not null default true;

drop function public.save_candidate(uuid, text, text, text, text, boolean);

create function public.save_candidate(
  p_id uuid,
  p_name text,
  p_vision text,
  p_mission text,
  p_image_url text,
  p_active boolean,
  p_show_vision_mission boolean
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings where singleton for update;
  if (select election_state from public.election_settings where singleton) <> 'closed' then
    raise exception using errcode = '55000',
      message = 'Kandidat hanya dapat diubah saat pemilihan ditutup.';
  end if;
  if length(btrim(coalesce(p_name, ''))) = 0 then
    raise exception using errcode = '22023', message = 'Nama kandidat wajib diisi.';
  end if;

  if p_id is null then
    insert into public.candidates(
      name, vision, mission, image_url, active, show_vision_mission
    )
    values (
      btrim(p_name), coalesce(p_vision, ''), coalesce(p_mission, ''),
      coalesce(p_image_url, ''), coalesce(p_active, true),
      coalesce(p_show_vision_mission, true)
    )
    returning id into v_id;
  else
    update public.candidates
    set name = btrim(p_name),
      vision = coalesce(p_vision, ''),
      mission = coalesce(p_mission, ''),
      image_url = coalesce(p_image_url, ''),
      active = coalesce(p_active, true),
      show_vision_mission = coalesce(p_show_vision_mission, true),
      updated_at = now()
    where id = p_id
    returning id into v_id;
    if v_id is null then
      raise exception using errcode = 'P0002', message = 'Kandidat tidak ditemukan.';
    end if;
  end if;

  perform public.write_audit(
    case when p_id is null then 'candidate_created' else 'candidate_updated' end,
    jsonb_build_object('candidate_id', v_id)
  );
  return v_id;
end;
$$;

revoke all on function public.save_candidate(
  uuid, text, text, text, text, boolean, boolean
) from public, anon, authenticated;
grant execute on function public.save_candidate(
  uuid, text, text, text, text, boolean, boolean
) to authenticated;

create or replace function public.get_admin_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_election jsonb;
  v_eligible integer;
  v_voted integer;
  v_total_ballots integer;
  v_candidates jsonb;
  v_devices jsonb;
  v_assignments jsonb;
  v_order jsonb;
  v_audit jsonb;
  v_rounds jsonb;
  v_round_id uuid;
begin
  perform public.assert_superadmin();
  select active_round_id into v_round_id
  from public.election_settings where singleton;
  select to_jsonb(e) || jsonb_build_object(
    'active_round_number', r.round_number,
    'active_round_title', r.title
  ) into v_election
  from public.election_settings e
  left join public.election_rounds r on r.id = e.active_round_id
  where e.singleton;

  select count(*) into v_eligible from public.voters where eligible;
  select coalesce(r.eligible_voters, v_eligible) into v_eligible
  from public.election_rounds r where r.id = v_round_id;
  select count(*) into v_voted
  from public.round_voter_participation p
  where p.round_id = v_round_id;
  select count(*) into v_total_ballots
  from public.ballots where round_id = v_round_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id, 'name', c.name, 'vision', c.vision, 'mission', c.mission,
    'show_vision_mission', c.show_vision_mission,
    'image_url', c.image_url, 'active', c.active,
    'votes', coalesce(v.vote_count, 0),
    'percentage', case when v_total_ballots = 0 then 0
      else round(coalesce(v.vote_count, 0)::numeric * 100 / v_total_ballots, 2) end
  ) order by c.created_at), '[]'::jsonb)
  into v_candidates
  from public.candidates c
  left join (
    select b.candidate_id, count(*)::integer as vote_count
    from public.ballots b where b.round_id = v_round_id
    group by b.candidate_id
  ) v on v.candidate_id = c.id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', d.id, 'name', d.name, 'active', d.active,
    'last_seen_at', d.last_seen_at,
    'connected', d.last_seen_at >= now() - interval '30 seconds',
    'active_assignment_id', a.id,
    'active_nim', a.nim
  ) order by d.created_at), '[]'::jsonb)
  into v_devices
  from public.voting_devices d
  left join lateral (
    select qa.id, qa.nim from public.queue_assignments qa
    where qa.device_id = d.id and qa.state = 'active' limit 1
  ) a on true;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id, 'device_id', a.device_id, 'device_name', d.name, 'nim', a.nim,
    'assigned_at', a.assigned_at
  ) order by a.assigned_at), '[]'::jsonb)
  into v_assignments
  from public.queue_assignments a
  join public.voting_devices d on d.id = a.device_id
  where a.state = 'active';

  select coalesce(jsonb_agg(jsonb_build_object(
    'nim', nim, 'position', queue_position
  ) order by queue_position), '[]'::jsonb)
  into v_order from public.voters;

  select coalesce(jsonb_agg(jsonb_build_object(
    'action', action, 'details', details, 'created_at', created_at
  ) order by created_at desc), '[]'::jsonb)
  into v_audit from (
    select action, details, created_at from public.audit_log
    order by created_at desc limit 25
  ) recent;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', r.id,
    'round_number', r.round_number,
    'title', r.title,
    'results_published', r.results_published,
    'show_public_participation', r.show_public_participation,
    'candidate_ids', coalesce((
      select jsonb_agg(rc.candidate_id order by rc.sort_order)
      from public.round_candidates rc where rc.round_id = r.id
    ), '[]'::jsonb)
  ) order by r.round_number), '[]'::jsonb)
  into v_rounds from public.election_rounds r;

  return jsonb_build_object(
    'election', v_election,
    'statistics', jsonb_build_object(
      'eligible', v_eligible,
      'voted', v_voted,
      'remaining', greatest(v_eligible - v_voted, 0),
      'participation_percentage', case when v_eligible = 0 then 0
        else round(v_voted::numeric * 100 / v_eligible, 2) end,
      'total_ballots', v_total_ballots
    ),
    'candidates', v_candidates,
    'devices', v_devices,
    'assignments', v_assignments,
    'queue_order', v_order,
    'audit_log', v_audit,
    'rounds', v_rounds
  );
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
      'show_vision_mission', c.show_vision_mission,
      'image_url', rc.image_url
    ) order by rc.sort_order)
    from public.round_candidates rc
    join public.candidates c on c.id = rc.candidate_id
    where rc.round_id = v_round_id and rc.enabled
  ), '[]'::jsonb);
end;
$$;

notify pgrst, 'reload schema';
commit;
