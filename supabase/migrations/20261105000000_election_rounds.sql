begin;

create table if not exists public.election_rounds (
  id uuid primary key default gen_random_uuid(),
  round_number integer not null unique check (round_number > 0),
  title text not null,
  eligible_voters integer check (eligible_voters >= 0),
  results_published boolean not null default false,
  show_public_participation boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.round_candidates (
  round_id uuid not null references public.election_rounds(id) on delete cascade,
  candidate_id uuid not null references public.candidates(id),
  name text not null,
  vision text not null default '',
  mission text not null default '',
  image_url text not null default '',
  enabled boolean not null default true,
  sort_order integer not null,
  primary key (round_id, candidate_id),
  unique (round_id, sort_order)
);

create table if not exists public.round_voter_participation (
  round_id uuid not null references public.election_rounds(id),
  nim text not null references public.voters(nim),
  cast_at timestamptz not null default now(),
  primary key (round_id, nim)
);

alter table public.election_settings
  add column if not exists active_round_id uuid references public.election_rounds(id);
alter table public.ballots
  add column if not exists round_id uuid references public.election_rounds(id);

insert into public.election_rounds(
  round_number, title, results_published, show_public_participation
)
select 1, 'Babak 1', results_published, show_public_participation
from public.election_settings where singleton
on conflict (round_number) do nothing;

update public.election_settings
set active_round_id = (
  select id from public.election_rounds where round_number = 1
)
where singleton;

update public.ballots
set round_id = (select id from public.election_rounds where round_number = 1)
where round_id is null;

alter table public.ballots alter column round_id set not null;
insert into public.round_candidates(
  round_id, candidate_id, name, vision, mission, image_url, enabled, sort_order
)
select r.id, c.id, c.name, c.vision, c.mission, c.image_url, c.active,
  row_number() over (order by c.created_at)::integer
from public.election_rounds r
cross join public.candidates c
where r.round_number = 1
  and (c.active or exists (
    select 1 from public.ballots b where b.candidate_id = c.id
  ))
on conflict (round_id, candidate_id) do nothing;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'ballots_round_candidate_fk'
      and conrelid = 'public.ballots'::regclass
  ) then
    alter table public.ballots add constraint ballots_round_candidate_fk
      foreign key (round_id, candidate_id)
      references public.round_candidates(round_id, candidate_id)
      deferrable initially deferred;
  end if;
end;
$$;

insert into public.round_voter_participation(round_id, nim)
select r.id, v.nim
from public.election_rounds r
cross join public.voters v
where r.round_number = 1 and v.has_voted
on conflict do nothing;

update public.election_settings e
set active_round_id = r.id
from public.election_rounds r
where e.singleton and r.round_number = 1;

update public.election_rounds
set eligible_voters = (select count(*)::integer from public.voters where eligible)
where round_number = 1;

alter table public.election_rounds enable row level security;
alter table public.round_candidates enable row level security;
alter table public.round_voter_participation enable row level security;
revoke all on public.election_rounds, public.round_candidates,
  public.round_voter_participation from public, anon, authenticated;

create or replace function public.create_election_round(p_candidate_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_round_id uuid;
  v_round_number integer;
  v_title text;
  v_candidate_count integer;
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings
  where singleton and election_state = 'closed'
  for update;
  if not found then
    raise exception using errcode = '55000',
      message = 'Babak baru hanya dapat dibuat saat pemilihan ditutup.';
  end if;
  if exists (select 1 from public.queue_assignments where state = 'active') then
    raise exception using errcode = '55000',
      message = 'Selesaikan atau lepaskan assignment aktif sebelum membuat babak.';
  end if;
  if coalesce(cardinality(p_candidate_ids), 0) = 0
     or (select count(distinct id) from unnest(p_candidate_ids) x(id))
        <> cardinality(p_candidate_ids) then
    raise exception using errcode = '22023',
      message = 'Pilih minimal satu kandidat yang berbeda untuk babak ini.';
  end if;
  select count(*) into v_candidate_count
  from public.candidates c
  where c.id = any(p_candidate_ids) and c.active;
  if v_candidate_count <> cardinality(p_candidate_ids) then
    raise exception using errcode = '22023',
      message = 'Daftar berisi kandidat yang tidak aktif atau tidak ditemukan.';
  end if;

  select coalesce(max(round_number), 0) + 1
  into v_round_number from public.election_rounds;
  v_title := 'Babak ' || v_round_number;
  insert into public.election_rounds(round_number, title)
  values (v_round_number, v_title)
  returning id into v_round_id;

  insert into public.round_candidates(
    round_id, candidate_id, name, vision, mission, image_url, enabled, sort_order
  )
  select v_round_id, c.id, c.name, c.vision, c.mission, c.image_url, true,
    row_number() over (order by c.created_at)::integer
  from public.candidates c
  where c.id = any(p_candidate_ids) and c.active;

  update public.election_settings
  set active_round_id = v_round_id,
      results_published = false,
      show_public_participation = false,
      updated_at = now()
  where singleton;
  update public.voters
  set has_voted = exists (
        select 1 from public.round_voter_participation p
        where p.round_id = v_round_id and p.nim = voters.nim
      ),
      queue_state = case when eligible then 'waiting' else 'completed' end,
      updated_at = now()
  where true;

  perform public.write_audit(
    'election_round_created',
    jsonb_build_object('round_number', v_round_number, 'round_id', v_round_id)
  );
  return jsonb_build_object(
    'id', v_round_id, 'round_number', v_round_number, 'title', v_title
  );
end;
$$;

create or replace function public.select_election_round(p_round_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_round public.election_rounds%rowtype;
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings
  where singleton and election_state = 'closed'
  for update;
  if not found then
    raise exception using errcode = '55000',
      message = 'Babak aktif hanya dapat diganti saat pemilihan ditutup.';
  end if;
  if exists (select 1 from public.queue_assignments where state = 'active') then
    raise exception using errcode = '55000',
      message = 'Selesaikan atau lepaskan assignment aktif sebelum mengganti babak.';
  end if;
  select * into v_round from public.election_rounds where id = p_round_id;
  if not found then
    raise exception using errcode = 'P0002', message = 'Babak tidak ditemukan.';
  end if;

  update public.election_settings
  set active_round_id = v_round.id,
      results_published = v_round.results_published,
      show_public_participation = v_round.show_public_participation,
      updated_at = now()
  where singleton;
  update public.voters v
  set has_voted = exists (
        select 1 from public.round_voter_participation p
        where p.round_id = v_round.id and p.nim = v.nim
      ),
      queue_state = case
        when v.eligible and not exists (
          select 1 from public.round_voter_participation p
          where p.round_id = v_round.id and p.nim = v.nim
        ) then 'waiting'
        else 'completed'
      end,
      updated_at = now()
  where true;

  perform public.write_audit(
    'election_round_selected',
    jsonb_build_object('round_number', v_round.round_number)
  );
end;
$$;

create or replace function public.delete_election_round(p_round_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_round public.election_rounds%rowtype;
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings
  where singleton and election_state = 'closed'
  for update;
  if not found then
    raise exception using errcode = '55000',
      message = 'Babak hanya dapat dihapus saat pemilihan ditutup.';
  end if;
  if exists (select 1 from public.queue_assignments where state = 'active') then
    raise exception using errcode = '55000',
      message = 'Selesaikan atau lepaskan assignment aktif sebelum menghapus babak.';
  end if;

  select * into v_round
  from public.election_rounds
  where id = p_round_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Babak tidak ditemukan.';
  end if;
  if exists (
    select 1 from public.election_settings
    where singleton and active_round_id = v_round.id
  ) then
    raise exception using errcode = '55000',
      message = 'Pilih babak lain sebagai babak aktif sebelum menghapus babak ini.';
  end if;
  if exists (
    select 1 from public.ballots where round_id = v_round.id
  ) then
    raise exception using errcode = '55000',
      message = 'Babak yang sudah memiliki suara tidak dapat dihapus agar hasil tetap terjaga.';
  end if;

  delete from public.round_voter_participation
  where round_id = v_round.id;
  delete from public.election_rounds
  where id = v_round.id;

  perform public.write_audit(
    'election_round_deleted',
    jsonb_build_object('round_number', v_round.round_number)
  );
end;
$$;

create or replace function public.set_election_state(p_state text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_settings public.election_settings%rowtype;
begin
  perform public.assert_superadmin();
  select * into v_settings from public.election_settings
  where singleton for update;

  if p_state = 'open' and v_settings.election_state = 'closed' then
    if not exists (select 1 from public.voters where eligible)
       or not exists (
         select 1 from public.round_candidates rc
         where rc.round_id = v_settings.active_round_id
       ) then
      raise exception using errcode = '55000',
        message = 'Tambahkan pemilih eligible dan minimal satu kandidat di babak aktif sebelum membuka pemilihan.';
    end if;
    if not exists (
      select 1 from public.round_voter_participation p
      where p.round_id = v_settings.active_round_id
    ) then
      update public.round_candidates rc
      set name = c.name,
          vision = c.vision,
          mission = c.mission,
          image_url = c.image_url
      from public.candidates c
      where rc.round_id = v_settings.active_round_id
        and rc.candidate_id = c.id;
    end if;
    update public.election_rounds
    set eligible_voters = (
      select count(*)::integer from public.voters where eligible
    )
    where id = v_settings.active_round_id
      and (
        eligible_voters is null
        or not exists (
          select 1 from public.round_voter_participation p
          where p.round_id = v_settings.active_round_id
        )
      );
    update public.voters v
    set has_voted = exists (
          select 1 from public.round_voter_participation p
          where p.round_id = v_settings.active_round_id and p.nim = v.nim
        ),
        queue_state = case
          when v.eligible and not exists (
            select 1 from public.round_voter_participation p
            where p.round_id = v_settings.active_round_id and p.nim = v.nim
          ) then 'waiting'
          else 'completed'
        end,
        updated_at = now()
    where true;
  elsif p_state = 'paused' and v_settings.election_state = 'open' then
    null;
  elsif p_state = 'open' and v_settings.election_state = 'paused' then
    null;
  elsif p_state = 'closed' and v_settings.election_state in ('open', 'paused') then
    update public.queue_assignments
    set state = 'cancelled', completed_at = now()
    where state = 'active';
    update public.voters v
    set queue_state = case
      when v.eligible and not exists (
        select 1 from public.round_voter_participation p
        where p.round_id = v_settings.active_round_id and p.nim = v.nim
      ) then 'waiting'
      else 'completed'
    end,
    updated_at = now()
    where true;
  else
    raise exception using errcode = '55000',
      message = 'Perubahan status pemilihan tidak valid.';
  end if;

  update public.election_settings
  set election_state = p_state, updated_at = now()
  where singleton;
  perform public.write_audit(
    'election_state_changed',
    jsonb_build_object('from', v_settings.election_state, 'to', p_state)
  );
end;
$$;

create or replace function public.add_voter(
  p_nim text,
  p_nama text,
  p_jenis_kelamin text,
  p_tanggal_masuk date,
  p_status_saat_ini text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_round_id uuid;
  v_position bigint;
  v_eligible boolean;
begin
  perform public.assert_superadmin();
  select active_round_id into v_round_id
  from public.election_settings
  where singleton and election_state = 'closed'
  for update;
  if not found then
    raise exception using errcode = '55000',
      message = 'Pemilih hanya dapat ditambahkan saat pemilihan ditutup.';
  end if;
  if exists (
    select 1 from public.round_voter_participation p
    where p.round_id = v_round_id
  ) then
    raise exception using errcode = '55000',
      message = 'Roster tidak dapat diubah setelah ada suara pada babak ini. Buat babak baru untuk melanjutkan.';
  end if;
  if length(btrim(coalesce(p_nim, ''))) = 0
     or length(btrim(coalesce(p_nama, ''))) = 0 then
    raise exception using errcode = '22023', message = 'NIM dan nama wajib diisi.';
  end if;

  v_eligible := btrim(coalesce(p_status_saat_ini, '')) ilike 'Aktif%';
  select coalesce(max(queue_position), 0) + 1
  into v_position from public.voters;
  insert into public.voters(
    nim, nama, jenis_kelamin, tanggal_masuk, status_saat_ini,
    eligible, queue_position, queue_state
  )
  values (
    btrim(p_nim), btrim(p_nama), btrim(coalesce(p_jenis_kelamin, '')),
    p_tanggal_masuk, btrim(coalesce(p_status_saat_ini, '')),
    v_eligible, v_position,
    case when v_eligible then 'waiting' else 'completed' end
  );
  update public.election_rounds
  set eligible_voters = null where id = v_round_id;
  perform public.write_audit(
    'voter_added', jsonb_build_object('queue_position', v_position)
  );
end;
$$;

create or replace function public.set_results_publication(
  p_published boolean, p_show_participation boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_round_id uuid;
begin
  perform public.assert_superadmin();
  select active_round_id into v_round_id
  from public.election_settings where singleton for update;
  if v_round_id is null then
    raise exception using errcode = '55000', message = 'Belum ada babak aktif.';
  end if;
  update public.election_rounds
  set results_published = p_published,
      show_public_participation = p_show_participation
  where id = v_round_id;
  update public.election_settings
  set results_published = p_published,
      show_public_participation = p_show_participation,
      updated_at = now()
  where singleton;
  perform public.write_audit(
    case when p_published then 'results_published' else 'results_hidden' end,
    jsonb_build_object(
      'round_id', v_round_id,
      'show_participation', p_show_participation
    )
  );
end;
$$;

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

create or replace function public.verify_voter_for_device(p_token text, p_nim text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
  v_settings public.election_settings%rowtype;
  v_voter public.voters%rowtype;
  v_assigned_nim text;
begin
  v_device_id := public.lookup_device_id(p_token);
  if v_device_id is null then
    raise exception using errcode = '28000', message = 'Identitas perangkat tidak valid.';
  end if;
  select * into v_settings from public.election_settings
  where singleton for update;
  perform 1 from public.voting_devices
  where id = v_device_id and active for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'device_inactive');
  end if;
  update public.voting_devices set last_seen_at = now() where id = v_device_id;
  if v_settings.election_state <> 'open' then
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
  if exists (
    select 1 from public.round_voter_participation p
    where p.round_id = v_settings.active_round_id and p.nim = v_voter.nim
  ) then
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

create or replace function public.get_candidates_for_device(p_token text, p_nim text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
  v_round_id uuid;
begin
  v_device_id := public.lookup_device_id(p_token);
  if v_device_id is null then
    raise exception using errcode = '28000', message = 'Identitas perangkat tidak valid.';
  end if;
  select active_round_id into v_round_id
  from public.election_settings
  where singleton and election_state = 'open';
  if v_round_id is null or not exists (
    select 1 from public.voting_devices d
    join public.queue_assignments a
      on a.device_id = d.id and a.state = 'active' and a.nim = p_nim
    join public.voters v on v.nim = a.nim and v.eligible
    where d.id = v_device_id and d.active
      and not exists (
        select 1 from public.round_voter_participation p
        where p.round_id = v_round_id and p.nim = v.nim
      )
  ) then
    raise exception using errcode = '42501',
      message = 'Pemilih tidak memiliki assignment aktif pada perangkat ini.';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', rc.candidate_id, 'name', rc.name, 'vision', rc.vision,
      'mission', rc.mission, 'image_url', rc.image_url
    ) order by rc.sort_order)
    from public.round_candidates rc
    where rc.round_id = v_round_id and rc.enabled
  ), '[]'::jsonb);
end;
$$;

create or replace function public.cast_vote(
  p_token text, p_nim text, p_candidate_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device_id uuid;
  v_round_id uuid;
  v_assignment_id uuid;
  v_voter public.voters%rowtype;
begin
  v_device_id := public.lookup_device_id(p_token);
  if v_device_id is null then
    raise exception using errcode = '28000', message = 'Identitas perangkat tidak valid.';
  end if;
  select active_round_id into v_round_id
  from public.election_settings
  where singleton and election_state = 'open'
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'election_not_open');
  end if;
  perform 1 from public.voting_devices
  where id = v_device_id and active for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'device_inactive');
  end if;
  select a.id into v_assignment_id
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
  if exists (
    select 1 from public.round_voter_participation p
    where p.round_id = v_round_id and p.nim = p_nim
  ) then
    return jsonb_build_object('ok', false, 'code', 'already_voted');
  end if;
  if not exists (
    select 1 from public.round_candidates rc
    where rc.round_id = v_round_id
      and rc.candidate_id = p_candidate_id
      and rc.enabled
  ) then
    return jsonb_build_object('ok', false, 'code', 'candidate_unavailable');
  end if;

  insert into public.ballots(round_id, candidate_id)
  values (v_round_id, p_candidate_id);
  insert into public.round_voter_participation(round_id, nim)
  values (v_round_id, p_nim);
  update public.voters
  set has_voted = true, queue_state = 'completed', updated_at = now()
  where nim = p_nim;
  update public.queue_assignments
  set state = 'completed', completed_at = now()
  where id = v_assignment_id;
  update public.voting_devices set last_seen_at = now() where id = v_device_id;
  perform public.write_audit(
    'vote_cast',
    jsonb_build_object('device_id', v_device_id, 'round_id', v_round_id)
  );
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.get_public_results(p_round_number integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_round public.election_rounds%rowtype;
  v_eligible integer;
  v_voted integer;
  v_total integer;
  v_candidates jsonb;
  v_result jsonb;
begin
  select * into v_round from public.election_rounds
  where round_number = p_round_number;
  if not found then
    return jsonb_build_object(
      'published', false,
      'message', 'Babak pemilihan tidak ditemukan.'
    );
  end if;
  if not v_round.results_published then
    return jsonb_build_object(
      'published', false,
      'message', 'Hasil ' || v_round.title || ' belum dipublikasikan.'
    );
  end if;

  select count(*) into v_eligible from public.voters where eligible;
  v_eligible := coalesce(v_round.eligible_voters, v_eligible);
  select count(*) into v_voted
  from public.round_voter_participation p
  where p.round_id = v_round.id;
  select count(*) into v_total from public.ballots where round_id = v_round.id;
  select coalesce(jsonb_agg(jsonb_build_object(
    'name', rc.name,
    'votes', coalesce(b.vote_count, 0),
    'percentage', case when v_total = 0 then 0
      else round(coalesce(b.vote_count, 0)::numeric * 100 / v_total, 2) end
  ) order by rc.sort_order), '[]'::jsonb)
  into v_candidates
  from public.round_candidates rc
  left join (
    select candidate_id, count(*)::integer as vote_count
    from public.ballots where round_id = v_round.id
    group by candidate_id
  ) b on b.candidate_id = rc.candidate_id
  where rc.round_id = v_round.id;

  v_result := jsonb_build_object(
    'published', true,
    'title', v_round.title,
    'total_votes', v_total,
    'candidates', v_candidates
  );
  if v_round.show_public_participation then
    v_result := v_result || jsonb_build_object(
      'participation_percentage',
      case when v_eligible = 0 then 0
        else round(v_voted::numeric * 100 / v_eligible, 2) end
    );
  end if;
  return v_result;
end;
$$;

create or replace function public.get_public_results()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_round_number integer;
begin
  select r.round_number into v_round_number
  from public.election_settings e
  join public.election_rounds r on r.id = e.active_round_id
  where e.singleton;
  if v_round_number is null then
    return jsonb_build_object(
      'published', false,
      'message', 'Belum ada babak pemilihan.'
    );
  end if;
  return public.get_public_results(v_round_number);
end;
$$;

create or replace function public.delete_voter(p_nim text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_offset bigint;
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings where singleton for update;
  if (select election_state from public.election_settings where singleton) <> 'closed' then
    raise exception using errcode = '55000',
      message = 'Pemilih hanya dapat dihapus saat pemilihan ditutup.';
  end if;
  perform 1 from public.voters where nim = btrim(coalesce(p_nim, '')) for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Pemilih tidak ditemukan.';
  end if;
  if exists (
    select 1 from public.round_voter_participation
    where nim = btrim(p_nim)
  ) then
    raise exception using errcode = '55000',
      message = 'Pemilih yang pernah memilih pada babak mana pun tidak dapat dihapus.';
  end if;
  if exists (
    select 1 from public.queue_assignments
    where nim = btrim(p_nim) and state = 'active'
  ) then
    raise exception using errcode = '55000',
      message = 'Lepaskan assignment aktif sebelum menghapus pemilih.';
  end if;
  if exists (
    select 1 from public.queue_assignments where nim = btrim(p_nim)
  ) then
    raise exception using errcode = '55000',
      message = 'Pemilih yang pernah mendapat assignment antrean tidak dapat dihapus.';
  end if;
  delete from public.voters where nim = btrim(p_nim);

  select coalesce(max(queue_position), 0) + count(*) + 1
  into v_offset from public.voters;
  update public.voters
  set queue_position = queue_position + v_offset
  where true;
  with ranked as (
    select nim, row_number() over (order by queue_position) as position
    from public.voters
  )
  update public.voters v
  set queue_position = ranked.position, updated_at = now()
  from ranked where v.nim = ranked.nim;
  perform public.write_audit('voter_deleted');
end;
$$;

revoke all on function public.create_election_round(uuid[]) from public, anon, authenticated;
revoke all on function public.select_election_round(uuid) from public, anon, authenticated;
revoke all on function public.delete_election_round(uuid) from public, anon, authenticated;
revoke all on function public.set_election_state(text) from public, anon, authenticated;
revoke all on function public.set_results_publication(boolean, boolean) from public, anon, authenticated;
revoke all on function public.add_voter(text, text, text, date, text) from public, anon, authenticated;
revoke all on function public.get_admin_dashboard() from public, anon, authenticated;
revoke all on function public.get_admin_voter_roster() from public, anon, authenticated;
revoke all on function public.verify_voter_for_device(text, text) from public, anon, authenticated;
revoke all on function public.get_candidates_for_device(text, text) from public, anon, authenticated;
revoke all on function public.cast_vote(text, text, uuid) from public, anon, authenticated;
revoke all on function public.get_public_results(integer) from public, anon, authenticated;
revoke all on function public.get_public_results() from public, anon, authenticated;
revoke all on function public.delete_voter(text) from public, anon, authenticated;

grant execute on function public.create_election_round(uuid[]) to authenticated;
grant execute on function public.select_election_round(uuid) to authenticated;
grant execute on function public.delete_election_round(uuid) to authenticated;
grant execute on function public.set_election_state(text) to authenticated;
grant execute on function public.set_results_publication(boolean, boolean) to authenticated;
grant execute on function public.add_voter(text, text, text, date, text) to authenticated;
grant execute on function public.get_admin_dashboard() to authenticated;
grant execute on function public.get_admin_voter_roster() to authenticated;
grant execute on function public.verify_voter_for_device(text, text) to anon, authenticated;
grant execute on function public.get_candidates_for_device(text, text) to anon, authenticated;
grant execute on function public.cast_vote(text, text, uuid) to anon, authenticated;
grant execute on function public.get_public_results(integer) to anon, authenticated;
grant execute on function public.get_public_results() to anon, authenticated;
grant execute on function public.delete_voter(text) to authenticated;

notify pgrst, 'reload schema';
commit;
