begin;

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

  perform public.rebalance_waiting_queue_lanes();

  select v.nim into v_nim
  from public.voters v
  where v.queue_state = 'waiting'
    and v.eligible
    and not v.has_voted
  order by v.queue_position
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

notify pgrst, 'reload schema';
commit;
