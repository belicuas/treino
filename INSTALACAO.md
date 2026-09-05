# FitTrack — Guia do Zero ao Ar 🚀

Siga na ordem. Leva ~20 minutos.

---

## PARTE 1 — Criar o Supabase (banco de dados)

**1.1** Acesse https://supabase.com → "Start your project" → entre com GitHub/Google.

**1.2** Clique em **New project**:
- Name: `fittrack`
- Database Password: crie uma senha forte (guarde, mas você não vai usá-la no app)
- Region: escolha a mais próxima (South America, se houver)
- Clique em **Create new project** e aguarde ~2 minutos.

**1.3 — Criar as tabelas**
Menu lateral → **SQL Editor** → **New query** →
cole TODO o conteúdo do arquivo `1-SQL-COMPLETO.sql` → clique em **Run**.
✅ Deve aparecer: "Success. No rows returned"

**1.4 — Desligar confirmação de email**
Menu lateral → **Authentication** → **Sign In / Providers** → clique em **Email** →
procure **"Confirm email"** e DESATIVE → Save.
(Se não encontrar, tudo bem: siga em frente. Se depois pedir confirmação,
você recebe um email e clica no link — por isso use um email REAL no passo 2.2.)

**1.5 — Copiar as chaves**
Menu lateral → **Settings** (engrenagem) → **API**. Copie:
- **Project URL** (ex: https://abcdefg.supabase.co)
- **anon public** (uma chave longa que começa com `eyJ...`)

---

## PARTE 2 — Configurar o app

**2.1** Abra o arquivo `index.html` num editor de texto
(Bloco de Notas, VS Code, qualquer um).

**2.2** Logo no começo, procure o bloco "⚙️ CONFIGURAÇÃO".
Preencha as 2 linhas:

    const SUPABASE_URL = 'https://SEU-PROJETO.supabase.co';   <- do passo 1.5
    const SUPABASE_KEY = 'eyJ...';                            <- do passo 1.5

Estas duas chaves são públicas por natureza — todo visitante recebe este
arquivo e consegue lê-las. O que protege os dados é o RLS no banco, não o
sigilo delas. **Nunca** coloque aqui a chave `service_role`.

**2.3** Salve o arquivo.

---

## PARTE 3 — Publicar no GitHub Pages

**3.1** Crie uma conta em https://github.com (se não tiver).

**3.2** Clique no **+** (canto superior direito) → **New repository**:
- Repository name: `fittrack`
- Marque **Public**
- Clique em **Create repository**

**3.3** Na página do repositório → **Add file** → **Upload files**.
Arraste TODOS os arquivos desta pasta (os arquivos soltos, NÃO a pasta):
- index.html
- manifest.json
- sw.js
- icon-180.png, icon-192.png, icon-512.png, icon-512-maskable.png

Clique em **Commit changes**.

**3.4** Vá em **Settings** (do repositório) → **Pages** (menu lateral):
- Branch: `main`
- Folder: `/ (root)`
- Clique em **Save**

**3.5** Aguarde 1-2 minutos e recarregue a página.
Vai aparecer o link, algo como:
`https://SEU-USUARIO.github.io/fittrack/`

---

## PARTE 4 — Criar sua conta de admin

**4.1** Abra o link do passo 3.5 no navegador.

**4.2** Clique em **"Criar conta"** e preencha:
- Nome: seu nome
- Nome de usuário: como você quer ser chamado no app
- Email: um email real (você vai precisar confirmá-lo)
- Senha: a que você quiser (mín. 6 caracteres)

**4.3** Pronto! Você entra como administrador (aba "Admin" na barra de baixo).

Se aparecer "Confirme pelo email": abra seu email, clique no link
de confirmação e depois faça login normalmente.

---

## PARTE 5 — Instalar no celular

Abra o link no celular:
- **Android (Chrome):** menu ⋮ → "Instalar app"
- **iPhone (Safari):** Compartilhar → "Adicionar à Tela de Início"

Mande o link para os amigos — eles fazem o mesmo. Cada um cria sua conta,
e você aprova na aba **Admin**.

---

## Deu erro?
- Tela pede para configurar → as chaves do passo 2.2 não foram salvas.
- Não consigo criar conta → confira se o SQL do passo 1.3 rodou com sucesso.
- "Email já vinculado" → esse email já tem conta; use outro ou apague em
  Authentication > Users.
