begin;

create or replace function public.rebalance_waiting_queue_lanes(
  p_rebalance_all boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.voters v
  set queue_device_id = a.device_id
  from public.queue_assignments a
  where a.nim = v.nim
    and a.state = 'active'
    and v.queue_device_id is distinct from a.device_id;

  update public.voters v
  set queue_device_id = null
  where v.queue_state = 'waiting'
    and v.queue_device_id is not null;

  update public.voters v
  set queue_device_id = null
  where v.queue_state not in ('waiting', 'assigned')
    and v.queue_device_id is not null;
end;
$$;

select public.rebalance_waiting_queue_lanes(true);

create or replace function public.assign_next_to_device(p_device_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nim text;
  v_assignment_id uuid;
begin
  if exists (
    select 1 from public.queue_assignments a
    where a.device_id = p_device_id and a.state = 'active'
  ) then
    return jsonb_build_object('status', 'assigned');
  end if;

  update public.voters v
  set queue_state = 'completed', updated_at = now()
  where v.queue_state = 'waiting'
    and (not v.eligible or v.has_voted);

  select v.nim into v_nim
  from public.voters v
  where v.queue_state = 'waiting'
    and v.eligible
    and not v.has_voted
  order by v.queue_position, v.nim
  limit 1
  for update skip locked;

  if v_nim is null then
    if exists (
      select 1 from public.queue_assignments where state = 'active'
    ) then
      return jsonb_build_object('status', 'waiting');
    end if;
    return jsonb_build_object('status', 'empty');
  end if;

  insert into public.queue_assignments(device_id, nim, state)
  values (p_device_id, v_nim, 'active')
  returning id into v_assignment_id;

  update public.voters
  set queue_state = 'assigned',
      queue_device_id = p_device_id,
      updated_at = now()
  where nim = v_nim;

  return jsonb_build_object('status', 'assigned', 'assignment_id', v_assignment_id);
end;
$$;

create or replace function public.get_admin_queue_board()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_round_id uuid;
  v_devices jsonb;
  v_voters jsonb;
begin
  perform public.assert_superadmin();
  select active_round_id into v_round_id
  from public.election_settings
  where singleton;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', d.id,
    'name', d.name,
    'active', d.active,
    'connected', coalesce(d.last_seen_at >= now() - interval '30 seconds', false)
  ) order by d.created_at, d.id), '[]'::jsonb)
  into v_devices
  from public.voting_devices d;

  select coalesce(jsonb_agg(jsonb_build_object(
    'nama', v.nama,
    'nim', v.nim,
    'eligible', v.eligible,
    'has_voted', exists (
      select 1 from public.round_voter_participation p
      where p.round_id = v_round_id and p.nim = v.nim
    ),
    'queue_state', v.queue_state,
    'queue_position', v.queue_position,
    'queue_device_id', case
      when v.queue_state = 'assigned' then v.queue_device_id
      else null
    end,
    'device_name', (
      select d.name
      from public.queue_assignments a
      join public.voting_devices d on d.id = a.device_id
      where a.nim = v.nim and a.state = 'active'
      limit 1
    )
  ) order by v.queue_position), '[]'::jsonb)
  into v_voters
  from public.voters v;

  return jsonb_build_object('devices', v_devices, 'voters', v_voters);
end;
$$;

revoke all on function public.rebalance_waiting_queue_lanes(boolean)
  from public, anon, authenticated;
revoke all on function public.assign_next_to_device(uuid)
  from public, anon, authenticated;
revoke all on function public.get_admin_queue_board()
  from public, anon, authenticated;
grant execute on function public.get_admin_queue_board()
  to authenticated;

notify pgrst, 'reload schema';
commit;
