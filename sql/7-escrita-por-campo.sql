-- ============================================================
-- FitTrack — ESCRITA POR CAMPO (fim da sobrescrita do perfil inteiro)
--
-- O PROBLEMA QUE FICOU DE PÉ
-- O script 6 impediu o pior: name, email e os arrays estruturais não podem
-- mais ser APAGADOS por um cliente com estado incompleto. Mas a causa
-- continuava no cliente — ele mandava o objeto inteiro a cada alteração, e
-- qualquer campo fora daquela lista de proteção seguia à mercê de uma cópia
-- velha aberta em outro aparelho.
--
-- A CORREÇÃO
-- O cliente passa a enviar só as chaves que mudou, marcadas com __merge:true.
-- Quando essa marca vem, o gatilho funde o patch no que já existe
-- (old.data || patch) em vez de trocar o objeto. Sem a marca, nada muda:
-- o comportamento antigo continua valendo, então versões antigas do app em
-- cache seguem funcionando.
--
-- Efeito colateral bom: o cliente que só quer mexer nos seis campos de
-- terceiros (pedido de treinador, amizade, treino montado) manda apenas
-- esses, e não mais os seis vindos de uma cópia possivelmente velha.
--
-- LIMITE CONSCIENTE
-- Merge altera e cria chaves, nunca REMOVE uma chave de primeiro nível.
-- O app não faz isso (esvazia arrays, não os apaga). Se algum dia precisar,
-- é uma escrita completa, sem a marca.
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
  eh_patch boolean;
  patch    jsonb;   -- so o que o cliente diz ter mudado (sem a marca)
  enviado  jsonb;   -- o objeto completo que o cliente esta propondo
begin
  -- ---------- patch ou objeto inteiro? ----------
  eh_patch := (new.data -> '__merge') = 'true'::jsonb;
  patch    := coalesce(new.data, '{}'::jsonb) - '__merge';
  if eh_patch then
    enviado := coalesce(old.data, '{}'::jsonb) || patch;
  else
    enviado := patch;
  end if;

  eh_admin := public.fittrack_is_admin();

  if eh_admin then
    -- o app escreve so o jsonb: refletir nas colunas
    new.role   := coalesce(nullif(enviado->>'role',   ''), new.role);
    new.status := coalesce(nullif(enviado->>'status', ''), new.status);
    if new.role   not in ('user','admin')                 then new.role   := old.role;   end if;
    if new.status not in ('pending','approved','blocked') then new.status := old.status; end if;
    d := enviado;
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
      d := enviado;
    else
      -- terceiro: parte do que existe e aceita apenas os seis campos que ele
      -- de fato mandou. Com patch, "mandou" passa a significar "mudou".
      d := old.data;
      foreach k in array campos_de_terceiros loop
        if jsonb_exists(patch, k) then
          d := jsonb_set(d, array[k], patch -> k, true);
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

  -- a marca de controle nunca fica gravada
  d := d - '__merge';

  -- jsonb e colunas terminam sempre iguais
  d := jsonb_set(d, '{role}',   to_jsonb(new.role),   true);
  d := jsonb_set(d, '{status}', to_jsonb(new.status), true);

  new.data := d;
  return new;
end;
$$;


-- ------------------------------------------------------------
-- COMO O APP DESCOBRE QUE ESTE SCRIPT JA FOI APLICADO
-- Sem isto, um app novo contra um banco antigo mandaria patches e o gatilho
-- velho os trataria como objeto inteiro — apagando campos. O cliente chama
-- esta funcao uma vez; se ela nao existir, ele continua mandando o objeto
-- inteiro, como antes.
-- ------------------------------------------------------------
create or replace function public.fittrack_merge_ok()
returns boolean language sql immutable as $$ select true $$;

grant execute on function public.fittrack_merge_ok() to authenticated;


-- Conferencia: as duas funcoes existem?
select p.proname
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('fittrack_users_guard','fittrack_merge_ok')
order by p.proname;
