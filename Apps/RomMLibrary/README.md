# RomM Library

RomM Library integra o TrimUI Smart Pro com uma instância self-hosted do RomM no seu NAS.

## Recursos

- Teste de conexão com RomM.
- Listagem de plataformas.
- Busca de ROMs.
- Download de ROM por ID.
- Cache local de capa e metadados.
- Configuração para acesso local, Tailscale ou HTTPS.

## Configuração

Edite `Apps/RomMLibrary/config.json`:

```json
{
  "url": "http://SEU-IP-TAILSCALE:3000",
  "token": "SEU_TOKEN_ROMM",
  "download_dir": "/mnt/SDCARD/Roms",
  "cache_dir": "/mnt/SDCARD/Data/romm/cache"
}
```

Use um token RomM dedicado, com permissões somente de leitura quando possível.

## Uso

Abra **Apps > RomM Library** no Smart Pro.

Para testar pela linha de comando:

```sh
/mnt/SDCARD/Apps/RomMLibrary/romm.sh
```

## Segurança

- Prefira Tailscale para acesso remoto.
- Não exponha o RomM diretamente à internet sem HTTPS e autenticação.
- Não versione tokens reais neste repositório.
