begin;

create or replace function public.delete_election_round(p_round_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_round public.election_rounds%rowtype;
  v_next_round public.election_rounds%rowtype;
  v_ballot_count integer;
  v_participation_count integer;
  v_was_active boolean;
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

  select active_round_id = v_round.id into v_was_active
  from public.election_settings
  where singleton;

  select * into v_next_round
  from public.election_rounds
  where id <> v_round.id
  order by round_number desc
  limit 1;

  if v_was_active then
    update public.election_settings
    set active_round_id = v_next_round.id,
        results_published = coalesce(v_next_round.results_published, false),
        show_public_participation = coalesce(v_next_round.show_public_participation, false),
        updated_at = now()
    where singleton;

    update public.voters v
    set has_voted = exists (
          select 1 from public.round_voter_participation p
          where p.round_id = v_next_round.id and p.nim = v.nim
        ),
        queue_state = case
          when v.eligible and not exists (
            select 1 from public.round_voter_participation p
            where p.round_id = v_next_round.id and p.nim = v.nim
          ) then 'waiting'
          else 'completed'
        end,
        updated_at = now()
    where true;
  end if;

  select count(*) into v_ballot_count
  from public.ballots
  where round_id = v_round.id;
  select count(*) into v_participation_count
  from public.round_voter_participation
  where round_id = v_round.id;

  delete from public.ballots
  where round_id = v_round.id;
  delete from public.round_voter_participation
  where round_id = v_round.id;
  delete from public.election_rounds
  where id = v_round.id;

  perform public.write_audit(
    'election_round_deleted',
    jsonb_build_object(
      'round_number', v_round.round_number,
      'was_active', v_was_active,
      'activated_round_number', v_next_round.round_number,
      'ballots_deleted', v_ballot_count,
      'participation_records_deleted', v_participation_count
    )
  );
end;
$$;

revoke all on function public.delete_election_round(uuid)
  from public, anon, authenticated;
grant execute on function public.delete_election_round(uuid)
  to authenticated;

notify pgrst, 'reload schema';
commit;
