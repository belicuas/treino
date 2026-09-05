-- ============================================================
-- FitTrack — SQL COMPLETO (projeto Supabase NOVO)
-- Cole TUDO isso de uma vez no SQL Editor e clique em RUN.
-- ============================================================

-- ---------- TABELAS ----------
create table if not exists fittrack_users (
  username   text primary key,
  data       jsonb not null,
  auth_id    uuid,
  updated_at timestamptz default now()
);

create table if not exists fittrack_groups (
  id         text primary key,
  data       jsonb not null,
  updated_at timestamptz default now()
);

-- ---------- LIGA A SEGURANÇA (RLS) ----------
alter table fittrack_users  enable row level security;
alter table fittrack_groups enable row level security;

-- ---------- REGRAS: USUÁRIOS ----------
-- Quem está LOGADO pode ler todos (necessário p/ ranking, grupos, admin)
create policy "logados leem usuarios"
  on fittrack_users for select to authenticated using (true);

-- Cada pessoa cria a própria linha (ligada ao seu login)
create policy "criar propria conta"
  on fittrack_users for insert to authenticated
  with check (auth_id = auth.uid());

-- Logados podem atualizar (o app controla quem edita o quê:
-- cada um os próprios dados, treinador os treinos dos alunos, admin aprova)
create policy "logados atualizam usuarios"
  on fittrack_users for update to authenticated
  using (true) with check (true);

-- ---------- REGRAS: GRUPOS ----------
create policy "logados leem grupos"
  on fittrack_groups for select to authenticated using (true);

create policy "logados criam grupos"
  on fittrack_groups for insert to authenticated with check (true);

create policy "logados atualizam grupos"
  on fittrack_groups for update to authenticated
  using (true) with check (true);

create policy "logados apagam grupos"
  on fittrack_groups for delete to authenticated using (true);

-- ---------- TEMPO REAL (sincronização instantânea) ----------
alter publication supabase_realtime add table fittrack_users;
alter publication supabase_realtime add table fittrack_groups;

-- ============================================================
-- PRONTO! Se aparecer "Success. No rows returned", deu certo.
-- ============================================================
