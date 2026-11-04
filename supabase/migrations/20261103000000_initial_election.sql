begin;

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create table public.superadmins (
  singleton boolean primary key default true check (singleton),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.election_settings (
  singleton boolean primary key default true check (singleton),
  title text not null default 'Pemilihan Ketua Angkatan Teknik Elektro 2026',
  election_state text not null default 'closed'
    check (election_state in ('closed', 'open', 'paused')),
  results_published boolean not null default false,
  show_public_participation boolean not null default false,
  updated_at timestamptz not null default now()
);

insert into public.election_settings(singleton) values (true)
on conflict (singleton) do nothing;

create table public.voters (
  nim text primary key check (length(btrim(nim)) > 0),
  nama text not null check (length(btrim(nama)) > 0),
  jenis_kelamin text not null default '',
  tanggal_masuk date,
  status_saat_ini text not null default '',
  eligible boolean not null default false,
  has_voted boolean not null default false,
  queue_position bigint not null unique check (queue_position > 0),
  queue_state text not null default 'waiting'
    check (queue_state in ('waiting', 'assigned', 'completed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.candidates (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) > 0),
  vision text not null default '',
  mission text not null default '',
  image_url text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.voting_devices (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) > 0),
  token_hash bytea not null unique,
  active boolean not null default true,
  last_seen_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.queue_assignments (
  id uuid primary key default gen_random_uuid(),
  device_id uuid not null references public.voting_devices(id),
  nim text not null references public.voters(nim),
  state text not null check (state in ('active', 'completed', 'cancelled')),
  assigned_at timestamptz not null default now(),
  completed_at timestamptz
);

create unique index queue_assignments_one_active_per_device
  on public.queue_assignments(device_id) where state = 'active';
create unique index queue_assignments_one_active_per_voter
  on public.queue_assignments(nim) where state = 'active';
create index queue_assignments_history_by_device
  on public.queue_assignments(device_id, assigned_at desc);

create table public.ballots (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidates(id),
  cast_at timestamptz not null default now()
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.superadmins enable row level security;
alter table public.election_settings enable row level security;
alter table public.voters enable row level security;
alter table public.candidates enable row level security;
alter table public.voting_devices enable row level security;
alter table public.queue_assignments enable row level security;
alter table public.ballots enable row level security;
alter table public.audit_log enable row level security;

create function public.is_superadmin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.superadmins s
    where s.singleton and s.user_id = auth.uid()
  );
$$;

revoke all on function public.is_superadmin() from public, anon;
grant execute on function public.is_superadmin() to authenticated;

create policy "superadmin reads election settings"
  on public.election_settings for select to authenticated
  using (public.is_superadmin());
create policy "superadmin reads devices"
  on public.voting_devices for select to authenticated
  using (public.is_superadmin());
create policy "superadmin reads queue assignments"
  on public.queue_assignments for select to authenticated
  using (public.is_superadmin());
create policy "superadmin reads audit log"
  on public.audit_log for select to authenticated
  using (public.is_superadmin());

grant usage on schema public to anon, authenticated;
revoke all on public.superadmins, public.election_settings, public.voters,
  public.candidates, public.voting_devices, public.queue_assignments,
  public.ballots, public.audit_log from public, anon, authenticated;
revoke all on sequence public.audit_log_id_seq from public, anon, authenticated;
grant select on public.election_settings, public.voting_devices,
  public.queue_assignments, public.audit_log to authenticated;

create function public.assert_superadmin()
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.superadmins s
    where s.singleton and s.user_id = auth.uid()
  ) then
    raise exception using errcode = '42501', message = 'Akses admin ditolak.';
  end if;
end;
$$;

create function public.write_audit(p_action text, p_details jsonb default '{}'::jsonb)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.audit_log(actor_id, action, details)
  values (auth.uid(), p_action, coalesce(p_details, '{}'::jsonb));
$$;

create function public.assign_next_to_device(p_device_id uuid)
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
  where v.queue_state = 'waiting' and (not v.eligible or v.has_voted);

  select v.nim into v_nim
  from public.voters v
  where v.queue_state = 'waiting' and v.eligible and not v.has_voted
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

  update public.voters
  set queue_state = 'assigned', updated_at = now()
  where nim = v_nim;

  insert into public.queue_assignments(device_id, nim, state)
  values (p_device_id, v_nim, 'active')
  returning id into v_assignment_id;

  return jsonb_build_object('status', 'assigned', 'assignment_id', v_assignment_id);
end;
$$;

create function public.lookup_device_id(p_token text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select d.id
  from public.voting_devices d
  where length(coalesce(p_token, '')) = 64
    and d.token_hash = extensions.digest(p_token, 'sha256');
$$;

create function public.create_voting_device(p_name text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text := encode(extensions.gen_random_bytes(32), 'hex');
  v_device_id uuid;
begin
  perform public.assert_superadmin();
  if length(btrim(coalesce(p_name, ''))) = 0 then
    raise exception using errcode = '22023', message = 'Nama perangkat wajib diisi.';
  end if;

  insert into public.voting_devices(name, token_hash)
  values (btrim(p_name), extensions.digest(v_token, 'sha256'))
  returning id into v_device_id;

  perform public.write_audit('device_created', jsonb_build_object('device_id', v_device_id));
  return jsonb_build_object('device_id', v_device_id, 'name', btrim(p_name), 'token', v_token);
end;
$$;

create function public.set_device_active(p_device_id uuid, p_is_active boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings where singleton for update;
  perform 1 from public.voting_devices where id = p_device_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Perangkat tidak ditemukan.';
  end if;
  if not p_is_active and exists (
    select 1 from public.queue_assignments
    where device_id = p_device_id and state = 'active'
  ) then
    raise exception using errcode = '55000',
      message = 'Lepaskan assignment aktif sebelum menonaktifkan perangkat.';
  end if;
  update public.voting_devices set active = p_is_active where id = p_device_id;
  perform public.write_audit(
    case when p_is_active then 'device_activated' else 'device_deactivated' end,
    jsonb_build_object('device_id', p_device_id)
  );
end;
$$;

create function public.release_assignment(p_assignment_id uuid, p_reason text, p_action text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment public.queue_assignments%rowtype;
begin
  select * into v_assignment
  from public.queue_assignments
  where id = p_assignment_id and state = 'active'
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Assignment aktif tidak ditemukan.';
  end if;
  if exists (select 1 from public.voters where nim = v_assignment.nim and has_voted) then
    raise exception using errcode = '55000', message = 'Pemilih ini sudah menyelesaikan voting.';
  end if;

  update public.queue_assignments
  set state = 'cancelled', completed_at = now()
  where id = v_assignment.id;
  update public.voters
  set queue_state = 'waiting', updated_at = now()
  where nim = v_assignment.nim;
  perform public.write_audit(
    p_action,
    jsonb_build_object(
      'assignment_id', v_assignment.id,
      'device_id', v_assignment.device_id,
      'reason', left(coalesce(p_reason, ''), 500)
    )
  );
end;
$$;

create function public.force_release_device(p_device_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_assignment_id uuid;
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings where singleton for update;
  perform 1 from public.voting_devices where id = p_device_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Perangkat tidak ditemukan.';
  end if;
  select id into v_assignment_id from public.queue_assignments
  where device_id = p_device_id and state = 'active' for update;
  if v_assignment_id is null then
    raise exception using errcode = 'P0002', message = 'Tidak ada assignment aktif pada perangkat.';
  end if;
  perform public.release_assignment(v_assignment_id, p_reason, 'device_force_released');
  update public.voting_devices set active = false where id = p_device_id;
  perform public.write_audit(
    'device_deactivated',
    jsonb_build_object('device_id', p_device_id, 'reason', left(coalesce(p_reason, ''), 500))
  );
end;
$$;

create function public.cancel_queue_assignment(p_assignment_id uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings where singleton for update;
  if length(btrim(coalesce(p_reason, ''))) = 0 then
    raise exception using errcode = '22023', message = 'Alasan pembatalan wajib diisi.';
  end if;
  perform public.release_assignment(p_assignment_id, p_reason, 'queue_assignment_cancelled');
end;
$$;

create function public.import_voters(p_voters jsonb)
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
    raise exception using errcode = '55000', message = 'Impor data hanya dapat dilakukan saat pemilihan ditutup.';
  end if;
  if exists (select 1 from public.voters where has_voted)
     or exists (select 1 from public.queue_assignments where state = 'active') then
    raise exception using errcode = '55000',
      message = 'Data tidak dapat diimpor setelah voting dimulai atau assignment aktif dibuat.';
  end if;
  if coalesce(jsonb_typeof(p_voters), '') <> 'array' then
    raise exception using errcode = '22023', message = 'Data pemilih harus berupa array JSON yang tidak kosong.';
  end if;
  if jsonb_array_length(p_voters) = 0 then
    raise exception using errcode = '22023', message = 'Data pemilih harus berupa array JSON yang tidak kosong.';
  end if;

  select count(*) into v_count from jsonb_to_recordset(p_voters) as x(
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
  where nim is not null;
  insert into public.voters(
    nim, nama, jenis_kelamin, tanggal_masuk, status_saat_ini,
    eligible, has_voted, queue_position, queue_state
  )
  select btrim(x.nim), btrim(x.nama), btrim(coalesce(x.jenis_kelamin, '')),
    nullif(btrim(coalesce(x.tanggal_masuk, '')), '')::date,
    btrim(coalesce(x.status_saat_ini, '')),
    btrim(coalesce(x.status_saat_ini, '')) ilike 'Aktif%', false, e.ordinality,
    case when btrim(coalesce(x.status_saat_ini, '')) ilike 'Aktif%' then 'waiting' else 'completed' end
  from jsonb_array_elements(p_voters) with ordinality as e(item, ordinality)
  cross join lateral jsonb_to_record(e.item) as x(
    nim text, nama text, jenis_kelamin text, tanggal_masuk text, status_saat_ini text
  )
  on conflict (nim) do update set
    nama = excluded.nama,
    jenis_kelamin = excluded.jenis_kelamin,
    tanggal_masuk = excluded.tanggal_masuk,
    status_saat_ini = excluded.status_saat_ini,
    eligible = excluded.eligible,
    queue_position = excluded.queue_position,
    queue_state = case when excluded.eligible then 'waiting' else 'completed' end,
    updated_at = now();

  perform public.write_audit('voters_imported', jsonb_build_object('count', v_count));
  return v_count;
end;
$$;

create function public.set_queue_order(p_nims text[])
returns void
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
  if (select election_state from public.election_settings where singleton) <> 'closed'
     or exists (select 1 from public.voters where has_voted)
     or exists (select 1 from public.queue_assignments where state = 'active') then
    raise exception using errcode = '55000', message = 'Urutan antrean hanya dapat diubah sebelum pemilihan dibuka.';
  end if;
  select count(*) into v_count from public.voters;
  if coalesce(cardinality(p_nims), 0) <> v_count
     or (select count(distinct x.nim) from unnest(coalesce(p_nims, array[]::text[])) x(nim)) <> v_count
     or exists (
       select 1 from unnest(coalesce(p_nims, array[]::text[])) x(nim)
       left join public.voters v on v.nim = x.nim
       where v.nim is null
     ) then
    raise exception using errcode = '22023', message = 'Urutan harus memuat setiap NIM terdaftar tepat satu kali.';
  end if;

  select coalesce(max(queue_position), 0) + v_count + 1
  into v_offset from public.voters;
  update public.voters
  set queue_position = queue_position + v_offset
  where nim is not null;
  update public.voters v
  set queue_position = x.position, updated_at = now()
  from unnest(p_nims) with ordinality as x(nim, position)
  where v.nim = x.nim;
  perform public.write_audit('queue_order_updated', jsonb_build_object('voter_count', v_count));
end;
$$;

create function public.save_candidate(
  p_id uuid, p_name text, p_vision text, p_mission text, p_image_url text, p_active boolean
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
    raise exception using errcode = '55000', message = 'Kandidat hanya dapat diubah saat pemilihan ditutup.';
  end if;
  if length(btrim(coalesce(p_name, ''))) = 0 then
    raise exception using errcode = '22023', message = 'Nama kandidat wajib diisi.';
  end if;

  if p_id is null then
    insert into public.candidates(name, vision, mission, image_url, active)
    values (btrim(p_name), coalesce(p_vision, ''), coalesce(p_mission, ''),
      coalesce(p_image_url, ''), coalesce(p_active, true))
    returning id into v_id;
  else
    update public.candidates
    set name = btrim(p_name), vision = coalesce(p_vision, ''),
      mission = coalesce(p_mission, ''), image_url = coalesce(p_image_url, ''),
      active = coalesce(p_active, true), updated_at = now()
    where id = p_id returning id into v_id;
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

create function public.set_election_state(p_state text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_state text;
begin
  perform public.assert_superadmin();
  select election_state into v_state from public.election_settings
  where singleton for update;

  if p_state = 'open' and v_state = 'closed' then
    if not exists (select 1 from public.voters where eligible)
       or not exists (select 1 from public.candidates where active) then
      raise exception using errcode = '55000',
        message = 'Tambahkan pemilih eligible dan minimal satu kandidat sebelum membuka pemilihan.';
    end if;
    update public.voters
    set queue_state = case when eligible and not has_voted then 'waiting' else 'completed' end,
      updated_at = now();
  elsif p_state = 'paused' and v_state = 'open' then
    null;
  elsif p_state = 'open' and v_state = 'paused' then
    null;
  elsif p_state = 'closed' and v_state in ('open', 'paused') then
    update public.queue_assignments
    set state = 'cancelled', completed_at = now()
    where state = 'active';
    update public.voters
    set queue_state = case when eligible and not has_voted then 'waiting' else 'completed' end,
      updated_at = now();
  else
    raise exception using errcode = '55000', message = 'Perubahan status pemilihan tidak valid.';
  end if;

  update public.election_settings
  set election_state = p_state, updated_at = now()
  where singleton;
  perform public.write_audit('election_state_changed', jsonb_build_object('from', v_state, 'to', p_state));
end;
$$;

create function public.set_results_publication(p_published boolean, p_show_participation boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.assert_superadmin();
  update public.election_settings
  set results_published = p_published,
      show_public_participation = p_show_participation,
      updated_at = now()
  where singleton;
  perform public.write_audit(
    case when p_published then 'results_published' else 'results_hidden' end,
    jsonb_build_object('show_participation', p_show_participation)
  );
end;
$$;

create function public.admin_record_action(p_action text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.assert_superadmin();
  if p_action <> 'admin_password_changed' then
    raise exception using errcode = '22023', message = 'Aksi audit tidak dikenal.';
  end if;
  perform public.write_audit(p_action);
end;
$$;

create function public.get_admin_dashboard()
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
begin
  perform public.assert_superadmin();

  select to_jsonb(e) into v_election
  from public.election_settings e where e.singleton;
  select count(*) into v_eligible from public.voters where eligible;
  select count(*) into v_voted from public.voters where eligible and has_voted;
  select count(*) into v_total_ballots from public.ballots;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id, 'name', c.name, 'vision', c.vision, 'mission', c.mission,
    'image_url', c.image_url, 'active', c.active, 'votes', coalesce(v.vote_count, 0),
    'percentage', case when v_total_ballots = 0 then 0
      else round(coalesce(v.vote_count, 0)::numeric * 100 / v_total_ballots, 2) end
  ) order by c.created_at), '[]'::jsonb)
  into v_candidates
  from public.candidates c
  left join (
    select b.candidate_id, count(*)::integer as vote_count
    from public.ballots b group by b.candidate_id
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
  from public.queue_assignments a join public.voting_devices d on d.id = a.device_id
  where a.state = 'active';

  select coalesce(jsonb_agg(jsonb_build_object('nim', nim, 'position', queue_position)
    order by queue_position), '[]'::jsonb)
  into v_order from public.voters;

  select coalesce(jsonb_agg(jsonb_build_object(
    'action', action, 'details', details, 'created_at', created_at
  ) order by created_at desc), '[]'::jsonb)
  into v_audit from (
    select action, details, created_at from public.audit_log order by created_at desc limit 25
  ) recent;

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
    'audit_log', v_audit
  );
end;
$$;

create function public.poll_voting_device(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
  v_active boolean;
  v_state text;
  v_result jsonb;
begin
  v_device_id := public.lookup_device_id(p_token);
  if v_device_id is null then
    raise exception using errcode = '28000', message = 'Identitas perangkat tidak valid.';
  end if;
  select election_state into v_state from public.election_settings
  where singleton for update;
  select active into v_active from public.voting_devices
  where id = v_device_id for update;
  if not v_active then
    return jsonb_build_object('status', 'inactive');
  end if;
  update public.voting_devices set last_seen_at = now() where id = v_device_id;

  if v_state <> 'open' then
    return jsonb_build_object('status', v_state);
  end if;
  if exists (
    select 1 from public.queue_assignments
    where device_id = v_device_id and state = 'active'
  ) then
    return jsonb_build_object('status', 'assigned');
  end if;

  v_result := public.assign_next_to_device(v_device_id);
  return v_result;
end;
$$;

create function public.verify_voter_for_device(p_token text, p_nim text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
  v_state text;
  v_voter public.voters%rowtype;
  v_assigned_nim text;
begin
  v_device_id := public.lookup_device_id(p_token);
  if v_device_id is null then
    raise exception using errcode = '28000', message = 'Identitas perangkat tidak valid.';
  end if;
  select election_state into v_state from public.election_settings
  where singleton for update;
  perform 1 from public.voting_devices
  where id = v_device_id and active for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'device_inactive');
  end if;
  update public.voting_devices set last_seen_at = now() where id = v_device_id;
  if v_state <> 'open' then
    return jsonb_build_object('ok', false, 'code', 'election_not_open');
  end if;

  select a.nim into v_assigned_nim
  from public.queue_assignments a
  where a.device_id = v_device_id and a.state = 'active';
  if v_assigned_nim is null then
    return jsonb_build_object('ok', false, 'code', 'no_assignment');
  end if;
  select * into v_voter from public.voters where nim = p_nim;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'nim_not_found');
  end if;
  if p_nim is distinct from v_assigned_nim then
    return jsonb_build_object('ok', false, 'code', 'nim_mismatch');
  end if;
  if not v_voter.eligible then
    return jsonb_build_object('ok', false, 'code', 'not_eligible');
  end if;
  if v_voter.has_voted then
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

create function public.get_candidates_for_device(p_token text, p_nim text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
begin
  v_device_id := public.lookup_device_id(p_token);
  if v_device_id is null then
    raise exception using errcode = '28000', message = 'Identitas perangkat tidak valid.';
  end if;
  if not exists (
    select 1 from public.voting_devices d
    join public.queue_assignments a on a.device_id = d.id and a.state = 'active' and a.nim = p_nim
    join public.voters v on v.nim = a.nim and v.eligible and not v.has_voted
    join public.election_settings e on e.singleton and e.election_state = 'open'
    where d.id = v_device_id and d.active
  ) then
    raise exception using errcode = '42501', message = 'Pemilih tidak memiliki assignment aktif pada perangkat ini.';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'name', c.name, 'vision', c.vision,
      'mission', c.mission, 'image_url', c.image_url
    ) order by c.created_at)
    from public.candidates c where c.active
  ), '[]'::jsonb);
end;
$$;

create function public.cast_vote(p_token text, p_nim text, p_candidate_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
  v_assignment_id uuid;
  v_voter public.voters%rowtype;
begin
  v_device_id := public.lookup_device_id(p_token);
  if v_device_id is null then
    raise exception using errcode = '28000', message = 'Identitas perangkat tidak valid.';
  end if;
  perform 1 from public.election_settings
  where singleton and election_state = 'open' for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'election_not_open');
  end if;
  perform 1 from public.voting_devices where id = v_device_id and active for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'device_inactive');
  end if;
  select a.id, a.nim into v_assignment_id, v_voter.nim
  from public.queue_assignments a
  where a.device_id = v_device_id and a.state = 'active' and a.nim = p_nim
  for update;
  if v_assignment_id is null then
    return jsonb_build_object('ok', false, 'code', 'nim_mismatch');
  end if;
  select * into v_voter from public.voters where nim = p_nim for update;
  if not found or not v_voter.eligible then
    return jsonb_build_object('ok', false, 'code', 'not_eligible');
  end if;
  if v_voter.has_voted then
    return jsonb_build_object('ok', false, 'code', 'already_voted');
  end if;
  if not exists (select 1 from public.candidates where id = p_candidate_id and active) then
    return jsonb_build_object('ok', false, 'code', 'candidate_unavailable');
  end if;

  insert into public.ballots(candidate_id) values (p_candidate_id);
  update public.voters
  set has_voted = true, queue_state = 'completed', updated_at = now()
  where nim = p_nim;
  update public.queue_assignments
  set state = 'completed', completed_at = now()
  where id = v_assignment_id;
  update public.voting_devices set last_seen_at = now() where id = v_device_id;
  perform public.write_audit('vote_cast', jsonb_build_object('device_id', v_device_id));
  return jsonb_build_object('ok', true);
end;
$$;

create function public.get_public_results()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_election public.election_settings%rowtype;
  v_eligible integer;
  v_voted integer;
  v_total integer;
  v_candidates jsonb;
  v_result jsonb;
begin
  select * into v_election from public.election_settings where singleton;
  if not v_election.results_published then
    return jsonb_build_object(
      'published', false,
      'message', 'Hasil pemilihan belum dipublikasikan.'
    );
  end if;

  select count(*) into v_eligible from public.voters where eligible;
  select count(*) into v_voted from public.voters where eligible and has_voted;
  select count(*) into v_total from public.ballots;
  select coalesce(jsonb_agg(jsonb_build_object(
    'name', c.name,
    'votes', coalesce(b.vote_count, 0),
    'percentage', case when v_total = 0 then 0
      else round(coalesce(b.vote_count, 0)::numeric * 100 / v_total, 2) end
  ) order by c.created_at), '[]'::jsonb)
  into v_candidates
  from public.candidates c
  left join (
    select candidate_id, count(*)::integer as vote_count
    from public.ballots group by candidate_id
  ) b on b.candidate_id = c.id;

  v_result := jsonb_build_object(
    'published', true,
    'title', v_election.title,
    'total_votes', v_total,
    'candidates', v_candidates
  );
  if v_election.show_public_participation then
    v_result := v_result || jsonb_build_object(
      'participation_percentage',
      case when v_eligible = 0 then 0 else round(v_voted::numeric * 100 / v_eligible, 2) end
    );
  end if;
  return v_result;
end;
$$;

revoke execute on all functions in schema public from public, anon, authenticated;

grant execute on function public.create_voting_device(text) to authenticated;
grant execute on function public.set_device_active(uuid, boolean) to authenticated;
grant execute on function public.force_release_device(uuid, text) to authenticated;
grant execute on function public.cancel_queue_assignment(uuid, text) to authenticated;
grant execute on function public.import_voters(jsonb) to authenticated;
grant execute on function public.set_queue_order(text[]) to authenticated;
grant execute on function public.save_candidate(uuid, text, text, text, text, boolean) to authenticated;
grant execute on function public.set_election_state(text) to authenticated;
grant execute on function public.set_results_publication(boolean, boolean) to authenticated;
grant execute on function public.admin_record_action(text) to authenticated;
grant execute on function public.get_admin_dashboard() to authenticated;
grant execute on function public.poll_voting_device(text) to anon, authenticated;
grant execute on function public.verify_voter_for_device(text, text) to anon, authenticated;
grant execute on function public.get_candidates_for_device(text, text) to anon, authenticated;
grant execute on function public.cast_vote(text, text, uuid) to anon, authenticated;
grant execute on function public.get_public_results() to anon, authenticated;
grant execute on function public.is_superadmin() to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'audit_log'
    ) then
      alter publication supabase_realtime add table public.audit_log;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'queue_assignments'
    ) then
      alter publication supabase_realtime add table public.queue_assignments;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'voting_devices'
    ) then
      alter publication supabase_realtime add table public.voting_devices;
    end if;
  end if;
end;
$$;

commit;
