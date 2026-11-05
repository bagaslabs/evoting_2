begin;

alter table public.voters
  add column if not exists queue_device_id uuid
    references public.voting_devices(id),
  add column if not exists eligibility_override boolean not null default false;

create or replace function public.rebalance_waiting_queue_lanes(
  p_rebalance_all boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_ids uuid[];
  v_lane_counts integer[];
  v_device_count integer;
  v_lane integer;
  v_lane_index integer;
  v_lane_count integer;
  v_voter record;
begin
  select array_agg(d.id order by d.created_at, d.id)
  into v_device_ids
  from public.voting_devices d
  where d.active;

  v_device_count := coalesce(cardinality(v_device_ids), 0);

  update public.voters v
  set queue_device_id = null
  where v.queue_state not in ('waiting', 'assigned')
    and v.queue_device_id is not null;

  update public.voters v
  set queue_device_id = a.device_id
  from public.queue_assignments a
  where a.nim = v.nim
    and a.state = 'active'
    and v.queue_device_id is distinct from a.device_id;

  if v_device_count = 0 then
    update public.voters
    set queue_device_id = null
    where queue_state = 'waiting'
      and queue_device_id is not null;
    return;
  end if;

  if p_rebalance_all then
    update public.voters v
    set queue_device_id = null
    where v.queue_state = 'waiting'
      and not exists (
        select 1 from public.queue_assignments a
        where a.nim = v.nim and a.state = 'active'
      );
  end if;

  update public.voters v
  set queue_device_id = null
  where v.queue_state = 'waiting'
    and not exists (
      select 1 from public.voting_devices d
      where d.id = v.queue_device_id and d.active
    );

  v_lane_counts := array_fill(0, array[v_device_count]);
  for v_lane in 1..v_device_count loop
    select count(*)::integer into v_lane_count
    from public.queue_assignments a
    join public.voters v on v.nim = a.nim
    where a.device_id = v_device_ids[v_lane]
      and a.state = 'active'
      and v.eligible
      and not v.has_voted;
    v_lane_counts[v_lane] := v_lane_count;

    select count(*)::integer into v_lane_count
    from public.voters v
    where v.queue_state = 'waiting'
      and v.eligible
      and not v.has_voted
      and v.queue_device_id = v_device_ids[v_lane]
      and not exists (
        select 1 from public.queue_assignments a
        where a.nim = v.nim and a.state = 'active'
      );
      v_lane_counts[v_lane] := v_lane_counts[v_lane] + v_lane_count;
  end loop;

  for v_voter in
    select v.nim
    from public.voters v
    where v.eligible
      and not v.has_voted
      and v.queue_state = 'waiting'
      and v.queue_device_id is null
      and not exists (
        select 1 from public.queue_assignments a
        where a.nim = v.nim and a.state = 'active'
      )
    order by v.queue_position, v.nim
  loop
    v_lane := 1;
    for v_lane_index in 2..v_device_count loop
      if v_lane_counts[v_lane_index] < v_lane_counts[v_lane] then
        v_lane := v_lane_index;
      end if;
    end loop;

    update public.voters
    set queue_device_id = v_device_ids[v_lane]
    where nim = v_voter.nim
      and queue_device_id is distinct from v_device_ids[v_lane];

    v_lane_counts[v_lane] := v_lane_counts[v_lane] + 1;
  end loop;

  update public.voters v
  set queue_device_id = null
  where v.queue_state = 'waiting'
    and (not v.eligible or v.has_voted)
    and v.queue_device_id is not null;
end;
$$;

create or replace function public.rebalance_waiting_queue_lanes_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.rebalance_waiting_queue_lanes(
    TG_TABLE_NAME = 'voting_devices'
  );
  return null;
end;
$$;

create or replace function public.clear_reordered_voter_queue_lane()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.queue_position is distinct from new.queue_position
     and new.queue_state = 'waiting' then
    new.queue_device_id := null;
  end if;
  return new;
end;
$$;

drop trigger if exists clear_reordered_voter_queue_lane on public.voters;
create trigger clear_reordered_voter_queue_lane
before update of queue_position
on public.voters
for each row
execute function public.clear_reordered_voter_queue_lane();

drop trigger if exists rebalance_voter_queue_lanes on public.voters;
drop trigger if exists rebalance_voter_queue_lanes_insert_delete on public.voters;
create trigger rebalance_voter_queue_lanes_insert_delete
after insert or delete
on public.voters
for each statement
execute function public.rebalance_waiting_queue_lanes_trigger();
create trigger rebalance_voter_queue_lanes
after update of eligible, queue_position, queue_state, has_voted
on public.voters
for each statement
execute function public.rebalance_waiting_queue_lanes_trigger();

drop trigger if exists rebalance_assignment_queue_lanes on public.queue_assignments;
create trigger rebalance_assignment_queue_lanes
after insert or update or delete
on public.queue_assignments
for each statement
execute function public.rebalance_waiting_queue_lanes_trigger();

drop trigger if exists rebalance_device_queue_lanes on public.voting_devices;
drop trigger if exists rebalance_device_queue_lanes_insert on public.voting_devices;
create trigger rebalance_device_queue_lanes_insert
after insert
on public.voting_devices
for each statement
execute function public.rebalance_waiting_queue_lanes_trigger();
create trigger rebalance_device_queue_lanes
after update of active
on public.voting_devices
for each statement
execute function public.rebalance_waiting_queue_lanes_trigger();

update public.voters v
set queue_device_id = a.device_id
from public.queue_assignments a
where a.nim = v.nim
  and a.state = 'active';
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

  perform public.rebalance_waiting_queue_lanes();

  select v.nim into v_nim
  from public.voters v
  where v.queue_state = 'waiting'
    and v.eligible
    and not v.has_voted
    and v.queue_device_id = p_device_id
  order by v.queue_position
  limit 1
  for update;

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

create or replace function public.get_admin_voter_roster()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_round_id uuid;
  v_roster jsonb;
begin
  perform public.assert_superadmin();
  select active_round_id into v_round_id
  from public.election_settings where singleton;

  select coalesce(jsonb_agg(jsonb_build_object(
    'nama', v.nama,
    'nim', v.nim,
    'eligible', v.eligible,
    'has_voted', exists (
      select 1 from public.round_voter_participation p
      where p.round_id = v_round_id and p.nim = v.nim
    ),
    'has_voted_any_round', exists (
      select 1 from public.round_voter_participation history
      where history.nim = v.nim
    ),
    'queue_state', v.queue_state,
    'queue_position', v.queue_position,
    'queue_device_id', v.queue_device_id,
    'device_name', assignment.device_name,
    'has_assignment_history', exists (
      select 1 from public.queue_assignments history where history.nim = v.nim
    )
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
    'queue_device_id', v.queue_device_id
  ) order by v.queue_position), '[]'::jsonb)
  into v_voters
  from public.voters v;

  return jsonb_build_object('devices', v_devices, 'voters', v_voters);
end;
$$;

create or replace function public.set_voter_eligibility(
  p_nim text,
  p_eligible boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_round_id uuid;
  v_has_voted boolean;
begin
  perform public.assert_superadmin();
  select active_round_id into v_round_id
  from public.election_settings
  where singleton
  for update;

  perform 1 from public.voters
  where nim = btrim(coalesce(p_nim, ''))
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Pemilih tidak ditemukan.';
  end if;
  if p_eligible is null then
    raise exception using errcode = '22023', message = 'Status eligible harus ditentukan.';
  end if;

  if not p_eligible then
    update public.queue_assignments
    set state = 'cancelled', completed_at = now()
    where nim = btrim(p_nim) and state = 'active';

    update public.voters
    set eligible = false,
        eligibility_override = true,
        queue_state = 'completed',
        queue_device_id = null,
        updated_at = now()
    where nim = btrim(p_nim);
  else
    select exists (
      select 1 from public.round_voter_participation
      where round_id = v_round_id and nim = btrim(p_nim)
    ) into v_has_voted;

    update public.voters
    set eligible = true,
        eligibility_override = true,
        has_voted = v_has_voted,
        queue_state = case when v_has_voted then 'completed' else 'waiting' end,
        updated_at = now()
    where nim = btrim(p_nim);
  end if;

  perform public.rebalance_waiting_queue_lanes();
  perform public.write_audit(
    'voter_eligibility_changed',
    jsonb_build_object('eligible', p_eligible)
  );
end;
$$;

create or replace function public.import_voters(p_voters jsonb)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
  v_offset bigint;
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings where singleton for update;
  if (select election_state from public.election_settings where singleton) <> 'closed' then
    raise exception using errcode = '55000',
      message = 'Impor data hanya dapat dilakukan saat pemilihan ditutup.';
  end if;
  if exists (select 1 from public.voters where has_voted)
     or exists (select 1 from public.queue_assignments where state = 'active') then
    raise exception using errcode = '55000',
      message = 'Data tidak dapat diimpor setelah voting dimulai atau assignment aktif dibuat.';
  end if;
  if coalesce(jsonb_typeof(p_voters), '') <> 'array' then
    raise exception using errcode = '22023',
      message = 'Data pemilih harus berupa array JSON yang tidak kosong.';
  end if;
  if jsonb_array_length(p_voters) = 0 then
    raise exception using errcode = '22023',
      message = 'Data pemilih harus berupa array JSON yang tidak kosong.';
  end if;

  select count(*) into v_count
  from jsonb_to_recordset(p_voters) as x(
    nim text, nama text, jenis_kelamin text, tanggal_masuk text, status_saat_ini text
  );
  if v_count <> jsonb_array_length(p_voters)
     or exists (
       select 1 from jsonb_to_recordset(p_voters) as x(
         nim text, nama text, jenis_kelamin text, tanggal_masuk text, status_saat_ini text
       )
       where nullif(btrim(nim), '') is null or nullif(btrim(nama), '') is null
     )
     or (select count(distinct x.nim)
         from jsonb_to_recordset(p_voters) as x(
           nim text, nama text, jenis_kelamin text, tanggal_masuk text, status_saat_ini text
         )) <> v_count then
    raise exception using errcode = '22023',
      message = 'Setiap pemilih harus memiliki NIM unik dan nama yang tidak kosong.';
  end if;

  if exists (
    select 1 from public.voters old
    where not exists (
      select 1 from jsonb_to_recordset(p_voters) as x(
        nim text, nama text, jenis_kelamin text, tanggal_masuk text, status_saat_ini text
      ) where x.nim = old.nim
    )
  ) then
    raise exception using errcode = '22023',
      message = 'Impor harus memuat seluruh NIM yang sudah terdaftar agar urutan tidak ambigu.';
  end if;

  select coalesce(max(queue_position), 0) + v_count + 1
  into v_offset from public.voters;
  update public.voters
  set queue_position = queue_position + v_offset
  where true;

  insert into public.voters as existing_voter(
    nim, nama, jenis_kelamin, tanggal_masuk, status_saat_ini,
    eligible, has_voted, queue_position, queue_state
  )
  select btrim(x.nim), btrim(x.nama), btrim(coalesce(x.jenis_kelamin, '')),
    nullif(btrim(coalesce(x.tanggal_masuk, '')), '')::date,
    btrim(coalesce(x.status_saat_ini, '')),
    btrim(coalesce(x.status_saat_ini, '')) ilike 'Aktif%', false, e.ordinality,
    case when btrim(coalesce(x.status_saat_ini, '')) ilike 'Aktif%'
      then 'waiting' else 'completed' end
  from jsonb_array_elements(p_voters) with ordinality as e(item, ordinality)
  cross join lateral jsonb_to_record(e.item) as x(
    nim text, nama text, jenis_kelamin text, tanggal_masuk text, status_saat_ini text
  )
  on conflict (nim) do update set
    nama = excluded.nama,
    jenis_kelamin = excluded.jenis_kelamin,
    tanggal_masuk = excluded.tanggal_masuk,
    status_saat_ini = excluded.status_saat_ini,
    eligible = case when existing_voter.eligibility_override
      then existing_voter.eligible else excluded.eligible end,
    queue_position = excluded.queue_position,
    queue_state = case
      when existing_voter.eligibility_override then
        case when existing_voter.eligible and not existing_voter.has_voted
          then 'waiting' else 'completed' end
      else excluded.queue_state
    end,
    updated_at = now();

  perform public.rebalance_waiting_queue_lanes();
  perform public.write_audit('voters_imported', jsonb_build_object('count', v_count));
  return v_count;
end;
$$;

revoke all on function public.rebalance_waiting_queue_lanes(boolean) from public, anon, authenticated;
revoke all on function public.rebalance_waiting_queue_lanes_trigger() from public, anon, authenticated;
revoke all on function public.clear_reordered_voter_queue_lane() from public, anon, authenticated;
revoke all on function public.assign_next_to_device(uuid) from public, anon, authenticated;
revoke all on function public.get_admin_queue_board() from public, anon, authenticated;
revoke all on function public.set_voter_eligibility(text, boolean) from public, anon, authenticated;
grant execute on function public.get_admin_queue_board() to authenticated;
grant execute on function public.set_voter_eligibility(text, boolean) to authenticated;

notify pgrst, 'reload schema';
commit;
