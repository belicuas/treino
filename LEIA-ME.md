# FitTrack — PWA com sincronização (Supabase)

App de treinos com **dados sincronizados em tempo real** entre todos os usuários, via Supabase.

## Arquivos
- `index.html` — o app (já configurado com suas chaves do Supabase)
- `manifest.json`, `sw.js` — configuração do PWA (ícone, tela cheia, offline)
- `icon-*.png` — ícones

Mantenha todos juntos na mesma pasta.

## Já está configurado
O app já está ligado ao seu projeto Supabase:
- URL: `https://ziejwcnhdqcucjivedmc.supabase.co`
- Tabela: `fittrack_users` (você já criou com o SQL)

## Publicar
1. Suba todos os arquivos desta pasta no GitHub Pages, Netlify ou Vercel.
2. Abra o link no celular e instale (Adicionar à tela inicial).
3. Pronto — todo mundo que usar o link compartilha os mesmos dados.

## Como testar se a sincronização funciona
1. Abra o app no seu celular e no computador (ou em dois navegadores).
2. Faça login como admin (`pedrobelicuas` / `lopes`) num, e crie/aprove algo.
3. No outro, os dados devem aparecer em segundos, sem recarregar.
4. No painel Supabase → Table Editor → `fittrack_users`, você vê as linhas sendo criadas.

## Login admin
- Usuário: `pedrobelicuas`
- Senha: `lopes`

## Como funciona
- Os dados ficam no Supabase (nuvem) e também em cache no aparelho (para abrir rápido e funcionar offline).
- Quando alguém registra um treino, o app envia ao Supabase, que avisa todos os outros em tempo real.
- Se ficar sem internet, o app usa o cache local e sincroniza quando voltar.

## Segurança (importante)
A chave no código é a `anon public`, feita para ficar exposta no app — sem problema.
A regra atual do banco permite leitura/escrita a quem tem a chave. Para um grupo de amigos é adequado.
NUNCA coloque a chave `service_role` (secreta) no app.
