begin;

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
      'queue_number', v.queue_position
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

revoke all on function public.get_public_current_queue() from public, anon, authenticated;
grant execute on function public.get_public_current_queue() to anon, authenticated;

notify pgrst, 'reload schema';
commit;
