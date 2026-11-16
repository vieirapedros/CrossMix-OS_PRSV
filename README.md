# CrossMix-OS — TrimUI Smart Pro Edition

Este é um fork do [CrossMix-OS](https://github.com/cizia64/CrossMix-OS), mantido como uma distribuição **exclusiva para o TrimUI Smart Pro**.

## Objetivo

Manter uma base estável, enxuta e fácil de diagnosticar para um único dispositivo: o TrimUI Smart Pro.

Não há objetivo de manter compatibilidade com o TrimUI Smart Pro S, TG5050 ou qualquer outro handheld.

## Princípios

- Suportar apenas o TrimUI Smart Pro.
- Reduzir arquivos, temas, emuladores e recursos não utilizados.
- Centralizar caminhos, logs e utilitários em bibliotecas compartilhadas.
- Tornar atualizações e diagnósticos mais previsíveis.
- Preservar a licença GPL-3.0 e os créditos do projeto original.

## Estrutura

- `System/` — componentes do sistema, scripts, bibliotecas e atualizações.
- `Emus/` — launchers e configurações de emuladores.
- `RetroArch/` — núcleos e configurações do RetroArch.
- `Apps/` — aplicativos e PortMaster.
- `BIOS/` — BIOS e firmwares necessários.
- `Roms/` — estrutura de ROMs.
- `Themes/` — tema e recursos visuais.
- `_assets/` — fontes, ferramentas de build e hotfixes; mantido para manutenção futura.

## Limpeza inicial

Foram removidos artefatos que não pertencem ao ambiente do console:

- `.VolumeIcon.icns`
- `autorun.inf`
- `.github/workflows/CrossMix Release.yml`

Consulte `docs/INVENTORY.md` para o registro completo das mudanças.

## Licença

Este projeto é derivado do CrossMix-OS e é distribuído sob a GPL-3.0.
