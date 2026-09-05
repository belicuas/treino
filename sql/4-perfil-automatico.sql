-- ============================================================
-- FitTrack — PERFIL AUTOMÁTICO NO CADASTRO
--
-- POR QUE ISSO EXISTE
-- Com a confirmação de email ligada, o signUp não devolve sessão.
-- Sem sessão o cliente é "anon", e as políticas exigem "authenticated" —
-- então a gravação do perfil no cadastro falha silenciosamente
-- (o app engole o erro num catch vazio).
-- O usuário confirmaria o email, faria login, e o app quebraria em
-- enterApp() ao ler o nome de um perfil que não existe.
--
-- A correção é o banco criar o perfil quando o login nasce, e não o
-- navegador. É o padrão do Supabase (handle_new_user).
-- ============================================================


-- ------------------------------------------------------------
-- 1) AJUSTE NO GUARDA DE INSERT
-- Ele forçava auth_id = auth.uid() em toda inserção. Quando quem
-- insere é um trigger do sistema, auth.uid() é NULL — o que apagaria
-- justamente o vínculo que estamos criando. Agora só sobrescreve
-- quando há um usuário autenticado de verdade.
-- ------------------------------------------------------------
create or replace function public.fittrack_users_guard_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.fittrack_is_admin() then
    return new;
  end if;
  new.role   := 'user';
  new.status := 'pending';
  if auth.uid() is not null then
    new.auth_id := auth.uid();
  end if;
  new.data := jsonb_set(
                jsonb_set(coalesce(new.data,'{}'::jsonb), '{role}',   '"user"',    true),
                '{status}', '"pending"', true);
  return new;
end;
$$;


-- ------------------------------------------------------------
-- 2) CRIA O PERFIL QUANDO O LOGIN É CRIADO
-- Roda em auth.users, com o mesmo formato de objeto que o app espera
-- (os arrays vazios evitam erro de leitura na interface).
-- ------------------------------------------------------------
create or replace function public.fittrack_handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  uname text;
  nome  text;
begin
  uname := nullif(trim(new.raw_user_meta_data->>'username'), '');
  if uname is null then
    uname := split_part(new.email, '@', 1);
  end if;

  -- username é chave primária: garante unicidade sem derrubar o cadastro
  if exists (select 1 from fittrack_users where username = uname) then
    uname := uname || '_' || substr(replace(new.id::text,'-',''), 1, 4);
  end if;

  nome := coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), uname);

  insert into fittrack_users (username, auth_id, role, status, data)
  values (
    uname, new.id, 'user', 'pending',
    jsonb_build_object(
      'name',              nome,
      'email',             new.email,
      'role',              'user',
      'status',            'pending',
      'authId',            new.id::text,
      'workouts',          '[]'::jsonb,
      'completedSessions', '[]'::jsonb,
      'loads',             '{}'::jsonb,
      'weights',           '[]'::jsonb,
      'friends',           '[]'::jsonb,
      'coaches',           '[]'::jsonb,
      'students',          '[]'::jsonb,
      'coachRequests',     '[]'::jsonb,
      'coachRequestsSent', '[]'::jsonb
    )
  )
  on conflict (username) do nothing;

  return new;
end;
$$;

drop trigger if exists trg_fittrack_new_user on auth.users;
create trigger trg_fittrack_new_user
  after insert on auth.users
  for each row execute function public.fittrack_handle_new_user();


-- ------------------------------------------------------------
-- 3) REPARA LOGINS ÓRFÃOS
-- Se algum login já existe sem perfil correspondente, cria agora.
-- ------------------------------------------------------------
insert into fittrack_users (username, auth_id, role, status, data)
select
  coalesce(nullif(trim(u.raw_user_meta_data->>'username'),''), split_part(u.email,'@',1)),
  u.id, 'user', 'pending',
  jsonb_build_object(
    'name',              coalesce(nullif(trim(u.raw_user_meta_data->>'name'),''), split_part(u.email,'@',1)),
    'email',             u.email,
    'role',              'user',
    'status',            'pending',
    'authId',            u.id::text,
    'workouts',          '[]'::jsonb,
    'completedSessions', '[]'::jsonb,
    'loads',             '{}'::jsonb,
    'weights',           '[]'::jsonb,
    'friends',           '[]'::jsonb,
    'coaches',           '[]'::jsonb,
    'students',          '[]'::jsonb,
    'coachRequests',     '[]'::jsonb,
    'coachRequestsSent', '[]'::jsonb
  )
from auth.users u
where not exists (select 1 from fittrack_users f where f.auth_id = u.id)
on conflict (username) do nothing;


-- Conferência
select username, role, status, (auth_id is not null) as tem_login
from fittrack_users order by username;
