# Smart Pro Apps

Estes aplicativos sao exclusivos do fork CrossMix-OS para TrimUI Smart Pro.

## Instalacao

Para instalar apenas o RomM Library:

```bash
./install-romm-library.sh /caminho/do/cartao
```

Para instalar todos os apps do projeto:

```bash
./install-smartpro-apps.sh /caminho/do/cartao
```

## Apps

| App | Funcao |
|---|---|
| RomM Library | Navega, busca e baixa ROMs do RomM no NAS |
| Smart Pro Game Center | Favoritos, recentes e tempo de jogo |
| Port Manager | Instala, lista e remove ports |
| BIOS Doctor | Verifica BIOS ausentes ou presentes |
| Wi-Fi Tools | Diagnostico de rede e teste do RomM |
| Battery Guard | Monitora bateria e registra historico |
| Theme Switcher | Troca temas com backup automatico |

## Seguranca

- Nao versione tokens do RomM.
- Prefira Tailscale para acesso remoto.
- O Port Manager move ports removidos para `.Trash`.
- O BIOS Doctor apenas diagnostica; nao copia BIOS automaticamente.
