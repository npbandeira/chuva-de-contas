# Chuva de Contas

Projeto feito para aprender [LÖVE](https://love2d.org/) (Lua) fazendo um jogo simples do
zero: contas de matemática caem do céu e o jogador precisa resolvê-las antes que
toquem o chão.

A ideia surgiu do jogo *Magic Touch: Wizard for Hire*, trocando os inimigos que
caem por contas de matemática.

## Jogar / baixar

**Jogue no navegador:** <https://npbandeira.itch.io/chuva-de-contas>

Ou baixe a versão para o seu sistema, sem precisar instalar o LÖVE. Os mesmos
arquivos estão no itch.io e na
[release do GitHub](https://github.com/npbandeira/chuva-de-contas/releases/latest):

| Plataforma | Arquivo |
|---|---|
| Windows | [`chuva-de-contas-v1.0.1-windows.zip`](https://github.com/npbandeira/chuva-de-contas/releases/download/v1.0.1/chuva-de-contas-v1.0.1-windows.zip) |
| macOS (Intel e Apple Silicon) | [`chuva-de-contas-v1.0.1-macos.zip`](https://github.com/npbandeira/chuva-de-contas/releases/download/v1.0.1/chuva-de-contas-v1.0.1-macos.zip) |
| Linux (x86_64) | [`chuva-de-contas-v1.0.1-linux.AppImage`](https://github.com/npbandeira/chuva-de-contas/releases/download/v1.0.1/chuva-de-contas-v1.0.1-linux.AppImage) |
| Android 4.1+ | [`chuva-de-contas-v1.0.1-android.apk`](https://github.com/npbandeira/chuva-de-contas/releases/download/v1.0.1/chuva-de-contas-v1.0.1-android.apk) |
| Navegador (HTML5) | [`chuva-de-contas-v1.0.1-web.zip`](https://github.com/npbandeira/chuva-de-contas/releases/download/v1.0.1/chuva-de-contas-v1.0.1-web.zip) |
| Qualquer um com LÖVE 11.5 | [`chuva-de-contas-v1.0.1.love`](https://github.com/npbandeira/chuva-de-contas/releases/download/v1.0.1/chuva-de-contas-v1.0.1.love) |

Como abrir cada um:

- **Windows:** extraia o `.zip` e abra `Chuva de Contas.exe`. Se o aviso
  "O Windows protegeu o computador" aparecer, clique em *Mais informações* >
  *Executar assim mesmo* (o jogo não tem assinatura digital).
- **macOS:** extraia o `.zip` e abra `Chuva de Contas.app`. Se o macOS bloquear,
  vá em *Ajustes do Sistema > Privacidade e Segurança* > *Abrir Mesmo Assim*.
  Se aparecer "o app está danificado", rode
  `xattr -cr "/Applications/Chuva de Contas.app"`.
- **Linux:** `chmod +x chuva-de-contas-v1.0.1-linux.AppImage` e execute. Se não
  abrir, instale o FUSE 2 (no Ubuntu: `sudo apt install libfuse2`).
- **Android:** abra o `.apk` no celular e permita instalar apps de fontes
  desconhecidas, se o Android pedir.
- **`.love`:** `love chuva-de-contas-v1.0.1.love`

## Como jogar

- Contas (`+`, `-`, `x`, `:`) caem em queda livre pela tela.
- Digite a resposta para destruir a conta correspondente antes que ela
  chegue ao chão.
- Cada conta perdida custa uma vida; o jogo acaba com 3 vidas perdidas.
- A cada 10 acertos o nível sobe: as contas ficam maiores e caem mais rápido, e
  novas operações são liberadas (nível 1: `+`/`-`; nível 2: `x`; nível 3+: `:`).
- Acertos em sequência formam um **combo**: cada acerto vale mais pontos que o
  anterior, e a cada 5 acertos seguidos rola uma comemoração (efeito na tela,
  tremida e som) que fica mais intensa conforme o combo cresce.
- De vez em quando aparecem contas especiais:
  - **Blindada** (contorno prateado): precisa resolver duas vezes — ao acertar a
    primeira, ela racha e vira outra conta na mesma posição.
  - **Poder** (brilho dourado com uma estrela): ao resolver, estoura em cadeia
    todas as outras contas na tela, dando pontos bônus por cada uma.
  - **Chefe** (vermelho escuro, maior e mais lento): aparece a cada nível múltiplo
    de 3, com um aviso na tela, e precisa de três acertos pra cair — vale o
    triplo de pontos.
- O recorde de pontos é salvo entre execuções (`highscore.txt`).
- Trilha sonora *chiptune* gerada por código, tocando em loop durante a partida:
  baixo saltitante e arpejo rápido inspirados no clima de temas de fase clássicos
  (Super Mario World / Sonic), com uma batida simples e um sininho mágico no
  início de cada volta do loop como aceno ao *Magic Touch*.

**PC:** digite os números no teclado; a conta estoura assim que a resposta
bate, sem precisar de Enter (ele continua funcionando para confirmar na hora).
Esc ou P pausa a partida; na tela inicial, C abre os créditos e Esc sai.
**Celular:** use o teclado numérico na tela; o botão `||` no canto pausa e o botão
Voltar do Android funciona como o Esc.

## Executando

Requer o [LÖVE](https://love2d.org/) instalado (`love` no PATH).

```bash
love .
```

Para testar o layout mobile (retrato + teclado na tela) sem um celular:

```bash
love . --mobile
```

## Estrutura do projeto

```
main.lua            Ponto de entrada: carrega tudo e repassa os callbacks do LÖVE à tela atual
conf.lua            Janela e módulos do LÖVE (lê plataforma e versão de src/config.lua)
states/             Telas do jogo; cada uma tem enter/exit/update/draw/entrada
  menu.lua          Tela inicial com título animado, JOGAR e recorde
  credits.lua       Créditos rolando
  play.lua          Partida em andamento e contagem "3, 2, 1" ao voltar da pausa
  pause.lua         Pausa: continuar, reiniciar ou ir ao menu
  gameover.lua      Fim de jogo e "jogar de novo"
src/
  config.lua        Versão do jogo e plataforma (celular, navegador)
  statemanager.lua  Troca de telas e repasse dos callbacks
  round.lua         Regras da partida: pontos, nível, vidas, combo, contas em queda
  hud.lua           Interface da partida: vidas, caixa de resposta, teclado na tela
  demo.lua          Cena animada atrás do menu e dos créditos
  problems.lua      Gerador das contas (Lua puro, sem depender do LÖVE)
  entities/
    card.lua        A conta caindo (normal, blindada, poder, chefe)
    wizard.lua      O mago
    spell.lua       Feitiço que voa da varinha até a conta
  particles.lua     Estilhaços ao estourar uma conta
  ui.lua            Peças de desenho comuns: texto, fundo, botões, scanlines
  layout.lua        Resolução virtual, escala para a tela real e teclado numérico
  transition.lua    Transição de losangos entre telas
  assets.lua        Carrega imagens, fontes e sons (com fallback sintetizado)
  music.lua         Trilha chiptune gerada por código, em loop
  theme.lua         Paleta de cores do tema arcade/neon
  save.lua          Recorde salvo em disco
assets/             Fontes, imagens e sons de terceiros (créditos em assets/CREDITS.txt)
  fonts/  images/  sounds/  licenses/
android/            Script e recursos para gerar o APK Android
scripts/            Build para o itch.io (web, Windows, macOS, Linux)
```

## Gerando o APK Android

```bash
./android/build_apk.sh
```

O script baixa as ferramentas necessárias (LÖVE embed, apktool, uber-apk-signer),
empacota o jogo dentro do APK oficial do LÖVE para Android e assina o resultado
em `build/chuva-de-contas-v<versão>.apk`. A versão vem de `config.VERSION` em
`src/config.lua`. Uma keystore própria é criada automaticamente em
`android/release.keystore` na primeira execução — guarde uma cópia de backup,
pois sem ela não é possível instalar atualizações sobre uma versão já instalada.

## Gerando os pacotes para o itch.io

```bash
./android/build_apk.sh      # primeiro o APK, para ele entrar no pacote
./scripts/build_itch.sh
```

Gera em `build/itch/` o `.love`, a versão web (love.js), os pacotes de Windows,
macOS e Linux (AppImage) e copia o APK. As ferramentas baixadas ficam em
`build/tools/itch`. O script precisa de `curl`, `unzip`, `7z`, `python3` com
Pillow e `npx` (Node.js).

## Créditos

Fonte, sons e imagens de terceiros estão listados com suas licenças em
[`assets/CREDITS.txt`](assets/CREDITS.txt).

## Licença

Copyright (c) 2026 Nicolas Pantoja. **Todos os direitos reservados.**
O código está aqui apenas para consulta: copiar, modificar ou publicar o jogo
(inclusive em lojas de aplicativos) depende de autorização do autor. Fonte, sons,
imagens e o motor LÖVE seguem as licenças de terceiros. Veja [`LICENSE`](LICENSE).
