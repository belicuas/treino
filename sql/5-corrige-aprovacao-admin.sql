-- ============================================================
-- FitTrack — CORRIGE A APROVAÇÃO PELO ADMIN
--
-- O PROBLEMA
-- O script 2 tornou role/status colunas reais, mas o app continua
-- escrevendo apenas o jsonb "data" (é assim que pushUser funciona).
-- No caminho do admin o trigger devolvia a linha sem tocar nela, então
-- o jsonb ia para 'approved' e a COLUNA continuava 'pending'.
--
-- Resultado: a aprovação parecia funcionar na tela, mas o primeiro
-- update seguinte feito por outra pessoa ressincronizava o jsonb a
-- partir da coluna e revertia a aprovação silenciosamente.
--
-- A CORREÇÃO
-- No caminho do admin, as colunas passam a ser atualizadas A PARTIR do
-- jsonb — que é o único lugar onde o app escreve. As colunas continuam
-- sendo a fonte de autoridade para todo mundo que não é admin.
-- ============================================================

create or replace function public.fittrack_users_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
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
    -- O app escreve so o jsonb. Refletir nas colunas, senao a aprovacao
    -- fica pela metade e e revertida no proximo update de terceiro.
    new.role   := coalesce(nullif(new.data->>'role',   ''), new.role);
    new.status := coalesce(nullif(new.data->>'status', ''), new.status);
    -- valores aceitos, para um jsonb corrompido nao virar privilegio
    if new.role   not in ('user','admin')                 then new.role   := old.role;   end if;
    if new.status not in ('pending','approved','blocked') then new.status := old.status; end if;
    -- jsonb e coluna terminam sempre iguais
    new.data := jsonb_set(jsonb_set(new.data, '{role}', to_jsonb(new.role), true),
                          '{status}', to_jsonb(new.status), true);
    return new;
  end if;

  eh_dono := (old.auth_id is not null and old.auth_id = auth.uid());

  -- linha antiga sem vinculo: so pode ser reivindicada pelo dono do email
  if old.auth_id is null
     and lower(coalesce(old.data->>'email','')) = lower(coalesce(auth.jwt()->>'email','#'))
  then
    new.auth_id := auth.uid();
    eh_dono := true;
  else
    new.auth_id := old.auth_id;
  end if;

  -- fora do admin, role e status nao mudam por nenhum caminho
  new.role   := old.role;
  new.status := old.status;

  if eh_dono then
    d := new.data;
  else
    d := old.data;
    foreach k in array campos_de_terceiros loop
      if jsonb_exists(new.data, k) then
        d := jsonb_set(d, array[k], new.data -> k, true);
      end if;
    end loop;
  end if;

  d := jsonb_set(d, '{role}',   to_jsonb(new.role),   true);
  d := jsonb_set(d, '{status}', to_jsonb(new.status), true);

  new.data := d;
  return new;
end;
$$;

-- Conferencia
select username, role, status, (data->>'status') as status_jsonb
from fittrack_users order by username;
