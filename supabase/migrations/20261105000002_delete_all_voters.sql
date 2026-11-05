begin;

create or replace function public.delete_all_voters()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted_count integer;
  v_election_state text;
begin
  perform public.assert_superadmin();
  select election_state into v_election_state
  from public.election_settings
  where singleton
  for update;
  if not found or v_election_state <> 'closed' then
    raise exception using errcode = '55000',
      message = 'Semua pemilih hanya dapat dihapus saat pemilihan ditutup.';
  end if;

  delete from public.round_voter_participation
  where nim in (select nim from public.voters);
  delete from public.queue_assignments
  where nim in (select nim from public.voters);
  delete from public.voters
  where true;
  get diagnostics v_deleted_count = row_count;

  perform public.write_audit(
    'all_voters_deleted',
    jsonb_build_object(
      'deleted_count', v_deleted_count,
      'anonymous_ballots_preserved', true
    )
  );
  return v_deleted_count;
end;
$$;

revoke all on function public.delete_all_voters() from public, anon, authenticated;
grant execute on function public.delete_all_voters() to authenticated;

notify pgrst, 'reload schema';
commit;
