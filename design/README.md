# Design

Mockups do redesenho, em telas de 390px. Cada `.dc.html` é uma prancheta:

| Arquivo | O que é |
|---|---|
| `Sistema.dc.html` | Escala de tipo (6 degraus), escala de espaço, card, paleta, nav |
| `Main.dc.html` | Início |
| `Progresso.dc.html` | Progresso — por exercício |
| `Corpo.dc.html` | Corpo — músculos, calendário, peso corporal |
| `Social.dc.html` | Social — amigos, ranking |
| `canvas.json` | Posição das pranchetas no canvas e as notas |

## O que o redesenho resolve

Medido no `index.html` de 08/09: 15 tamanhos de fonte com 112 das 162
ocorrências entre 11 e 13px (nenhuma hierarquia), 170 estilos inline
(nenhum ritmo de espaço), até 7 itens na barra de baixo e abas dentro de
abas em três níveis. A paleta nunca foi o problema — ela é mantida.

A navegação passa a ser **Início · Progresso · Corpo · Social · Perfil**:
`Corpo` recolhe agenda muscular, calendário e peso corporal (que morava em
Progresso sem pertencer lá), e `Alunos` e `Admin` saem da barra para dentro
do Perfil.

## Regenerar o canvas

Estes arquivos são a fonte; o canvas publicado é gerado a partir deles pela
skill `/design`, que monta um HTML de ~2,5 MB (o editor vai embutido). Esse
arquivo gerado **não é versionado** — veja o `.gitignore`.

Nada aqui é carregado pelo app: `index.html` não referencia esta pasta.
