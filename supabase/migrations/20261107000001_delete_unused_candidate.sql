begin;

create function public.delete_candidate(p_candidate_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
begin
  perform public.assert_superadmin();
  perform 1 from public.election_settings
  where singleton and election_state = 'closed'
  for update;
  if not found then
    raise exception using errcode = '55000',
      message = 'Kandidat hanya dapat dihapus saat pemilihan ditutup.';
  end if;

  select name into v_name
  from public.candidates
  where id = p_candidate_id
  for update;
  if not found then
    raise exception using errcode = 'P0002',
      message = 'Kandidat tidak ditemukan.';
  end if;

  if exists (
    select 1 from public.ballots where candidate_id = p_candidate_id
  ) then
    raise exception using errcode = '55000',
      message = 'Kandidat yang sudah memiliki suara tidak dapat dihapus. Nonaktifkan kandidat agar hasil tetap utuh.';
  end if;

  if exists (
    select 1 from public.round_candidates where candidate_id = p_candidate_id
  ) then
    raise exception using errcode = '55000',
      message = 'Kandidat sudah pernah dipakai dalam babak pemilihan dan tidak dapat dihapus. Nonaktifkan kandidat agar riwayat tetap utuh.';
  end if;

  delete from public.candidates where id = p_candidate_id;

  perform public.write_audit(
    'candidate_deleted',
    jsonb_build_object('candidate_id', p_candidate_id, 'name', v_name)
  );
end;
$$;

revoke all on function public.delete_candidate(uuid)
  from public, anon, authenticated;
grant execute on function public.delete_candidate(uuid)
  to authenticated;

notify pgrst, 'reload schema';
commit;
