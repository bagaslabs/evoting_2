begin;

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

create or replace function public.set_queue_order(p_nims text[])
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

notify pgrst, 'reload schema';

commit;
