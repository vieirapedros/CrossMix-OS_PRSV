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
| `RomMLibrary-sdcard.zip` | Extrair na raiz do cartão: cria `Apps/RomMLibrary/` (26 arquivos). |
| `JukaMix-fixes-sdcard.zip` | Extrair na raiz do cartão: substitui os 10 arquivos corrigidos. |
| `romm-library.patch` | Patch git do commit `272c5cff` (`git am`). |
| `RetroArch-probe-sdcard.zip` | **Substituído pelo `RetroArch-fix-sdcard.zip`.** Primeira versão da sonda (troca `Apps/RetroArch/launch.sh` e acrescenta `ra_probe.sh`). Guardado só para registro. |
| `RetroArch-fix-sdcard.zip` | Extrair na raiz do cartão (5 arquivos): daemon de entrada sem o anúncio de vibração (`trimui/app/trimui_inputd`, `System/resources/tsp_inputd` e `tsps_inputd`), sonda corrigida (`ra_probe.sh`) e `Apps/RetroArch/launch.sh`. Seção 8. |
| `jukamix-fixes.patch` | Patch git do commit `d0d8ff90` (`git am`, depois do anterior). |
| `retroarch-fix.patch` | Patch git (com `--binary`) do commit da correção do RetroArch (seção 8), `git am` depois dos anteriores. |
| `jukamix-romm-and-fixes.bundle` | Bundle git com a branch `release/2026-11-22-jukamix-romm` até a correção do RetroArch (requer `d5102fab`). |
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

- **Nada foi testado em hardware real.** Os testes são simulações (109 + 35 + 44 + 24 checagens); o
  daemon de entrada corrigido só foi verificado por comparação de bytes e disassembly, não executado.
- **RetroArch preso na tela de loading** ao abrir por Apps → RetroArch (relatado em 2026-11-22):
  causa provável identificada e correção entregue, **ainda não confirmada no aparelho**; ver a seção 8.
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
