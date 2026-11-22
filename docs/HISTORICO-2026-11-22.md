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
| `jukamix-fixes.patch` | Patch git do commit `d0d8ff90` (`git am`, depois do anterior). |
| `jukamix-romm-and-fixes.bundle` | Bundle git com a branch `fix/jukamix-review` (contém os dois commits; requer `d5102fab`). |
| `SHA256SUMS.txt` | Hashes para conferir a integridade (`sha256sum -c SHA256SUMS.txt`). |

Os dois zips são independentes. Patches e bundle servem só para o git; não vão ao cartão.

## 5. Instalação resumida

1. Backup de `Roms/`, `BIOS/`, `Saves/`, `Data/` e personalizações.
2. Formatar o cartão em FAT32 e extrair o release do JukaMix na raiz.
3. Ligar uma vez e conferir o JukaMix puro (inclusive abrir um jogo no RetroArch).
4. Desligar, extrair os dois zips na raiz do cartão (aceitar substituir os 10 arquivos) e ligar de novo.
5. Conectar o Wi-Fi, ligar o Tailscale (System Tools → NETWORK → Tailscale) e abrir Apps → RomM Library.

Detalhes de uso: `Apps/RomMLibrary/README.md`.

## 6. Como trazer para a `main` (decisão pendente)

As três branches nascem do `d5102fab` (JukaMix), **não** da `main`. Para unir à `main`:

- Um merge de `feat/romm-library` na `main` vai gerar conflitos de "adicionado nos dois lados" nos
  arquivos do RomMLibrary antigo que ainda estão na `main` (`README.md`, `config.json`,
  `lib/download.sh`). O mais simples é remover o RomMLibrary antigo da `main` antes.
- Alternativa: tratar a branch `release/2026-11-22-jukamix-romm` como a nova base e abandonar as
  sobras da fase anterior.

## 7. Limitações e pendências

- **Nada foi testado em hardware real.** Os testes são simulações (109 + 35 checagens).
- **RetroArch preso na tela de loading** (relatado em 2026-11-22): a análise estática dos scripts
  não achou a causa. Pendente: testar no JukaMix puro, rodar System Logs - Collect e enviar
  `System/logs/diagnostics_<data>.txt`; testar versões mais antigas do RetroArch (segurar Y ao abrir).
- Causa de os apps antigos não abrirem no fw 1.1.1: não determinada.
- O id do ScreenScraper para WonderSwan Color (45) não foi confirmado online; pode ser 46.
- No teste existente `tests/logging_test.sh` uma checagem falha no caminho que só usa `logread`;
  provavelmente é do ambiente de teste, não foi investigado.
- RomM Library: sem suporte a IPv6 literal; os arquivos não são verificados por hash (só o tamanho esperado).
