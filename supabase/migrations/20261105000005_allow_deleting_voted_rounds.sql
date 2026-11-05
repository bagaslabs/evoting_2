begin;

create or replace function public.delete_election_round(p_round_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_round public.election_rounds%rowtype;
  v_ballot_count integer;
  v_participation_count integer;
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
