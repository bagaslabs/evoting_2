begin;

create or replace function public.get_admin_round_archive(p_round_number integer)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_round public.election_rounds%rowtype;
  v_ballots integer;
  v_voted integer;
  v_eligible_not_voted integer;
  v_non_eligible integer;
  v_candidates jsonb;
  v_voters_voted jsonb;
  v_voters_eligible_not_voted jsonb;
  v_voters_non_eligible jsonb;
begin
  perform public.assert_superadmin();

  select * into v_round
  from public.election_rounds
  where round_number = p_round_number;

  if not found then
    raise exception using errcode = 'P0002', message = 'Babak pemilihan tidak ditemukan.';
  end if;

  select count(*)::integer into v_ballots
  from public.ballots b where b.round_id = v_round.id;

  select count(*)::integer into v_voted
  from public.round_voter_participation p where p.round_id = v_round.id;

  select count(*)::integer into v_eligible_not_voted
  from public.voters v
  where v.eligible and not exists (
    select 1 from public.round_voter_participation p
    where p.round_id = v_round.id and p.nim = v.nim
  );

  select count(*)::integer into v_non_eligible
  from public.voters v where not v.eligible;

  select coalesce(jsonb_agg(jsonb_build_object(
    'name', rc.name,
    'votes', coalesce(b.vote_count, 0),
    'percentage', case when v_ballots = 0 then 0
      else round(coalesce(b.vote_count, 0)::numeric * 100 / v_ballots, 2) end
  ) order by rc.sort_order), '[]'::jsonb)
  into v_candidates
  from public.round_candidates rc
  left join (
    select candidate_id, count(*)::integer as vote_count
    from public.ballots where round_id = v_round.id
    group by candidate_id
  ) b on b.candidate_id = rc.candidate_id
  where rc.round_id = v_round.id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'nama', v.nama, 'nim', v.nim, 'eligible_now', v.eligible,
    'cast_at', p.cast_at
  ) order by v.nama, v.nim), '[]'::jsonb)
  into v_voters_voted
  from public.round_voter_participation p
  join public.voters v on v.nim = p.nim
  where p.round_id = v_round.id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'nama', v.nama, 'nim', v.nim
  ) order by v.nama, v.nim), '[]'::jsonb)
  into v_voters_eligible_not_voted
  from public.voters v
  where v.eligible and not exists (
    select 1 from public.round_voter_participation p
    where p.round_id = v_round.id and p.nim = v.nim
  );

  select coalesce(jsonb_agg(jsonb_build_object(
    'nama', v.nama, 'nim', v.nim
  ) order by v.nama, v.nim), '[]'::jsonb)
  into v_voters_non_eligible
  from public.voters v where not v.eligible;

  return jsonb_build_object(
    'round', jsonb_build_object(
      'number', v_round.round_number,
      'title', v_round.title,
      'created_at', v_round.created_at,
      'eligible_voters_at_start', v_round.eligible_voters
    ),
    'totals', jsonb_build_object(
      'ballots', v_ballots,
      'voted', v_voted,
      'eligible_not_voted', v_eligible_not_voted,
      'non_eligible', v_non_eligible
    ),
    'candidates', v_candidates,
    'voters', jsonb_build_object(
      'voted', v_voters_voted,
      'eligible_not_voted', v_voters_eligible_not_voted,
      'non_eligible', v_voters_non_eligible
    ),
    'eligibility_note',
      'Status eligible dan daftar roster menunjukkan keadaan saat arsip dibuat. Babak ini hanya menyimpan jumlah eligible saat pemilihan dibuka, bukan snapshot status per pemilih.'
  );
end;
$$;

revoke all on function public.get_admin_round_archive(integer) from public, anon, authenticated;
grant execute on function public.get_admin_round_archive(integer) to authenticated;

commit;
