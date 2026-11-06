begin;

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
    'image_url', rc.image_url,
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
      'participation_voted', v_voted,
      'participation_eligible', v_eligible,
      'participation_percentage',
      case when v_eligible = 0 then 0
        else round(v_voted::numeric * 100 / v_eligible, 2) end
    );
  end if;
  return v_result;
end;
$$;

commit;
