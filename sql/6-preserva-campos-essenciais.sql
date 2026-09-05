-- ============================================================
-- FitTrack — NÃO DEIXAR O CLIENTE APAGAR CAMPOS ESSENCIAIS
--
-- O PROBLEMA OBSERVADO
-- O perfil criado pelo trigger nasce completo (name, email, e os arrays
-- que a interface espera). Mas o app grava o objeto INTEIRO a cada
-- alteração — e se o objeto que ele tem em memória estiver incompleto,
-- o que faltar é apagado do banco.
--
-- Foi o que houve com o usuário "teste": perfil criado 02:11 com nome e
-- email, sobrescrito 02:15 por um objeto sem eles. A aba Admin então
-- contava o pendente na estatística mas quebrava ao montar a lista, em
-- u.name.split(' ') — contador aparece, usuário não.
--
-- A CORREÇÃO
-- O banco passa a tratar name e email como campos que só podem ser
-- alterados, nunca apagados. Um cliente que "esqueceu" um campo recebe
-- de volta o valor que já existia, em vez de destruí-lo.
-- ============================================================

create or replace function public.fittrack_users_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  campos_de_terceiros text[] := array[
    'coachRequests', 'coachRequestsSent', 'friends', 'coaches', 'students', 'workouts'
  ];
  -- arrays/objetos que a interface le sem proteger contra ausencia
  campos_estruturais text[] := array[
    'workouts', 'completedSessions', 'friends', 'coaches', 'students',
    'coachRequests', 'coachRequestsSent', 'weights'
  ];
  eh_dono  boolean;
  eh_admin boolean;
  k        text;
  d        jsonb;
  email_do_login text;
begin
  eh_admin := public.fittrack_is_admin();

  if eh_admin then
    -- o app escreve so o jsonb: refletir nas colunas
    new.role   := coalesce(nullif(new.data->>'role',   ''), new.role);
    new.status := coalesce(nullif(new.data->>'status', ''), new.status);
    if new.role   not in ('user','admin')                 then new.role   := old.role;   end if;
    if new.status not in ('pending','approved','blocked') then new.status := old.status; end if;
    d := new.data;
  else
    eh_dono := (old.auth_id is not null and old.auth_id = auth.uid());

    if old.auth_id is null
       and lower(coalesce(old.data->>'email','')) = lower(coalesce(auth.jwt()->>'email','#'))
    then
      new.auth_id := auth.uid();
      eh_dono := true;
    else
      new.auth_id := old.auth_id;
    end if;

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
  end if;

  -- ---------- daqui para baixo vale para todos, admin inclusive ----------

  -- NOME: pode mudar, nunca sumir
  if nullif(d->>'name','') is null then
    d := jsonb_set(d, '{name}',
           to_jsonb(coalesce(nullif(old.data->>'name',''), new.username)),
           true);
  end if;

  -- EMAIL: a fonte de verdade e o login, nao o navegador
  select u.email into email_do_login from auth.users u where u.id = new.auth_id;
  if nullif(d->>'email','') is null then
    d := jsonb_set(d, '{email}',
           to_jsonb(coalesce(email_do_login, nullif(old.data->>'email',''), '')),
           true);
  end if;

  -- ARRAYS que a interface le direto: se sumirem, devolve o que havia
  foreach k in array campos_estruturais loop
    if not jsonb_exists(d, k) then
      d := jsonb_set(d, array[k], coalesce(old.data -> k, '[]'::jsonb), true);
    end if;
  end loop;
  if not jsonb_exists(d, 'loads') then
    d := jsonb_set(d, '{loads}', coalesce(old.data -> 'loads', '{}'::jsonb), true);
  end if;

  -- jsonb e colunas terminam sempre iguais
  d := jsonb_set(d, '{role}',   to_jsonb(new.role),   true);
  d := jsonb_set(d, '{status}', to_jsonb(new.status), true);

  new.data := d;
  return new;
end;
$$;


-- ------------------------------------------------------------
-- REPARA OS PERFIS JA DANIFICADOS
-- Repoe nome e email a partir do login, e os arrays que faltarem.
-- ------------------------------------------------------------
update fittrack_users f
set data = (
  select f.data
      || case when nullif(f.data->>'name','') is null
              then jsonb_build_object('name',
                     coalesce(nullif(trim(u.raw_user_meta_data->>'name'),''),
                              nullif(trim(u.raw_user_meta_data->>'username'),''),
                              f.username))
              else '{}'::jsonb end
      || case when nullif(f.data->>'email','') is null
              then jsonb_build_object('email', u.email) else '{}'::jsonb end
      || case when not jsonb_exists(f.data,'loads')             then '{"loads":{}}'::jsonb             else '{}'::jsonb end
      || case when not jsonb_exists(f.data,'weights')           then '{"weights":[]}'::jsonb           else '{}'::jsonb end
      || case when not jsonb_exists(f.data,'workouts')          then '{"workouts":[]}'::jsonb          else '{}'::jsonb end
      || case when not jsonb_exists(f.data,'completedSessions') then '{"completedSessions":[]}'::jsonb else '{}'::jsonb end
      || case when not jsonb_exists(f.data,'friends')           then '{"friends":[]}'::jsonb           else '{}'::jsonb end
      || case when not jsonb_exists(f.data,'coaches')           then '{"coaches":[]}'::jsonb           else '{}'::jsonb end
      || case when not jsonb_exists(f.data,'students')          then '{"students":[]}'::jsonb          else '{}'::jsonb end
      || case when not jsonb_exists(f.data,'coachRequests')     then '{"coachRequests":[]}'::jsonb     else '{}'::jsonb end
      || case when not jsonb_exists(f.data,'coachRequestsSent') then '{"coachRequestsSent":[]}'::jsonb else '{}'::jsonb end
  from auth.users u where u.id = f.auth_id
)
where exists (select 1 from auth.users u where u.id = f.auth_id);

-- Conferencia
select username,
       coalesce(data->>'name','SEM NOME')   as nome,
       coalesce(data->>'email','SEM EMAIL') as email,
       status
from fittrack_users order by username;
