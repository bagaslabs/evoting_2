begin;

create or replace function public.delete_voting_device(p_device_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device public.voting_devices%rowtype;
  v_assignment_count integer;
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings
  where singleton and election_state = 'closed'
  for update;
  if not found then
    raise exception using errcode = '55000',
      message = 'Perangkat hanya dapat dihapus saat pemilihan ditutup.';
  end if;

  select * into v_device
  from public.voting_devices
  where id = p_device_id
  for update;
  if not found then
    raise exception using errcode = 'P0002',
      message = 'Perangkat tidak ditemukan.';
  end if;
  if exists (
    select 1 from public.queue_assignments
    where device_id = v_device.id and state = 'active'
  ) then
    raise exception using errcode = '55000',
      message = 'Lepaskan assignment aktif sebelum menghapus perangkat.';
  end if;

  update public.voting_devices
  set active = false
  where id = v_device.id;

  update public.voters
  set queue_device_id = null
  where queue_device_id = v_device.id;

  delete from public.queue_assignments
  where device_id = v_device.id;
  get diagnostics v_assignment_count = row_count;

  delete from public.voting_devices
  where id = v_device.id;

  perform public.rebalance_waiting_queue_lanes(true);
  perform public.write_audit(
    'device_deleted',
    jsonb_build_object(
      'device_name', v_device.name,
      'assignments_deleted', v_assignment_count
    )
  );
end;
$$;

revoke all on function public.delete_voting_device(uuid)
  from public, anon, authenticated;
grant execute on function public.delete_voting_device(uuid)
  to authenticated;

notify pgrst, 'reload schema';
commit;
