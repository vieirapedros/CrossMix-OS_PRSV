# Inventory

Este documento registra o escopo do fork e as mudanças de limpeza.

## Device scope

- Supported device: TrimUI Smart Pro.
- Unsupported devices: TrimUI Smart Pro S, TG5050 and any other handheld.

## Removed

| Path | Reason |
|---|---|
| `.VolumeIcon.icns` | macOS volume icon; not used by the console. |
| `autorun.inf` | Windows autoplay artifact; not used by the console. |
| `.github/workflows/CrossMix Release.yml` | Original project release workflow; replaced by a Smart Pro-only maintenance workflow later. |

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
| `Themes/` | Active theme and UI assets. |
| `Data/` | Configuration and metadata. |

## Next cleanup candidates

Before removal, each candidate must be checked for references from `System/`, `Emus/`, `RetroArch/`, themes and launcher scripts:

- Unused themes.
- Unused backgrounds, icons and images.
- Unused applications.
- Unused emulator launchers.
- Unused RetroArch cores and assets.
