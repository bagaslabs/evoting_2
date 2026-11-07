do $$
begin
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public'
      and indexname = 'queue_assignments_one_active_per_device'
      and indexdef ilike '%unique%'
      and indexdef ilike '%state%'
  ) then
    raise exception 'Missing unique active-assignment constraint per device';
  end if;

  if not exists (
    select 1 from pg_indexes
    where schemaname = 'public'
      and indexname = 'queue_assignments_one_active_per_voter'
      and indexdef ilike '%unique%'
      and indexdef ilike '%state%'
  ) then
    raise exception 'Missing unique active-assignment constraint per voter';
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ballots'
      and column_name in ('nim', 'voter_id', 'device_id', 'assignment_id')
  ) then
    raise exception 'Ballots must not contain voter or device identifiers';
  end if;

  if not (
    select relrowsecurity from pg_class
    where oid = 'public.ballots'::regclass
  ) then
    raise exception 'Row-level security must be enabled for ballots';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ballots'
      and column_name = 'round_id'
  ) then
    raise exception 'Every ballot must be assigned to an election round';
  end if;

  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public'
      and table_name = 'round_voter_participation'
  ) then
    raise exception 'Per-round voter participation must be tracked separately from ballots';
  end if;

  if has_table_privilege('anon', 'public.round_voter_participation', 'select')
     or has_table_privilege('authenticated', 'public.round_voter_participation', 'select') then
    raise exception 'Clients must not be able to read per-round voter participation records';
  end if;

  if has_table_privilege('anon', 'public.ballots', 'select')
     or has_table_privilege('authenticated', 'public.ballots', 'select') then
    raise exception 'Clients must not be able to read individual ballots';
  end if;

  if not has_function_privilege('anon', 'public.get_public_results()', 'execute') then
    raise exception 'Public aggregate results endpoint must be executable by visitors';
  end if;

  if not has_function_privilege('anon', 'public.get_public_results(integer)', 'execute') then
    raise exception 'Public results endpoint for a specific round must be executable by visitors';
  end if;

  if not has_function_privilege('anon', 'public.get_public_current_queue()', 'execute') then
    raise exception 'Public queue status endpoint must be executable by visitors';
  end if;

  if position(
       '''nim''' in pg_get_functiondef('public.get_public_current_queue()'::regprocedure)
     ) > 0
     or position(
       '''voter_name''' in pg_get_functiondef('public.get_public_current_queue()'::regprocedure)
     ) = 0 then
    raise exception 'Public queue endpoint must return voter names but not full NIMs';
  end if;

  if position(
       'right(v.nim, 3)' in
       lower(pg_get_functiondef('public.get_public_current_queue()'::regprocedure))
     ) = 0 then
    raise exception 'Public queue endpoint must return only the final three NIM digits';
  end if;

  if position(
       '[1:2]' in
       pg_get_functiondef('public.get_public_current_queue()'::regprocedure)
     ) = 0 then
    raise exception 'Public queue endpoint must return at most two words of the voter name';
  end if;

  if position(
       '''waiting_for_voter''' in
       pg_get_functiondef('public.get_public_current_queue()'::regprocedure)
     ) = 0
     or position(
       'left join public.voting_devices' in
       lower(pg_get_functiondef('public.get_public_current_queue()'::regprocedure))
     ) = 0 then
    raise exception 'Public queue must keep active device booths visible while no voter is assigned';
  end if;

  if position(
       'no_assignment' in
       lower(pg_get_functiondef('public.verify_voter_for_device(text,text)'::regprocedure))
     ) > 0
     or position(
       'nim_mismatch' in
       lower(pg_get_functiondef('public.cast_vote(text,text,uuid)'::regprocedure))
     ) > 0 then
    raise exception 'Voting must not be restricted to the device queue assignment';
  end if;

  if position(
       'right(v.nim, 3)' in
       lower(pg_get_functiondef('public.verify_voter_for_device(text,text)'::regprocedure))
     ) = 0
     or position(
       'nim_ambiguous' in
       lower(pg_get_functiondef('public.verify_voter_for_device(text,text)'::regprocedure))
     ) = 0 then
    raise exception 'Device voter verification must use the final three NIM digits and return matches for ambiguous suffixes';
  end if;

  if has_function_privilege('anon', 'public.create_election_round(text,uuid[])', 'execute')
     or has_function_privilege('anon', 'public.select_election_round(uuid)', 'execute')
     or has_function_privilege('anon', 'public.delete_election_round(uuid)', 'execute') then
    raise exception 'Anonymous users must not be able to create, switch, or delete election rounds';
  end if;

  if not has_function_privilege('authenticated', 'public.create_election_round(text,uuid[])', 'execute')
     or not has_function_privilege('authenticated', 'public.rename_election_round(uuid,text)', 'execute') then
    raise exception 'Authenticated admins must be able to create and rename election rounds';
  end if;

  if has_function_privilege('anon', 'public.delete_voting_device(uuid)', 'execute')
     or not has_function_privilege('authenticated', 'public.delete_voting_device(uuid)', 'execute') then
    raise exception 'Only authenticated admins may delete voting devices';
  end if;

  if position(
       'delete from public.queue_assignments' in
       lower(pg_get_functiondef('public.delete_voting_device(uuid)'::regprocedure))
     ) = 0 then
    raise exception 'Deleting a voting device must remove its assignment history';
  end if;

  if position(
       'delete from public.ballots' in
       lower(pg_get_functiondef('public.delete_election_round(uuid)'::regprocedure))
     ) = 0 then
    raise exception 'Deleting an election round must remove its ballots';
  end if;

  if position(
       'pilih babak lain sebagai babak aktif' in
       lower(pg_get_functiondef('public.delete_election_round(uuid)'::regprocedure))
     ) > 0 then
    raise exception 'Deleting the active election round must be allowed';
  end if;

  if has_function_privilege('anon', 'public.get_admin_dashboard()', 'execute') then
    raise exception 'Anonymous users must not be able to call the admin dashboard';
  end if;

  if has_function_privilege('anon', 'public.rotate_voting_device_token(uuid)', 'execute') then
    raise exception 'Anonymous users must not be able to rotate device tokens';
  end if;

  if has_function_privilege('anon', 'public.get_voting_device_tokens()', 'execute') then
    raise exception 'Anonymous users must not be able to read device tokens';
  end if;

  if not has_function_privilege('authenticated', 'public.rotate_voting_device_token(uuid)', 'execute') then
    raise exception 'Authenticated admins must be able to rotate device tokens';
  end if;

  if not has_function_privilege('authenticated', 'public.get_voting_device_tokens()', 'execute') then
    raise exception 'Authenticated admins must be able to read device tokens';
  end if;

  if has_function_privilege('anon', 'public.get_admin_voter_roster()', 'execute') then
    raise exception 'Anonymous users must not be able to read the admin voter roster';
  end if;

  if has_function_privilege('anon', 'public.get_admin_queue_board()', 'execute')
     or not has_function_privilege('authenticated', 'public.get_admin_queue_board()', 'execute') then
    raise exception 'Only authenticated admins may read the device queue board';
  end if;

  if not has_function_privilege('authenticated', 'public.get_admin_voter_roster()', 'execute') then
    raise exception 'Authenticated admins must be able to read the voter roster';
  end if;

  if has_table_privilege('anon', 'public.voters', 'select')
     or has_table_privilege('authenticated', 'public.voters', 'select') then
    raise exception 'Clients must not directly read the voter roster table';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'voters'
      and column_name = 'queue_device_id'
  ) then
    raise exception 'Waiting voters must be assigned to a device lane';
  end if;

  if position(
       'v.queue_device_id = p_device_id'
       in lower(pg_get_functiondef('public.assign_next_to_device(uuid)'::regprocedure))
     ) > 0
     or position(
       'order by v.queue_position'
       in lower(pg_get_functiondef('public.assign_next_to_device(uuid)'::regprocedure))
     ) = 0 then
    raise exception 'An empty device must assign the next globally ordered waiting voter';
  end if;

  if has_function_privilege('anon', 'public.set_voter_eligibility(text,boolean)', 'execute')
     or not has_function_privilege('authenticated', 'public.set_voter_eligibility(text,boolean)', 'execute') then
    raise exception 'Only authenticated admins may change voter eligibility';
  end if;

  if pg_get_functiondef('public.get_admin_voter_roster()'::regprocedure) ilike '%ballots%' then
    raise exception 'The admin voter roster must not read individual ballots';
  end if;

  if has_function_privilege('anon', 'public.add_voter(text,text,text,date,text)', 'execute')
     or has_function_privilege('anon', 'public.delete_voter(text)', 'execute')
     or has_function_privilege('anon', 'public.delete_all_voters()', 'execute')
     or has_function_privilege('anon', 'public.set_voter_eligibility(text,boolean)', 'execute')
     or has_function_privilege('anon', 'public.assign_next_voter_to_device(uuid)', 'execute') then
    raise exception 'Anonymous users must not be able to modify voter records or queue assignments';
  end if;

  if not has_function_privilege('authenticated', 'public.add_voter(text,text,text,date,text)', 'execute')
     or not has_function_privilege('authenticated', 'public.delete_voter(text)', 'execute')
     or not has_function_privilege('authenticated', 'public.delete_all_voters()', 'execute')
     or not has_function_privilege('authenticated', 'public.set_voter_eligibility(text,boolean)', 'execute')
     or not has_function_privilege('authenticated', 'public.assign_next_voter_to_device(uuid)', 'execute') then
    raise exception 'Authenticated admins must be able to manage voters and next-device assignments';
  end if;

  if has_function_privilege('anon', 'public.assign_next_to_device(uuid)', 'execute') then
    raise exception 'Anonymous users must not be able to directly assign voters to a device';
  end if;

  if has_table_privilege('authenticated', 'vault.decrypted_secrets', 'select') then
    raise exception 'Authenticated users must not directly read decrypted Vault secrets';
  end if;

  if has_function_privilege('anon', 'public.poll_voting_device(text)', 'execute')
     or has_function_privilege('anon', 'public.verify_voter_for_device(text,text)', 'execute')
     or has_function_privilege('anon', 'public.get_candidates_for_device(text,text)', 'execute')
     or has_function_privilege('anon', 'public.cast_vote(text,text,uuid)', 'execute') then
    raise exception 'Device RPCs without a client binding must not be callable anonymously';
  end if;

  if has_function_privilege('anon', 'public.claim_voting_device(text,uuid)', 'execute') then
    raise exception 'Anonymous users must not be able to claim device tokens directly';
  end if;

  if not has_function_privilege('anon', 'public.poll_voting_device(text,uuid)', 'execute')
     or not has_function_privilege('anon', 'public.verify_voter_for_device(text,uuid,text)', 'execute')
     or not has_function_privilege('anon', 'public.get_candidates_for_device(text,uuid,text)', 'execute')
     or not has_function_privilege('anon', 'public.cast_vote(text,uuid,text,uuid)', 'execute') then
    raise exception 'Client-bound device RPCs must be reachable by their token-authenticated client';
  end if;
end;
$$;

do $$
declare
  v_token text := encode(extensions.gen_random_bytes(32), 'hex');
  v_device_id uuid;
  v_client_id uuid := gen_random_uuid();
  v_other_client_id uuid := gen_random_uuid();
begin
  insert into public.voting_devices(name, token_hash)
  values ('device binding contract test', extensions.digest(v_token, 'sha256'))
  returning id into v_device_id;

  perform public.claim_voting_device(v_token, v_client_id);
  perform public.claim_voting_device(v_token, v_client_id);

  begin
    perform public.claim_voting_device(v_token, v_other_client_id);
    raise exception 'A token was claimed by more than one device';
  exception when sqlstate '55000' then
    null;
  end;

  if not exists (
    select 1 from public.voting_devices
    where id = v_device_id and device_client_id = v_client_id
  ) then
    raise exception 'The first client must retain its token binding';
  end if;

  update public.voting_devices
  set token_hash = extensions.digest(v_token || 'rotated', 'sha256')
  where id = v_device_id;

  if exists (
    select 1 from public.voting_devices
    where id = v_device_id and device_client_id is not null
  ) then
    raise exception 'Rotating a token must clear its previous client binding';
  end if;

  delete from public.voting_devices where id = v_device_id;
end;
$$;
