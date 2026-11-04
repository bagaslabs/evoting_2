begin;

create or replace function public.get_admin_voter_roster()
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

create function public.add_voter(
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
  v_position bigint;
  v_eligible boolean;
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings where singleton for update;
  if (select election_state from public.election_settings where singleton) <> 'closed' then
    raise exception using errcode = '55000', message = 'Pemilih hanya dapat ditambahkan saat pemilihan ditutup.';
  end if;
  if length(btrim(coalesce(p_nim, ''))) = 0 or length(btrim(coalesce(p_nama, ''))) = 0 then
    raise exception using errcode = '22023', message = 'NIM dan nama wajib diisi.';
  end if;

  v_eligible := btrim(coalesce(p_status_saat_ini, '')) ilike 'Aktif%';
  select coalesce(max(queue_position), 0) + 1 into v_position from public.voters;

  insert into public.voters(
    nim, nama, jenis_kelamin, tanggal_masuk, status_saat_ini,
    eligible, queue_position, queue_state
  )
  values (
    btrim(p_nim), btrim(p_nama), btrim(coalesce(p_jenis_kelamin, '')),
    p_tanggal_masuk, btrim(coalesce(p_status_saat_ini, '')),
    v_eligible, v_position, case when v_eligible then 'waiting' else 'completed' end
  );

  perform public.write_audit('voter_added', jsonb_build_object('queue_position', v_position));
end;
$$;

create function public.delete_voter(p_nim text)
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
    raise exception using errcode = '55000', message = 'Pemilih hanya dapat dihapus saat pemilihan ditutup.';
  end if;

  perform 1 from public.voters where nim = btrim(coalesce(p_nim, '')) for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Pemilih tidak ditemukan.';
  end if;
  if exists (select 1 from public.voters where nim = btrim(p_nim) and has_voted) then
    raise exception using errcode = '55000',
      message = 'Pemilih yang sudah memilih tidak dapat dihapus agar catatan partisipasi tetap akurat.';
  end if;
  if exists (select 1 from public.queue_assignments where nim = btrim(p_nim)) then
    raise exception using errcode = '55000',
      message = 'Pemilih yang pernah mendapat assignment antrean tidak dapat dihapus.';
  end if;

  delete from public.voters where nim = btrim(p_nim);

  select coalesce(max(queue_position), 0) + count(*) + 1
  into v_offset from public.voters;
  update public.voters
  set queue_position = queue_position + v_offset
  where nim is not null;

  with ranked as (
    select nim, row_number() over (order by queue_position) as position
    from public.voters
  )
  update public.voters v
  set queue_position = ranked.position, updated_at = now()
  from ranked
  where v.nim = ranked.nim;

  perform public.write_audit('voter_deleted');
end;
$$;

create function public.assign_next_voter_to_device(p_device_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_state text;
  v_active boolean;
  v_connected boolean;
  v_result jsonb;
begin
  perform public.assert_superadmin();
  select election_state into v_state
  from public.election_settings where singleton for update;
  if v_state <> 'open' then
    raise exception using errcode = '55000', message = 'Antrean hanya dapat diberikan saat pemilihan dibuka.';
  end if;

  select active, last_seen_at >= now() - interval '30 seconds'
  into v_active, v_connected
  from public.voting_devices where id = p_device_id for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Perangkat tidak ditemukan.';
  end if;
  if not v_active then
    raise exception using errcode = '55000', message = 'Perangkat tidak aktif.';
  end if;
  if not coalesce(v_connected, false) then
    raise exception using errcode = '55000', message = 'Perangkat belum terhubung.';
  end if;

  v_result := public.assign_next_to_device(p_device_id);
  perform public.write_audit(
    'admin_next_voter_assigned',
    jsonb_build_object('device_id', p_device_id, 'status', v_result ->> 'status')
  );
  return v_result;
end;
$$;

revoke all on function public.get_admin_voter_roster() from public, anon, authenticated;
revoke all on function public.add_voter(text, text, text, date, text) from public, anon, authenticated;
revoke all on function public.delete_voter(text) from public, anon, authenticated;
revoke all on function public.assign_next_voter_to_device(uuid) from public, anon, authenticated;
grant execute on function public.get_admin_voter_roster() to authenticated;
grant execute on function public.add_voter(text, text, text, date, text) to authenticated;
grant execute on function public.delete_voter(text) to authenticated;
grant execute on function public.assign_next_voter_to_device(uuid) to authenticated;

notify pgrst, 'reload schema';

commit;
