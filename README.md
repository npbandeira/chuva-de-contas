# Chuva de Contas

Projeto feito para aprender [LÖVE](https://love2d.org/) (Lua) fazendo um jogo simples do
zero: contas de matemática caem do céu e o jogador precisa resolvê-las antes que
toquem o chão.

A ideia surgiu do jogo *Magic Touch: Wizard for Hire*, trocando os inimigos que
caem por contas de matemática.

## Como jogar

- Contas (`+`, `-`, `x`, `:`) caem em queda livre pela tela.
- Digite a resposta e confirme para destruir a conta correspondente antes que ela
  chegue ao chão.
- Cada conta perdida custa uma vida; o jogo acaba com 3 vidas perdidas.
- A cada 10 acertos o nível sobe: as contas ficam maiores e caem mais rápido, e
  novas operações são liberadas (nível 1: `+`/`-`; nível 2: `x`; nível 3+: `:`).
- Acertos em sequência formam um **combo**: cada acerto vale mais pontos que o
  anterior, e a cada 5 acertos seguidos rola uma comemoração (efeito na tela,
  tremida e som) que fica mais intensa conforme o combo cresce.
- O recorde de pontos é salvo entre execuções (`highscore.txt`).
- Trilha sonora *chiptune* gerada por código, tocando em loop durante a partida:
  baixo saltitante e arpejo rápido inspirados no clima de temas de fase clássicos
  (Super Mario World / Sonic), com uma batida simples e um sininho mágico no
  início de cada volta do loop como aceno ao *Magic Touch*.

**PC:** digite os números no teclado e pressione Enter. Esc volta ao menu / sai.
**Celular:** use o teclado numérico na tela.

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
conf.lua         Configuração da janela do LÖVE e detecção de modo mobile
main.lua         Ponto de entrada: só liga os callbacks do LÖVE aos módulos abaixo
problems.lua     Gerador das contas (separado para poder testar com Lua puro)
src/
  assets.lua     Carrega imagens, fontes e sons (com fallback sintetizado)
  music.lua      Trilha chiptune gerada por código, em loop
  theme.lua      Paleta de cores do tema arcade/neon
  layout.lua     Resolução virtual, escala pra tela real e teclado numérico
  game.lua       Estado e regras da partida: pontos, nível, vidas, combo, partículas
  input.lua      Teclado físico, teclado na tela e toques/cliques
  draw.lua       Desenho de tudo: fundo, contas, HUD, telas e efeitos visuais
assets/          Fontes, sons e imagens de terceiros (créditos em assets/CREDITS.txt)
android/         Script e recursos para gerar o APK Android
```

## Gerando o APK Android

```bash
./android/build_apk.sh
```

O script baixa as ferramentas necessárias (LÖVE embed, apktool, uber-apk-signer),
empacota o jogo dentro do APK oficial do LÖVE para Android e assina o resultado
em `build/chuva-de-contas-v<versão>.apk`. A versão vem de `GAME_VERSION` em
`conf.lua`. Uma keystore própria é criada automaticamente em
`android/release.keystore` na primeira execução — guarde uma cópia de backup,
pois sem ela não é possível instalar atualizações sobre uma versão já instalada.

## Créditos

Fonte, sons e imagens de terceiros estão listados com suas licenças em
[`assets/CREDITS.txt`](assets/CREDITS.txt).
