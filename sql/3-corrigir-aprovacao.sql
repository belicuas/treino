-- ============================================================
-- Correção: permitir que o ADMIN aprove/edite outros usuários
-- Rode no SQL Editor do Supabase se a aprovação não estiver salvando.
-- ============================================================

-- remove a política de update antiga (se existir com outro nome/regra)
drop policy if exists "logados atualizam" on fittrack_users;
drop policy if exists "logados atualizam usuarios" on fittrack_users;

-- recria permitindo que qualquer usuário LOGADO atualize qualquer linha
-- (a lógica de quem pode o quê fica no app: admin aprova, treinador edita alunos, etc.)
create policy "logados atualizam usuarios"
  on fittrack_users for update to authenticated
  using (true) with check (true);

-- ============================================================
-- "Success. No rows returned" = deu certo.
-- ============================================================
