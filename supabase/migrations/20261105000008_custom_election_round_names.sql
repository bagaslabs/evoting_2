begin;

drop function if exists public.create_election_round(uuid[]);

create function public.create_election_round(
  p_title text,
  p_candidate_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_round_id uuid;
  v_round_number integer;
  v_title text := btrim(p_title);
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
  if v_title is null or length(v_title) = 0 or length(v_title) > 80 then
    raise exception using errcode = '22023',
      message = 'Nama babak wajib diisi dan maksimal 80 karakter.';
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
    jsonb_build_object(
      'round_number', v_round_number,
      'round_id', v_round_id,
      'title', v_title
    )
  );
  return jsonb_build_object(
    'id', v_round_id,
    'round_number', v_round_number,
    'title', v_title
  );
end;
$$;

create or replace function public.rename_election_round(
  p_round_id uuid,
  p_title text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_title text := btrim(p_title);
  v_round public.election_rounds%rowtype;
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings
  where singleton and election_state = 'closed'
  for update;
  if not found then
    raise exception using errcode = '55000',
      message = 'Nama babak hanya dapat diubah saat pemilihan ditutup.';
  end if;
  if exists (select 1 from public.queue_assignments where state = 'active') then
    raise exception using errcode = '55000',
      message = 'Selesaikan atau lepaskan assignment aktif sebelum mengubah nama babak.';
  end if;
  if v_title is null or length(v_title) = 0 or length(v_title) > 80 then
    raise exception using errcode = '22023',
      message = 'Nama babak wajib diisi dan maksimal 80 karakter.';
  end if;

  select * into v_round
  from public.election_rounds
  where id = p_round_id
  for update;
  if not found then
    raise exception using errcode = 'P0002',
      message = 'Babak tidak ditemukan.';
  end if;

  update public.election_rounds
  set title = v_title
  where id = v_round.id;

  perform public.write_audit(
    'election_round_renamed',
    jsonb_build_object(
      'round_number', v_round.round_number,
      'previous_title', v_round.title,
      'title', v_title
    )
  );
end;
$$;

revoke all on function public.create_election_round(text, uuid[])
  from public, anon, authenticated;
grant execute on function public.create_election_round(text, uuid[])
  to authenticated;
revoke all on function public.rename_election_round(uuid, text)
  from public, anon, authenticated;
grant execute on function public.rename_election_round(uuid, text)
  to authenticated;

notify pgrst, 'reload schema';
commit;
