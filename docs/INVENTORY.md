# Inventory

Este documento registra o escopo do fork e as mudanças de limpeza.

## Device scope

- Supported device: TrimUI Smart Pro.
- Unsupported devices: TrimUI Smart Pro S, TG5050 and any other handheld.

## Visual setup

The selected visual setup is intentionally dark, discreet and lightweight:

| Asset type | Kept pack |
|---|---|
| Theme | `Epic Noir` |
| Icons | `Epic Noir (Controllers)` |
| Background | `No Backgrounds` |
| System Tools icons | `Default` |
| System Tools background | `Default` |

`Icons/Default` and `Backgrounds/Default` are retained because `_SystemTools/config.json` references them explicitly.

## Removed

| Path | Reason |
|---|---|
| `.VolumeIcon.icns` | macOS volume icon; not used by the console. |
| `autorun.inf` | Windows autoplay artifact; not used by the console. |
| `.github/workflows/CrossMix Release.yml` | Original project release workflow; replaced by a Smart Pro-only maintenance workflow later. |

## Asset pruning

`System/usr/trimui/scripts/tools/prune-assets.sh` moves unused theme, icon and background packs to:

```text
/mnt/SDCARD/.Trash/assets-<timestamp>/
```

It does not permanently delete files. The retained packs are:

- `Themes/Epic Noir`
- `Icons/Epic Noir (Controllers)`
- `Backgrounds/No Backgrounds`
- `Icons/Default`
- `Backgrounds/Default`

## Retained for now

| Path | Reason |
|---|---|
| `_assets/` | Contains sources, toolchain, scripts, hotfixes and theme assets needed for future builds and maintenance. |
| `System/` | Core OS files, libraries, scripts and update components. |
| `Emus/` | Emulator launchers and configuration. |
| `RetroArch/` | RetroArch cores, settings and assets. |
| `Apps/` | Applications and PortMaster. |
| `BIOS/` | BIOS and firmware files. |
| `Roms/` | ROM directory structure. |
| `Data/` | Configuration and metadata. |
