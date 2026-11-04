begin;

alter table public.voting_devices
  add column token_secret_id uuid;

create unique index voting_devices_token_secret_id_unique
  on public.voting_devices(token_secret_id)
  where token_secret_id is not null;

revoke all on schema vault from public, anon, authenticated;
revoke all on table vault.secrets, vault.decrypted_secrets from public, anon, authenticated;

create or replace function public.create_voting_device(p_name text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text := encode(extensions.gen_random_bytes(32), 'hex');
  v_device_id uuid;
  v_secret_id uuid;
begin
  perform public.assert_superadmin();
  if length(btrim(coalesce(p_name, ''))) = 0 then
    raise exception using errcode = '22023', message = 'Nama perangkat wajib diisi.';
  end if;

  insert into public.voting_devices(name, token_hash)
  values (btrim(p_name), extensions.digest(v_token, 'sha256'))
  returning id into v_device_id;

  v_secret_id := vault.create_secret(
    v_token,
    'voting_device_token_' || v_device_id::text,
    'Token perangkat voting ' || btrim(p_name)
  );
  update public.voting_devices
  set token_secret_id = v_secret_id
  where id = v_device_id;

  perform public.write_audit('device_created', jsonb_build_object('device_id', v_device_id));
  return jsonb_build_object('device_id', v_device_id, 'name', btrim(p_name));
end;
$$;

create function public.rotate_voting_device_token(p_device_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_token text := encode(extensions.gen_random_bytes(32), 'hex');
  v_name text;
  v_secret_id uuid;
begin
  perform public.assert_superadmin();

  select d.name, d.token_secret_id into v_name, v_secret_id
  from public.voting_devices d
  where d.id = p_device_id
  for update;
  if not found then
    raise exception using errcode = 'P0002', message = 'Perangkat tidak ditemukan.';
  end if;

  if v_secret_id is null then
    v_secret_id := vault.create_secret(
      v_token,
      'voting_device_token_' || p_device_id::text,
      'Token perangkat voting ' || v_name
    );
  else
    perform vault.update_secret(
      v_secret_id,
      v_token,
      'voting_device_token_' || p_device_id::text,
      'Token perangkat voting ' || v_name
    );
  end if;

  update public.voting_devices
  set token_hash = extensions.digest(v_token, 'sha256'),
      token_secret_id = v_secret_id
  where id = p_device_id;

  perform public.write_audit(
    'device_token_rotated',
    jsonb_build_object('device_id', p_device_id)
  );
end;
$$;

create function public.get_voting_device_tokens()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_tokens jsonb;
begin
  perform public.assert_superadmin();

  select coalesce(jsonb_agg(jsonb_build_object(
    'device_id', d.id,
    'token', s.decrypted_secret
  ) order by d.created_at), '[]'::jsonb)
  into v_tokens
  from public.voting_devices d
  left join vault.decrypted_secrets s on s.id = d.token_secret_id;

  return v_tokens;
end;
$$;

revoke all on function public.create_voting_device(text) from public, anon, authenticated;
revoke all on function public.rotate_voting_device_token(uuid) from public, anon, authenticated;
revoke all on function public.get_voting_device_tokens() from public, anon, authenticated;
grant execute on function public.create_voting_device(text) to authenticated;
grant execute on function public.rotate_voting_device_token(uuid) to authenticated;
grant execute on function public.get_voting_device_tokens() to authenticated;

notify pgrst, 'reload schema';

commit;
