# Registro histórico — reconstrução sobre o JukaMix + RomM Library (2026-11-22)

Este documento registra o que foi feito entre 2026-11-21 e 2026-11-22 e onde estão os arquivos.
Ele vive na branch `release/2026-11-22-jukamix-romm`. **A `main` não foi alterada.**

## 1. Contexto

- Aparelho: Trimui Smart Pro, firmware 1.1.1.
- Sistema de base: JukaMix (`jukaLang/JukaCrossMix-OS`), commit `d5102fab` ("Better Logging for debugging").
- Em 2026-11-20 a `main` deste fork recebeu 49 commits sobre o `d5102fab`: apps novos (RomM,
  BatteryGuard, TestApp, SmartProGameCenter, BIOSDoctor, PortManager, ThemeSwitcher, WiFiTools,
  FirmwareUpdate), scripts de manutenção, workflows e uma série de commits de depuração sobre o
  lançamento de apps (shebang, caminho absoluto, captura de `cmd_to_run.sh`, log de opções de
  montagem). Os últimos commits removem TestApp, o RomMLibrary antigo e BatteryGuard com a
  mensagem "did not work on device". **A causa de os apps antigos não abrirem no fw 1.1.1 não foi
  determinada.**
- A `main` ainda contém sobras dessa fase, inclusive arquivos do RomMLibrary antigo
  (`Apps/RomMLibrary/README.md`, `config.json`, `lib/*.sh`, `romm.sh`).

## 2. Decisão de escopo (2026-11-21)

- Refazer em cima do JukaMix puro, mantendo os apps do JukaMix.
- Acrescentar **somente** o app RomM Library, na aba Apps.
- Os apps antigos não foram migrados.
- Entrega: zip para o cartão SD + patch (sem push na época).

## 3. O que foi feito

### 3.1 `feat/romm-library` (`272c5cff`) — app RomM Library

- Assistente de primeira execução (URL do servidor, usuário/senha ou token `rmm_`) com VirtualKeyboard.
- Teste de conexão com diagnóstico legível, aviso do estado do Tailscale e fallback de MagicDNS.
- Plataformas → lista paginada (salto por letra, busca por plataforma e global) → download.
- Download com progresso, B para parar, retomada (Range), checagem de tamanho e espaço, três rotas de download.
- ROMs de vários arquivos (ZIP) extraídas na pasta certa de `Roms/`; nomes ajustados para FAT/exFAT.
- Tabela plataforma → pasta (`data/platform_map.tsv`); para as desconhecidas o app pergunta uma vez e lembra.
- Idiomas pt/en. Configuração em `Data/romm/config.json` (ignorada pelo git); log em `System/logs/romm_library.log`.
- Testes: `tests/romm_library/run.sh` (precisa de `bash`) com servidor RomM simulado — 109 checagens.

### 3.2 `fix/jukamix-review` (`d0d8ff90`) — correções no JukaMix

| Item | Arquivo(s) | Problema → correção |
|---|---|---|
| Parar serviços | Tailscale, SFTPGo e Syncthing (menu NETWORK) | `pkill <caminho>` nunca casava (o pkill usa o nome do processo): "Disable" não parava e "Enable" duplicava. Passou a `pkill -x <nome>`. No Tailscale, `TAILSCALE` apontava para o `tailscaled`; agora aponta para o CLI `tailscale`. |
| Ícone NGPC | `Add icons on best folders.sh` | Segundo rótulo `NGP)` era inalcançável; renomeado para `NGC)`. |
| Scraper | `scrap_screenscraper.sh` | WS e WSC estavam em 207 (Watara Supervision). 207 passou para `SUPERVISION`; WSC usa 45; removida a linha morta `SFX`. |
| Restore de FW | `FW Settings Save-Load.sh` | Cancelar o seletor testava variável nunca atribuída. Agora sai limpo. |

Testes: `tests/jukamix_fixes_test.sh` — 35 checagens (17 falham no código antigo).

### 3.3 `release/2026-11-22-jukamix-romm` (esta branch)

Branch das duas anteriores + este documento + os arquivos entregues em `releases/2026-11-22/`.

## 4. Arquivos em `releases/2026-11-22/`

| Arquivo | Para quê |
|---|---|
| `RomMLibrary-sdcard.zip` | Extrair na raiz do cartão: cria `Apps/RomMLibrary/` (24 arquivos). **Regerado em 2026-11-24** com a correção de texto (seções 10 e 12) e a opção Excluir (seção 11); a versão original tinha 22 arquivos; por cima de uma instalação existente só troca os arquivos do app e não mexe em `Data/romm/`. |
| `JukaMix-fixes-sdcard.zip` | Extrair na raiz do cartão: substitui os 10 arquivos corrigidos. |
| `romm-library.patch` | Patch git do commit `272c5cff` (`git am`). |
| `RetroArch-probe-sdcard.zip` | **Substituído pelo `RetroArch-fix-sdcard.zip`.** Primeira versão da sonda (troca `Apps/RetroArch/launch.sh` e acrescenta `ra_probe.sh`). Guardado só para registro. |
| `RetroArch-fix-sdcard.zip` | Extrair na raiz do cartão (5 arquivos): daemon de entrada sem o anúncio de vibração (`trimui/app/trimui_inputd`, `System/resources/tsp_inputd` e `tsps_inputd`), sonda corrigida (`ra_probe.sh`) e `Apps/RetroArch/launch.sh`. Seção 8. |
| `romm-library-text.patch` | Patch git do commit da seção 10 (texto das telas de download e aviso), `git am` depois dos anteriores. |
| `romm-library-delete.patch` | Patch git do commit da seção 11 (opção "Excluir do cartão SD"), `git am` depois do anterior. |
| `romm-library-ui.patch` | Patch git do commit da seção 12 (avisos e confirmações pelo `selector`, progresso em uma linha, calibração dos acentos), `git am` depois do anterior. |
| `jukamix-fixes.patch` | Patch git do commit `d0d8ff90` (`git am`, depois do anterior). |
| `retroarch-fix.patch` | Patch git (com `--binary`) do commit da correção do RetroArch (seção 8), `git am` depois dos anteriores. |
| `jukamix-romm-and-fixes.bundle` | Bundle git com todos os commits desde o JukaMix até o `83fcda45` (ref `HEAD`; requer `d5102fab`). **Regerado em 2026-11-25** (antes parava em `1741df2e`, sem os commits da RomM Library). Não contém o commit que adiciona esta versão do bundle. |
| `SHA256SUMS.txt` | Hashes para conferir a integridade (`sha256sum -c SHA256SUMS.txt`). |

`RomMLibrary-sdcard.zip` e `JukaMix-fixes-sdcard.zip` são independentes entre si; `RetroArch-fix-sdcard.zip` substitui o `RetroArch-probe-sdcard.zip`. Patches e bundle servem só para o git; não vão ao cartão.

## 5. Instalação resumida

1. Backup de `Roms/`, `BIOS/`, `Saves/`, `Data/` e personalizações.
2. Formatar o cartão em FAT32 e extrair o release do JukaMix na raiz.
3. Ligar uma vez e conferir o JukaMix puro (inclusive abrir um jogo no RetroArch).
4. Desligar, extrair na raiz do cartão `RomMLibrary-sdcard.zip`, `JukaMix-fixes-sdcard.zip` e `RetroArch-fix-sdcard.zip` (aceitar substituir os arquivos) e ligar de novo. O `RetroArch-fix` só vale depois de um reinício completo, porque o daemon de entrada é carregado no boot.
5. Conectar o Wi-Fi, ligar o Tailscale (System Tools → NETWORK → Tailscale) e abrir Apps → RomM Library.

Detalhes de uso: `Apps/RomMLibrary/README.md`.

## 6. Como trazer para a `main` (decisão pendente)

As três branches nascem do `d5102fab` (JukaMix), **não** da `main`. Para unir à `main`:

- Um merge de `feat/romm-library` na `main` vai gerar conflitos de "adicionado nos dois lados" nos
  arquivos do RomMLibrary antigo que ainda estão na `main` (`README.md`, `config.json`,
  `lib/download.sh`). O mais simples é remover o RomMLibrary antigo da `main` antes.
- Alternativa: tratar a branch `release/2026-11-22-jukamix-romm` como a nova base e abandonar as
  sobras da fase anterior.
- Atenção: o workflow de release do JukaMix (`JukaMix-OS Release.yml`) só remove `_assets scripts
  tests schemas packages .github` antes de empacotar a imagem. As pastas `releases/` e `docs/`
  entrariam na imagem se a `main` voltar a gerar releases com elas; mova-as para fora ou
  acrescente-as à lista de exclusão antes disso.

## 7. Limitações e pendências

- **Nada foi testado em hardware real.** Os testes são simulações (159 + 35 + 44 + 24 + 8 checagens); o
  daemon de entrada corrigido só foi verificado por comparação de bytes e disassembly, não executado.
- **RetroArch preso na tela de loading** ao abrir por Apps → RetroArch (relatado em 2026-11-22):
  causa identificada, correção entregue e **confirmada no aparelho pelo usuário em 2026-11-23**
  ("funcionando 100%"); ver a seção 8.
- Causa de os apps antigos não abrirem no fw 1.1.1: não determinada.
- O id do ScreenScraper para WonderSwan Color (45) não foi confirmado online; pode ser 46.
- No teste existente `tests/logging_test.sh` uma checagem falha no caminho que só usa `logread`;
  provavelmente é do ambiente de teste, não foi investigado.
- RomM Library: sem suporte a IPv6 literal; os arquivos não são verificados por hash (só o tamanho esperado).

## 8. RetroArch preso ao abrir por Apps → RetroArch (diagnósticos de 2026-11-22/23)

### 8.1 O que os dois relatórios `System Logs - Collect` mostraram

Aparelho `tsp`, imagem 1.3.0, firmware patched 1.3.0, firmware 1.1.0, kernel 4.9.191.

- **O RetroArch estava vivo, não morto.** O tick do watchdog (301 s após o boot) pegou
  `ra64.trimui_tsp` em estado **D** (espera ininterrupta), com 47,55 s de CPU, carga 4,30 e 727 MB
  livres. Sem falta de memória; temperatura normal.
- **As "crash entries" são falsos positivos.** Casam só com linhas normais de boot que contêm a
  palavra "watchdog" (`sunxi-wdt … Watchdog enabled`, `procd: - watchdog -`); `mmc2: error -22
  whilst initialising SDIO card` é a inicialização do Wi-Fi (o Wi-Fi conectou). Não há panic, oops,
  OOM nem erro de E/S no log do kernel.
- **Os boots "NOT clean" são desligamentos forçados** pelo botão de energia. Como `/tmp` some, o log
  da sessão travada se perde; e `Apps/RetroArch/launch.sh` não registra `start app=`.
- **Trocar a versão do RetroArch não resolveu** (relato do usuário): a causa não está no binário do
  RetroArch.
- **Correção de uma conclusão anterior.** Eu havia escrito que "os jogos abrem normalmente e só o
  menu trava". Isso se baseava em lançamentos feitos na primeira sessão, antes do reinício. Depois do
  reinício os jogos podem travar do mesmo jeito (veja 8.3); não foi verificado.

### 8.2 O que o log da sonda (`ra_probe.log`, 2026-11-23 03:03) provou

- A **thread principal** do RetroArch ficou em estado D durante todo o log (≥ 9 s reais), parada em
  `ioctl(fd 12, 0x40304580)`, ou seja **EVIOCSFF** (enviar um efeito de vibração a um dispositivo de
  entrada). Pilha do kernel: `uinput_request_submit` ← `uinput_dev_upload_effect` ←
  `input_ff_upload` ← `evdev_ioctl`. O alvo é um dispositivo criado por `/dev/uinput` e o kernel
  espera, sem limite de tempo e sem poder ser interrompido, que o processo dono desse dispositivo
  responda ao pedido.
- A outra thread, de vídeo, continua trocando o quadro do framebuffer (`FBIOPAN_DISPLAY`, ~20 por
  segundo): por isso a tela fica no "loading" e a CPU aparece alta.
- Antes disso, a thread principal passa breves momentos em D em `evdev_release`/`joydev_release`
  (`synchronize_rcu`): é o fechamento normal de dispositivos de entrada no início, não o problema.
- **Defeito da própria sonda:** o log diz 240 s, mas cobre ~15 s de relógio. O `sleep` do shell do
  aparelho voltava na hora (provável efeito do `sync` em segundo plano terminando durante a espera).
  Corrigido na versão 2 (8.5). A conclusão acima não depende disso, mas o log não mostra se o travamento
  teria passado depois.

### 8.3 Causa provável (análise estática, não confirmada no aparelho)

O daemon de entrada do JukaMix para o TSP/TSP-S (`System/resources/tsp_inputd`, 41 144 bytes, o mesmo
arquivo que `tsps_inputd`) cria o controle virtual "Xbox 360" na função `trimui_setup_xpad` **anunciando
force feedback**: liga `EV_FF`, seis bits `FF_*` (`0x50 0x60 0x51 0x58 0x59 0x5a`) e define
`ff_effects_max = 16`. Mas o daemon **nunca atende** esses pedidos: não há `UI_BEGIN_FF_UPLOAD` /
`UI_END_FF_UPLOAD` (0xc06055c8/c9) em nenhum dos três binários, e as três chamadas `read()` do programa
leem só o inotify e a porta serial, nunca o descritor do uinput. O SDL2 (usado pelo RetroArch) envia um
efeito de vibração assim que abre um controle com FF; com esse dispositivo o pedido nunca termina.

- Esse recurso entrou no upstream em 2025-11-26 (commit `a984db64`, "Fix Pro S controls") e continua em
  `b27bd415` e `321a16cd`. O `tsp_inputd` de 2025-09-01 (`e8804701`, 26 912 bytes, também o padrão em
  `trimui/app/trimui_inputd`) **não** tem FF.
- **Hipótese para "antes funcionava":** o cartão novo começa com o daemon padrão (sem FF); o
  `inputd_switcher` instala o do dispositivo (com FF), mas só passa a valer depois de um reinício
  (`restart_inputd` não reinicia com o MainUI ativo). Isso explicaria jogos abrindo na primeira sessão e
  o travamento depois. É uma hipótese: o relatório não mostra qual daemon estava instalado.
- **Não confirmado:** que o dono do dispositivo é o `trimui_inputd` (o log não listava quem segura
  `/dev/uinput`; a sonda v2 passa a listar); e por que outros usuários do JukaMix não relatam o mesmo
  (não investigado; pode ser que relatem).

### 8.4 Correção entregue (`RetroArch-fix-sdcard.zip`)

`scripts/inputd-disable-ff.py` troca **8 instruções de 32 bits** em `trimui_setup_xpad`: as sete
chamadas `ioctl` que ligam `EV_FF` e os `FF_*` viram `nop` (os retornos nunca eram checados) e
`ff_effects_max` passa de 16 para 0. O resto do binário é idêntico (41 144 bytes, mesmos offsets),
então todas as correções de entrada mais novas do daemon continuam. O script confere as instruções ao
redor antes de escrever e se recusa a mexer em qualquer outro arquivo.

| Arquivo no cartão | Antes | Depois |
|---|---|---|
| `trimui/app/trimui_inputd` (daemon em uso) | conforme instalado pelo switcher (provavelmente o de 41 144 B, crc32 `5055f537`) ou o padrão de 26 912 B (`3356097d`) | 41 144 B, crc32 `1802bfaf` |
| `System/resources/tsp_inputd` e `tsps_inputd` (origem do switcher) | 41 144 B, crc32 `5055f537` | 41 144 B, crc32 `1802bfaf` |

Os três ficam iguais, então o `inputd_switcher` (que compara o instalado com o de `System/resources`)
não desfaz a correção. O `brickpro_inputd` não tem FF e não foi tocado. Teste:
`bash tests/inputd_noff_test.sh` (24 checagens: exatamente 8 palavras mudam, nos offsets esperados;
o disassembly da função não tem mais `ioctl` de FF; os arquivos do cartão são idênticos).

**Limite desta correção:** ela foi verificada por comparação de bytes e disassembly; o binário é
aarch64 e depende de `/dev/uinput` e da UART do aparelho, por isso não foi executado aqui.

**Se não resolver:** a sonda v2 diz exatamente o que acontece (8.5). Alternativa já disponível no
próprio release do JukaMix: copiar o `trimui/app/trimui_inputd` original (26 912 B) por cima do daemon
do cartão e do `System/resources/tsp_inputd`; ele não tem FF, mas também não tem as correções de
entrada de 26–28/11/2025 (controles do Pro S, D-pad e detecção de dispositivo).

### 8.5 Sonda v2 (`ra_probe.sh`)

- Espera por **tempo real** (`/proc/uptime`), repetindo o `sleep` se ele voltar antes; cada amostra
  mostra `t=+Ns` real e o `uptime`. A duração de 240 s passa a ser real.
- Quando a thread principal está em `EVIOCSFF`, registra uma única vez: o descritor e o nó
  `/dev/input/eventN`, o nome e as capacidades (`B: FF=`) desse dispositivo, a lista dos dispositivos de
  entrada, **quais processos seguram `/dev/uinput`** e o tamanho/crc32 do daemon instalado e dos de
  `System/resources`.
- Continua só lendo `/proc` e nunca interfere no RetroArch. Teste: `bash tests/ra_probe_test.sh`
  (44 checagens).

### 8.6 Como conferir no aparelho

1. Extrair `RetroArch-fix-sdcard.zip` na raiz do cartão (aceitar substituir) e **desligar e ligar de
   novo** (reinício completo).
2. Abrir Apps → RetroArch (e depois um jogo por um lançador de emulador). Esperado: o menu abre.
3. Qualquer que seja o resultado, `System/logs/ra_probe.log` (ou *System Logs - Collect*) mostra o
   que aconteceu. A linha `installed input daemon: 41144 bytes crc32=1802bfaf` confirma que o daemon
   corrigido está em uso; `5055f537` significa que o original continua instalado.

## 9. Revisão de uma avaliação externa da estrutura do JukaMix (2026-11-23)

O usuário colou uma avaliação com quatro pontos sobre o repositório do JukaMix e pediu para conferir
e aplicar o que estivesse certo. Cada ponto foi checado contra este repositório (a base é a mesma
`d5102fab`). Veredito:

| # | Alegação | Veredito | Ação |
|---|----------|----------|------|
| 1 | Arquivos `Zone.Identifier` órfãos em `Apps/BootLogo/themes/ff_VII` e `Zelda` | **Certo, mas o caminho está errado.** São 21 arquivos em `Apps/PortMaster/PortMaster/themes/ff_VII` (20) e `.../Zelda` (1); não existe `Apps/BootLogo/themes`. Todos têm 0 byte, menos um (170 bytes); nada os referencia | **Aplicado**: removidos; `.gitignore` e `tests/repo_hygiene_test.sh` impedem a volta |
| 2 | Várias versões de RetroArch/PPSSPP/Flycast/ScummVM inflam o repositório | **Verdade como observação, mas é recurso, não sobra.** O seletor de versões do RetroArch (`Apps/RetroArch/launch.sh` procura `ra64.trimui_<aparelho>_*.bin`) e as variantes `PPSSPP_1.15.4`, `flycast_v1.0/v2.4` são intencionais; o usuário já usou o rebaixamento de versão. São 13 arquivos `ra64.*` (121 MB); os do Brick e do TSPS somam 60,1 MB de ~4,4 GB (1,3 %) | **Não aplicado.** Cortar variantes quebra funções e outros aparelhos; fica como decisão do usuário (ver abaixo) |
| 3 | Inconsistência de nomes (`JukaCrossMix-OS`, `JukaMix-OS Release.yml`, `- JukaMix.bmp`, `JukCrossMix-OS.sh`) | **Os fatos estão certos, a conclusão não.** `JukCrossMix-OS` é um identificador interno, usado por `System/etc/crossmix.json`, pela pasta `Themes/JukCrossMix-OS`, pelo script do menu e pelos scripts de lançamento. Renomear quebra instalações existentes e o caminho do tema gravado nelas | **Não aplicado** |
| 4 | Fontes NotoSans duplicadas em "BootLogo themes" e `Icons/Default/Logos` grande | **Parcialmente errado.** Não há temas de BootLogo com fontes; as fontes duplicadas estão nos 6 temas do PortMaster (Doom, Fallout, Stardew, Zelda, ff_VII, hiviz): 30 arquivos, 209,9 MB, **só 5 conteúdos distintos** (175 MB redundantes). `Icons/Default/Logos` são 492 arquivos, 11,8 MB: não é problema | **Aplicado só nas fontes**, ver 9.1 |

### 9.1 Por que remover as fontes dos temas é seguro

- As 30 cópias são **idênticas byte a byte** (sha256) às 5 fontes de `pylibs/resources/NotoSans.tar.xz`.
- `pugwash` descompacta esse tar em `pylibs/resources` na primeira execução (e `funcs.txt` também), e
  adiciona essa pasta à busca de recursos da interface. A busca (`ResourceManager.find`) percorre os
  caminhos do último para o primeiro, então `pylibs/resources` já era consultada **antes** da pasta do
  tema: as cópias dos temas nunca eram a usada.
- O `default_theme` do PortMaster já funciona assim: o `theme.json` cita as cinco fontes e a pasta
  não tem nenhuma.
- As fontes só servem a idiomas chinês, coreano e japonês (`font[zh_*]`, `font[ko_KR]`,
  `font[ja_JP]`). As fontes próprias de cada tema (Doom, Cinzel, Press Start 2P…) ficaram onde
  estavam. `theme.md5` é só um texto guardado; não é conferido contra o conteúdo da pasta.
- Efeito: **−209,9 MB** na imagem; depois da primeira execução do PortMaster, 35 MB são extraídos
  uma vez em `pylibs/resources`.
- Limite: não executei o PortMaster (precisa do aparelho). A conclusão vem da leitura do código e da
  comparação dos arquivos. Para voltar atrás: `git revert` do commit, ou copiar as fontes de volta.

### 9.2 Decisões que ficam com o usuário

Cortar peso é possível, mas muda o que o sistema oferece, então não foi feito sem pedido:

- Remover os binários do Brick e do TSPS (`brick.*`, `*_brick_*`, `*_tsps_*`; ~60 MB) se o cartão for só
  para o TSP.
- Reduzir variantes de RetroArch para uma ou duas versões do TSP.
- Escolher entre `PPSSPP`/`PPSSPP_1.15.4` e `flycast_v1.0`/`flycast_v2.4`.
- `Emus/SCUMMVM/ScummVM` tem 294 MB: é o maior item isolado de `Emus`.

### 9.3 No cartão já instalado

Os `Zone.Identifier` podem existir também no cartão. Para listar sem apagar (PowerShell, trocando `E:`
pela letra do cartão):

```powershell
Get-ChildItem -Path E:\Apps\PortMaster -Recurse -Force -Filter *Zone.Identifier* | Select-Object FullName, Length
```

Conferida a lista, o mesmo comando com `| Remove-Item -WhatIf` mostra o que seria apagado, e sem
`-WhatIf` apaga de fato. As fontes `NotoSans*-Regular.ttf` dentro de
`Apps\PortMaster\PortMaster\themes\<tema>\` também podem ser apagadas à mão; extrair o pacote novo
por cima não as recria.

## 10. RomM Library no aparelho: texto das telas de download e de aviso (2026-11-23/24)

> **Superada em parte pela seção 12.** A conversão para Latin-1 (acentos) continua valendo, mas a ideia de
> quebrar o texto em várias linhas no `infoscreen` estava errada: ele só desenha uma linha, e cada quebra
> virava um quadradinho. Isso apareceu nas fotos do aparelho de 2026-11-24.

**Relato do usuário:** o app "rodou perfeitamente"; só as fontes na hora do download e nas mensagens de
aviso ficavam "bem bagunçadas". As fontes dos menus (mesmo pequenas) estavam ok.

**Causa provável** (por leitura do código e dos binários; não vi a tela do aparelho):

- Menus, lista de jogos e teclado usam `selector`/`VirtualKeyboard`, que leem UTF-8: ok.
- Download e avisos usam `infoscreen.sh`, que chama `System/bin/sdl2imgshow`. Esse binário (14,9 KB)
  importa só `TTF_RenderText_Solid`: o texto é lido como **Latin-1**, não UTF-8, e não há chamada de
  quebra de linha. Efeito: com a interface em português, "não" saía como "NÃ£o", e aspas curvas,
  reticências e títulos com macron ou caracteres japoneses viravam lixo; linhas longas passavam da
  borda da tela.
- A interface em inglês (ASCII) não sofria do problema dos acentos, mas os títulos dos jogos
  continuavam podendo ter caracteres fora do ASCII.

**Correção** (`Apps/RomMLibrary/lib/screentext.awk`, `data/latin1.tsv`, `screen_text` em `lib/common.sh`,
usada por `ui_info`, `ui_wait`, `ui_confirm` e pela tela de progresso do download):

- U+00A0–U+00FF viram 1 byte Latin-1 (acentos corretos na tela).
- Aspas curvas, travessões, reticências, `™`, `€` e setas viram ASCII; macrons, carons e afins
  (U+0100–U+024F, U+1E00–U+1EFF) viram a letra base; o que sobrar (japonês, chinês…) vira um `?`.
- Linhas são quebradas por palavras na largura de 880 px estimada com a fonte do tema
  (`wqy-microhei.ttf`, larguras medidas por classe de caractere e arredondadas para cima); palavra maior
  que a tela sofre quebra dura. Se o awk falhar, o texto original é mostrado como antes.
- Medição com a fonte real (Pillow): a maior linha dos casos de teste mede 860 px; a tela do Brick tem
  1024 px e a do TSP 1280.

**Testes:** `tests/romm_library/run.sh` passou de 109 para 124 checagens. O mock do `infoscreen` agora
guarda os bytes exatos recebidos (`info.raw`) e o texto lido como UTF-8 (`info.log`); sem a correção, 5
checagens de ponta a ponta falham (provado com o código antigo).

**Limites:** os escapes são convertidos com `printf %b` e `tr` do BusyBox, o awk é o do BusyBox; só
rodei com `dash` e `mawk`. A estimativa de largura é conservadora, não exata. Se ainda aparecer algo
estranho, uma foto da tela mostra se o problema restante é de largura, de fonte ou de outro texto.

## 11. RomM Library: opção "Excluir do cartão SD" (2026-11-24)

**Pedido do usuário:** às vezes a ROM baixada não funciona ou está quebrada, e não dava para apagá-la
pelo menu do RomM.

**O que foi feito** (`lib/download.sh`, `lib/screens.sh`, `lib/i18n.sh`):

- Tela do jogo: quando ele está no cartão, o menu ganha "Excluir do cartão SD" (a numeração se ajusta;
  sem o jogo no cartão o menu é o mesmo de antes). Pede confirmação (a partir da seção 12, um menu "Não" / "Sim, excluir"; antes era A/B no `infoscreen`) mostrando até 3
  nomes, quantos itens a mais e o tamanho total, e avisa que saves e estados **não** são apagados.
- Para só apagar o que o app baixou, cada download passa a gravar `Data/romm/dl/<id>.lst` (linhas
  `pasta<TAB>item`, item = arquivo ou pasta direto dentro de `Roms/<pasta>/`). Vale também para jogos
  de vários arquivos: o ZIP é extraído e cada item movido é anotado. Se a extração falhar no meio, o que
  já foi movido também fica na lista.
- Jogos de arquivo único baixados antes da lista existir são reconhecidos pelo caminho
  (`Roms/<pasta>/<nome sanitizado>`). Jogos de vários arquivos baixados antes não têm como ser
  reconhecidos com segurança: é preciso baixar de novo uma vez.
- Segurança: item ou pasta vazio, `.`, `..` ou com `/` nunca é apagado; um item que a lista de **outro**
  jogo também cita é mantido; nada fora de `Roms/` é tocado. Também apaga o `.rommpart`/`.state` desse
  jogo e o `*_cache*.db` da pasta.
- A lista de jogos agora marca com `* ` também os jogos de vários arquivos já baixados (antes só os de
  arquivo único).

**Testes:** `tests/romm_library/run.sh` foi de 124 para 159 checagens (exclusão de arquivo único, de
vários arquivos, cancelamento com B, jogo antigo sem lista, item compartilhado, entradas perigosas
na lista, saves e outro jogo na mesma pasta intactos).

**Limites:** testado só em simulação (`dash`, `mawk`, `du`/`sort` do ambiente de teste), não no
aparelho. Não apaga imagens/metadados que o scraper do JukaMix tenha gerado para o jogo.

## 12. RomM Library: as letras ainda estavam ruins; avisos e progresso refeitos (2026-11-24)

**Relato do usuário (3 fotos do aparelho):** "As letras seguem ruins." As fotos mostram a tela de progresso
do download e os avisos com quadradinhos (⊠) em cada quebra de linha, frases longas numa linha só saindo
pela borda e texto cortado. Os acentos já estavam certos.

**Causa real:** o `infoscreen` (`sdl2imgshow`) faz **uma única** chamada `TTF_RenderText_Solid`. Ele só
desenha uma linha: `\n` vira um quadradinho e nada quebra nem corta. A seção 10 supôs o contrário e
acrescentou quebras de linha, que só pioraram. Quem desenha vários parágrafos é o `selector` (o título lê
`\n`, uma linha por vez).

**Correção** (`lib/common.sh`, `lib/screentext.awk`, `lib/download.sh`, `lib/platforms.sh`, `lib/screens.sh`,
`lib/i18n.sh`):

- **Progresso do download:** uma linha só no `infoscreen`: `título... - 45%   12.3 MB / 40.0 MB  -  1.2 MB/s  -  B: parar`.
  O título é cortado com `...` na largura da tela (1150 px; 900 px no Brick) e o final (porcentagem, tamanho,
  velocidade e dica) nunca é cortado. O rótulo "Baixando" saiu para sobrar espaço.
- **Avisos** (`ui_notice`, `ui_wait`): viraram um menu do `selector` com um item "OK" e o texto no título,
  quebrado por palavra em cerca de 57 caracteres (`screen_wrap`). A confirmação de exclusão (`ui_confirm`)
  é um menu "Não" (item inicial) / "Sim, excluir".
- **Frases curtas** ("Carregando...", "Conectando..."): `ui_info` continua no `infoscreen`, mas junta tudo
  numa linha só.
- **Seletor de pasta** (`plat_ask_folder`): itens numerados (`3. GBA`) e a pasta vem pelo número.
- **Acentos no `selector`:** o binário sugere Latin-1 (`TTF_RenderText_*` não decodifica UTF-8), mas você
  disse que os menus estavam ok mandando UTF-8, e eu não consigo testar no aparelho. Em vez de adivinhar,
  na primeira abertura o app mostra duas linhas (`ação coração você`) em cada codificação e você escolhe
  a que aparece certa; o resultado vai para `ui_encoding` no `config.json` (`latin1` ou `utf8`). **B** pula
  e pergunta de novo na próxima vez. *Configurações → Acentos na tela* refaz a escolha. O texto devolvido
  pelo `selector` é trocado de volta pelo original (UTF-8), então as comparações das telas não mudam.

**Testes:** `tests/romm_library/run.sh` foi de 159 para 182 checagens: `screen_line` (uma linha, fim
preservado, `...`, largura medida com Pillow na fonte do tema: ≤ 1280 px e, com 900 px, ≤ 1024 px),
`screen_wrap` (UTF-8 intacto, ≤ 62 caracteres, palavras preservadas), conversão Latin-1, e a calibração
(escolher UTF-8, escolher Latin-1, B, refazer pelas Configurações, bytes recebidos pelo `selector`
conferidos). O mock do `selector` registra os bytes (`sel.raw`) e trata um menu de um item "OK" como aviso.

**Limites:** nada disso foi rodado no aparelho: só `dash` e `mawk` aqui, não o `ash`/`awk` do BusyBox. A
largura é uma estimativa conservadora com a fonte do tema (no Brick, 900 px é um palpite). Se alguma tela
ainda sair torta, uma foto diz se é largura, fonte ou codificação.
