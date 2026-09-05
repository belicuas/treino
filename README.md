# FitTrack

PWA de acompanhamento de treinos: treinos, cargas, peso corporal, ranking,
grupos, relação treinador ↔ aluno e aprovação de novos usuários pelo admin.

App de arquivo único (`index.html`) servido pelo GitHub Pages, com
[Supabase](https://supabase.com) como banco de dados e autenticação.

**No ar em:** https://belicuas.github.io/treino/

## Estrutura

| Arquivo | O que é |
|---|---|
| `index.html` | o app inteiro — HTML, CSS e JS num arquivo só |
| `sw.js` | service worker (funcionamento offline) |
| `manifest.json` + `icon-*.png` | metadados de PWA, para instalar no celular |
| `INSTALACAO.md` | guia de instalação do zero |
| `sql/` | scripts do banco, na ordem em que devem ser aplicados |

## Banco de dados

Duas tabelas, ambas com o perfil guardado numa coluna `jsonb`:

- **`fittrack_users`** — `username` (PK), `data` (jsonb), `auth_id`, `role`, `status`
- **`fittrack_groups`** — `id` (PK), `data` (jsonb)

Os scripts em `sql/` são cumulativos e devem ser rodados em ordem no
SQL Editor do Supabase:

1. `1-schema-inicial.sql` — tabelas, RLS e as políticas originais
2. `2-seguranca-rls.sql` — **correção de segurança** (ver abaixo)
3. `3-corrigir-aprovacao.sql` — ajuste no fluxo de aprovação
4. `4-perfil-automatico.sql` — cria o perfil no banco quando o login nasce
5. `5-corrige-aprovacao-admin.sql` — aprovação do admin grava coluna e jsonb
6. `6-preserva-campos-essenciais.sql` — impede o cliente de apagar campos

### Por que o script 6 existe

O app grava o objeto de perfil **inteiro** a cada alteração. Se o objeto
que ele tem em memória estiver incompleto, o que faltar é apagado do
banco — foi assim que um usuário perdeu `name` e `email` minutos depois
de ser criado, e a aba Admin passou a contar o pendente na estatística
mas quebrar ao montar a lista (`u.name.split(' ')` sobre `undefined`).

O banco agora trata `name`, `email` e os arrays estruturais como campos
que só podem ser alterados, nunca apagados: um cliente que "esqueceu" um
campo recebe de volta o valor que já existia. O `email` vem sempre de
`auth.users`, que é a fonte de verdade.

## Cadastro e confirmação de email

O perfil em `fittrack_users` é criado por um trigger em `auth.users`, não
pelo navegador. Isso é o que permite exigir confirmação de email: com a
confirmação ligada, o `signUp` não devolve sessão, o cliente continua
como `anon`, e a gravação do perfil pelo app falharia — o usuário
confirmaria o email, faria login e o app quebraria em `enterApp()` ao
ler o nome de um perfil inexistente.

Toda conta nova nasce `role=user` e `status=pending`, independentemente
do que o cliente enviar. A aprovação é feita pela aba Admin.

> **Atenção ao envio de emails.** O projeto usa o SMTP embutido do
> Supabase, que serve para testes: o limite é de poucos emails por hora
> e a entrega não é garantida (costuma cair em spam). Para cadastros de
> verdade, configure um SMTP próprio em Authentication → Emails —
> Resend e Brevo têm plano gratuito suficiente para este uso.

## Segurança

O modelo original confiava no cliente: a política de update era
`using (true)`, e quem decidia o que cada pessoa podia fazer era o
JavaScript. Como a `anon key` é pública por design, qualquer usuário
cadastrado podia falar direto com a API REST do Supabase, por fora do
app, e editar qualquer registro — inclusive se promover a administrador.

`sql/2-seguranca-rls.sql` move a autorização para o banco:

- `role` e `status` viraram colunas reais; o `jsonb` é apenas uma cópia
  que o app lê, e um trigger garante que ele nunca contradiga a coluna
- um trigger `BEFORE UPDATE` classifica quem está escrevendo:
  - **admin** — sem restrição (precisa disso para aprovar e bloquear)
  - **dono da linha** — os próprios dados, exceto `role`, `status` e `auth_id`
  - **terceiro** — apenas seis campos: `coachRequests`, `coachRequestsSent`,
    `friends`, `coaches`, `students` e `workouts`, que são os que o app
    legitimamente escreve na linha de outra pessoa (pedido de treinador,
    amizade, e o treinador montando o treino do aluno)
- grupos só podem ser apagados pelo dono ou pelo admin

Nenhuma mudança foi necessária no `index.html`: o app funciona igual,
mas agora quem impõe as regras é o Postgres, não o navegador.

### Limites conhecidos

- **Leitura é aberta entre usuários logados.** Ranking, grupos e lista de
  amigos dependem disso; fechar exigiria redesenhar o app.
- **Membros podem editar o grupo em que estão**, inclusive de forma
  desastrada. Restringir mais impediria alguém de sair do próprio grupo.
- **Há senhas em texto puro nos dados de demonstração** dentro do
  `index.html` (contas fictícias de seed, não contas reais).

## Desenvolvimento

Não há build: é editar o `index.html` e commitar. O Pages publica sozinho
a partir da branch `main`.

Ao mexer no `sw.js`, suba a versão do cache — senão o navegador dos
usuários continua servindo a versão antiga.

As chaves do Supabase ficam no topo do `index.html`, no bloco
`⚙️ CONFIGURAÇÃO`. A `anon key` é uma chave de cliente e pode ficar
pública; o que protege os dados é o RLS. **A `service_role` key nunca
deve entrar neste arquivo.**
