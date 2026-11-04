begin;

create function public.get_admin_voter_roster()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_roster jsonb;
begin
  perform public.assert_superadmin();

  select coalesce(jsonb_agg(jsonb_build_object(
    'nama', v.nama,
    'nim', v.nim,
    'eligible', v.eligible,
    'has_voted', v.has_voted,
    'queue_state', v.queue_state,
    'queue_position', v.queue_position,
    'device_name', assignment.device_name
  ) order by v.queue_position), '[]'::jsonb)
  into v_roster
  from public.voters v
  left join lateral (
    select d.name as device_name
    from public.queue_assignments a
    join public.voting_devices d on d.id = a.device_id
    where a.nim = v.nim and a.state = 'active'
    limit 1
  ) assignment on true;

  return v_roster;
end;
$$;

revoke all on function public.get_admin_voter_roster() from public, anon, authenticated;
grant execute on function public.get_admin_voter_roster() to authenticated;

notify pgrst, 'reload schema';

commit;
