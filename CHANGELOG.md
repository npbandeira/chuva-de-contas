# Changelog

Todas as mudanças relevantes do **Chuva de Contas** ficam registradas aqui.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e o projeto usa [Versionamento Semântico](https://semver.org/lang/pt-BR/).
A versão do jogo fica em `GAME_VERSION`, no `conf.lua`.

## [Não lançado]

### Adicionado

- Arquivo `LICENSE`: o projeto é de Nicolas Pantoja, com todos os direitos
  reservados. O material de terceiros continua sob as licenças dele.

## [1.0.0] - 2026-09-29

Primeira versão pública.

### Jogo

- Contas de `+`, `-`, `x` e `:` caem do céu; digite a resposta para destruir a
  conta antes que ela toque o chão.
- 3 vidas: cada conta que chega ao chão custa uma vida e mostra a resposta certa.
- Dificuldade progressiva: a cada 10 acertos as contas caem mais rápido e novas
  operações são liberadas (`x` a partir do nível 2, `:` a partir do nível 3).
- Mago que lança um feitiço em direção à conta resolvida, com partículas na
  explosão.
- **Combo** por acertos seguidos: vale pontos extras e, a cada 5 acertos, rende
  uma comemoração com efeito na tela, tremida e som.
- Contas especiais:
  - **Blindada**: moldura de aço, precisa de 2 acertos. No primeiro, o escudo
    quebra em estilhaços e a conta racha. Um aviso explica na primeira vez que
    aparece.
  - **Poder**: estoura todas as outras contas da tela de uma vez.
  - **Chefe**: aparece a cada 3 níveis, com chifres, aura pulsante e aviso na
    tela; precisa de 3 acertos.
- Escudinhos acima das contas especiais mostram quantos acertos ainda faltam.
- Recorde de pontos salvo entre partidas.

### Telas e interface

- Tela inicial animada: título letra por letra, contas caindo ao fundo com o
  mago estourando algumas, botão **JOGAR** e placa de recorde.
- Contador de acertos grande e translúcido no fundo durante a partida.
- Indicador de combo ao lado da caixa de resposta, com cor que muda conforme o
  combo cresce.
- **Pausa** com as opções continuar, reiniciar e voltar ao menu, e contagem
  "3, 2, 1" ao voltar. A partida também pausa sozinha quando o jogo perde o foco
  (outra janela ou app em segundo plano).
- Tela de **créditos** com rolagem automática.
- Transição animada entre as telas.
- Tela de fim de jogo com pontos, acertos e aviso de novo recorde.

### Som

- Trilha chiptune original, gerada por código e tocando em loop.
- Efeitos sonoros para acerto, erro, vida perdida, combo, golpe em escudo e
  explosão. A música fica mais baixa durante a pausa.

### Plataformas

- **PC** (Windows, macOS, Linux via LÖVE 11.5): teclado físico. Esc ou P pausa,
  C abre os créditos.
- **Android**: layout em retrato com teclado numérico na tela. O botão `||`
  pausa, e o botão Voltar do Android funciona como Esc. Para testar o layout de
  celular no PC, use `love . --mobile`.

### Licenças

- Créditos completos de fonte, sons, imagens e bibliotecas em
  `assets/CREDITS.txt`.
- Textos das licenças do LÖVE e das bibliotecas de terceiros, e da fonte
  Press Start 2P (SIL OFL 1.1), em `assets/licenses/`.

[Não lançado]: https://github.com/npbandeira/chuva-de-contas/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/npbandeira/chuva-de-contas/releases/tag/v1.0.0
