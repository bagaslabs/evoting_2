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

  if has_table_privilege('anon', 'public.ballots', 'select')
     or has_table_privilege('authenticated', 'public.ballots', 'select') then
    raise exception 'Clients must not be able to read individual ballots';
  end if;

  if not has_function_privilege('anon', 'public.get_public_results()', 'execute') then
    raise exception 'Public aggregate results endpoint must be executable by visitors';
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

  if not has_function_privilege('authenticated', 'public.get_admin_voter_roster()', 'execute') then
    raise exception 'Authenticated admins must be able to read the voter roster';
  end if;

  if pg_get_functiondef('public.get_admin_voter_roster()'::regprocedure) ilike '%ballots%' then
    raise exception 'The admin voter roster must not read individual ballots';
  end if;

  if has_function_privilege('anon', 'public.add_voter(text,text,text,date,text)', 'execute')
     or has_function_privilege('anon', 'public.delete_voter(text)', 'execute')
     or has_function_privilege('anon', 'public.assign_next_voter_to_device(uuid)', 'execute') then
    raise exception 'Anonymous users must not be able to modify voter records or queue assignments';
  end if;

  if not has_function_privilege('authenticated', 'public.add_voter(text,text,text,date,text)', 'execute')
     or not has_function_privilege('authenticated', 'public.delete_voter(text)', 'execute')
     or not has_function_privilege('authenticated', 'public.assign_next_voter_to_device(uuid)', 'execute') then
    raise exception 'Authenticated admins must be able to manage voters and next-device assignments';
  end if;

  if has_table_privilege('authenticated', 'vault.decrypted_secrets', 'select') then
    raise exception 'Authenticated users must not directly read decrypted Vault secrets';
  end if;

  if not has_function_privilege('anon', 'public.cast_vote(text,text,uuid)', 'execute') then
    raise exception 'Registered device voting RPC must be reachable by its token-authenticated client';
  end if;
end;
$$;
