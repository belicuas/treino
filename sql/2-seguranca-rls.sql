-- ============================================================
-- FitTrack — CORREÇÃO DE SEGURANÇA (RLS)
-- Cole TUDO no SQL Editor do Supabase e clique em RUN.
-- Não é preciso mudar o index.html: o app continua funcionando igual.
--
-- O QUE ISSO CONSERTA
-- Antes, a política era "logados atualizam usuarios ... using(true)":
-- qualquer pessoa com conta podia falar direto com a API do Supabase
-- (fora do app) e editar QUALQUER usuário — inclusive virar admin.
-- A checagem de permissão vivia só no JavaScript, e JavaScript no
-- navegador do usuário não é uma fronteira de segurança.
--
-- Agora quem decide é o banco.
-- ============================================================


-- ------------------------------------------------------------
-- 1) COLUNAS DE VERDADE
-- role e status passam a existir como colunas reais. O jsonb "data"
-- continua tendo as cópias (o app lê de lá), mas quem manda é a coluna.
-- ------------------------------------------------------------
alter table fittrack_users add column if not exists role   text not null default 'user';
alter table fittrack_users add column if not exists status text not null default 'pending';

-- traz o que já existe no jsonb para as colunas novas
update fittrack_users set
  role   = coalesce(nullif(data->>'role',''),   'user'),
  status = coalesce(nullif(data->>'status',''), 'pending');


-- ------------------------------------------------------------
-- 2) FUNÇÕES AUXILIARES
-- SECURITY DEFINER: rodam por fora do RLS, senão a política que
-- consulta a tabela entraria em recursão infinita.
-- ------------------------------------------------------------
create or replace function public.fittrack_is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from fittrack_users
    where auth_id = auth.uid() and role = 'admin'
  );
$$;

-- username de quem está fazendo a requisição
create or replace function public.fittrack_me()
returns text language sql stable security definer set search_path = public as $$
  select username from fittrack_users where auth_id = auth.uid() limit 1;
$$;


-- ------------------------------------------------------------
-- 3) O GUARDA — impede escalada de privilégio
--
-- Regras aplicadas em toda atualização de fittrack_users:
--   • admin        -> pode tudo (precisa disso para aprovar/bloquear)
--   • dono da linha-> edita os próprios dados, MENOS role/status/auth_id
--   • terceiro     -> só encosta em 6 campos (pedido de treinador,
--                     amizade, alunos e montar treino). O resto da
--                     linha volta ao valor original, mesmo que ele
--                     tente sobrescrever.
--
-- Resultado: ninguém se promove a admin, ninguém se auto-aprova,
-- ninguém sequestra a conta de outro, e histórico de treino, peso,
-- nome e email ficam protegidos de terceiros.
-- ------------------------------------------------------------
create or replace function public.fittrack_users_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  -- únicos campos que outra pessoa pode escrever na sua linha
  campos_de_terceiros text[] := array[
    'coachRequests', 'coachRequestsSent', 'friends', 'coaches', 'students', 'workouts'
  ];
  eh_dono  boolean;
  eh_admin boolean;
  k        text;
  d        jsonb;
begin
  eh_admin := public.fittrack_is_admin();
  if eh_admin then
    return new;                     -- admin não é filtrado
  end if;

  eh_dono := (old.auth_id is not null and old.auth_id = auth.uid());

  -- Linha antiga sem auth_id (contas criadas antes do login existir):
  -- o usuário pode reivindicá-la SOMENTE se o email bater com o do
  -- login autenticado. Sem essa checagem, qualquer um adotaria a
  -- linha do admin.
  if old.auth_id is null
     and lower(coalesce(old.data->>'email','')) = lower(coalesce(auth.jwt()->>'email','#'))
  then
    new.auth_id := auth.uid();
    eh_dono := true;
  else
    new.auth_id := old.auth_id;     -- ninguém mais mexe no vínculo
  end if;

  -- role e status só mudam pela mão do admin
  new.role   := old.role;
  new.status := old.status;

  if eh_dono then
    d := new.data;
  else
    -- terceiro: parte da linha ORIGINAL e aplica só a allowlist
    d := old.data;
    foreach k in array campos_de_terceiros loop
      if jsonb_exists(new.data, k) then
        d := jsonb_set(d, array[k], new.data -> k, true);
      end if;
    end loop;
  end if;

  -- o jsonb nunca pode contradizer as colunas reais
  d := jsonb_set(d, '{role}',   to_jsonb(new.role),   true);
  d := jsonb_set(d, '{status}', to_jsonb(new.status), true);

  new.data := d;
  return new;
end;
$$;

drop trigger if exists trg_fittrack_users_guard on fittrack_users;
create trigger trg_fittrack_users_guard
  before update on fittrack_users
  for each row execute function public.fittrack_users_guard();


-- Toda conta nova nasce comum e pendente, diga o cliente o que disser.
create or replace function public.fittrack_users_guard_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.fittrack_is_admin() then
    return new;
  end if;
  new.role    := 'user';
  new.status  := 'pending';
  new.auth_id := auth.uid();
  new.data    := jsonb_set(
                   jsonb_set(coalesce(new.data,'{}'::jsonb), '{role}',  '"user"',    true),
                   '{status}', '"pending"', true);
  return new;
end;
$$;

drop trigger if exists trg_fittrack_users_guard_insert on fittrack_users;
create trigger trg_fittrack_users_guard_insert
  before insert on fittrack_users
  for each row execute function public.fittrack_users_guard_insert();


-- ------------------------------------------------------------
-- 4) POLÍTICAS — USUÁRIOS
-- ------------------------------------------------------------
drop policy if exists "logados leem usuarios"      on fittrack_users;
drop policy if exists "criar propria conta"        on fittrack_users;
drop policy if exists "logados atualizam usuarios" on fittrack_users;

-- leitura: o app precisa de todos os perfis (ranking, grupos, amigos)
create policy "logados leem usuarios"
  on fittrack_users for select to authenticated using (true);

-- criação: só a própria linha, ligada ao próprio login
create policy "criar propria conta"
  on fittrack_users for insert to authenticated
  with check (auth_id = auth.uid());

-- atualização: liberada na policy, filtrada pelo trigger acima
create policy "logados atualizam usuarios"
  on fittrack_users for update to authenticated
  using (true) with check (true);

-- exclusão: só admin
create policy "admin apaga usuarios"
  on fittrack_users for delete to authenticated
  using (public.fittrack_is_admin());


-- ------------------------------------------------------------
-- 5) POLÍTICAS — GRUPOS
-- Antes qualquer logado apagava qualquer grupo. Agora só quem tem
-- relação com ele.
-- ------------------------------------------------------------
drop policy if exists "logados leem grupos"      on fittrack_groups;
drop policy if exists "logados criam grupos"     on fittrack_groups;
drop policy if exists "logados atualizam grupos" on fittrack_groups;
drop policy if exists "logados apagam grupos"    on fittrack_groups;

create policy "logados leem grupos"
  on fittrack_groups for select to authenticated using (true);

-- quem cria precisa constar como dono
create policy "criar grupo proprio"
  on fittrack_groups for insert to authenticated
  with check (data->>'owner' = public.fittrack_me());

-- editar: dono, admin do grupo, membro, ou admin do sistema.
-- O "using" olha a linha ANTES da edição — é ele que barra estranhos.
-- O "with check" fica liberado de propósito: se exigisse a mesma
-- condição na linha NOVA, um membro não conseguiria sair do próprio
-- grupo (ele deixaria de estar em members no meio da operação).
create policy "membros atualizam grupos"
  on fittrack_groups for update to authenticated
  using (
    data->>'owner' = public.fittrack_me()
    or jsonb_exists(data->'admins',  public.fittrack_me())
    or jsonb_exists(data->'members', public.fittrack_me())
    or public.fittrack_is_admin()
  )
  with check (true);

-- apagar: só o dono do grupo ou o admin do sistema
create policy "dono apaga grupo"
  on fittrack_groups for delete to authenticated
  using (
    data->>'owner' = public.fittrack_me()
    or public.fittrack_is_admin()
  );


-- ============================================================
-- 6) PASSO OBRIGATÓRIO — TE PROMOVER A ADMIN
--
-- A partir de agora ninguém vira admin sozinho (era exatamente o furo).
-- Então a sua promoção é feita aqui, uma única vez, à mão.
-- Troque o email abaixo se necessário e rode:
-- ============================================================
update fittrack_users
set role   = 'admin',
    status = 'approved',
    data   = jsonb_set(jsonb_set(data,'{role}','"admin"',true),'{status}','"approved"',true)
where lower(data->>'email') = lower('SEU-EMAIL-AQUI@exemplo.com');

-- Confira o resultado (deve listar você como admin/approved):
select username, role, status, (auth_id is not null) as tem_login
from fittrack_users
order by role desc, username;

-- ============================================================
-- PRONTO. Teste depois: entrar no app, aprovar alguém pela aba Admin,
-- montar um treino para um aluno, criar e apagar um grupo.
-- ============================================================
