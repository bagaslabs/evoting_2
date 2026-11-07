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
      'voter_suffix', case when v.nim is null then null else right(v.nim, 3) end,
      'voter_name', case when v.nim is null then null else array_to_string(
        (regexp_split_to_array(
          regexp_replace(btrim(v.nama), '[[:space:]]+', ' ', 'g'),
          ' '
        ))[1:2],
        ' '
      ) end,
      'waiting_for_voter', v.nim is null
    )
    order by d.created_at, d.id
  ), '[]'::jsonb)
  from public.voting_devices d
  left join public.queue_assignments a
    on a.device_id = d.id and a.state = 'active'
  left join public.voters v
    on v.nim = a.nim
   and v.queue_state = 'assigned'
   and v.eligible
   and not v.has_voted
   and not exists (
     select 1
     from public.round_voter_participation p
     join public.election_settings e
       on e.singleton and e.active_round_id = p.round_id
     where p.nim = v.nim
   )
  where d.active;
$$;

revoke all on function public.get_public_current_queue()
  from public, anon, authenticated;
grant execute on function public.get_public_current_queue()
  to anon, authenticated;

notify pgrst, 'reload schema';
commit;
