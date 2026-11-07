begin;

alter table public.queue_assignments
  add column voter_started_at timestamptz;

create or replace function public.verify_voter_for_device(
  p_token text,
  p_client_id uuid,
  p_nim text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
  v_result jsonb;
begin
  if public.lookup_device_id(p_token) is null then
    raise exception using errcode = '28000',
      message = 'Identitas perangkat tidak valid.';
  end if;

  perform 1 from public.election_settings where singleton for update;
  v_device_id := public.claim_voting_device(p_token, p_client_id);
  v_result := public.verify_voter_for_device(p_token, p_nim);

  if coalesce((v_result ->> 'ok')::boolean, false) then
    update public.queue_assignments
    set voter_started_at = coalesce(voter_started_at, now())
    where device_id = v_device_id and state = 'active';
  end if;

  return v_result;
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
      'voter_suffix', case when v.nim is null then null else right(v.nim, 3) end,
      'voter_name', case when v.nim is null then null else array_to_string(
        (regexp_split_to_array(
          regexp_replace(btrim(v.nama), '[[:space:]]+', ' ', 'g'),
          ' '
        ))[1:2],
        ' '
      ) end,
      'waiting_for_voter', v.nim is null,
      'assigned_at', case when v.nim is null then null else a.assigned_at end,
      'voter_started_at',
        case when v.nim is null then null else a.voter_started_at end
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

notify pgrst, 'reload schema';
commit;
