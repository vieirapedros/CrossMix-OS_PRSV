# RomM Library

App da aba **Apps** (JukaMix / CrossMix OS, TrimUI Smart Pro) para **navegar e baixar jogos do seu servidor [RomM](https://romm.app)** direto para as pastas `Roms/` do cartão. Funciona pela rede local ou pelo **Tailscale**.

## Instalar

Copie a pasta `Apps/RomMLibrary` para o cartão SD (o zip já vem com o caminho certo: extraia na raiz do cartão, mesclando). Reabra a aba Apps.

## Primeiro uso

1. Ligue o Tailscale (se o RomM estiver na sua tailnet): **System Tools → NETWORK → Tailscale**.
2. Abra **RomM Library**. O assistente pede:
   - **Servidor**: `http://100.x.y.z:8080` (IP do Tailscale do NAS) ou `http://nome-do-nas:porta`. O app aceita `http`/`https`, com ou sem `/api` no fim.
   - **Login**: usuário e senha, ou um **token de API** (RomM → Perfil → *Client API Tokens*; começa com `rmm_`).
3. Ele testa a conexão e mostra a versão do RomM e quantas plataformas encontrou.

Dentro do Tailscale o tráfego já é criptografado; `http://` é o jeito mais simples. Se usar `https://` com certificado próprio e der erro, ligue *Aceitar certificado HTTPS inválido* nas Configurações.

## Usando

- **Explorar plataformas** → escolha a plataforma → lista paginada (A–Z). No topo: `[ Buscar... ]` (dentro da plataforma) e `[ Ir para a letra... ]`.
- **Buscar jogo** no menu principal procura em todas as plataformas.
- `* ` na frente do nome = o arquivo já está no cartão.
- Escolha o jogo → **Baixar para o cartão SD**. Aparece o progresso; **B para** e o download pode ser **retomado** depois (basta baixar de novo).
- Terminando, o app apaga o cache da lista da pasta (`*_cache*.db`); se o jogo não aparecer, reinicie o MainUI.

### Para qual pasta vai?

O app conhece as plataformas comuns (GBA→`Roms/GBA`, SNES→`Roms/SFC`, Mega Drive→`Roms/MD`, PlayStation→`Roms/PS`…; tabela em `data/platform_map.tsv`). Para as que não conhece (ex.: *Arcade*, *GameCube*) ele **pergunta uma vez** e lembra. *Configurações → Esquecer pastas lembradas* zera isso. Obs.: no CrossMix `Roms/NGC` é Neo Geo Pocket Color, não GameCube.

Jogos de vários arquivos (ex.: PS1 `.cue` + `.bin`) chegam em ZIP e são extraídos para a pasta. ROMs que já são um `.zip` (arcade) ficam intactas. Caracteres que o cartão FAT/exFAT não aceita (`: * ? " < > | / \`) viram `_` no nome do arquivo.

## Arquivos

| O quê | Onde |
|---|---|
| Config (URL, login, token, pastas lembradas) | `Data/romm/config.json` — **texto puro, não versione** (já está no `.gitignore`) |
| Log | `System/logs/romm_library.log` (nunca contém senha/token) |
| Exemplo de config | `Apps/RomMLibrary/config.example.json` |

Chaves do `config.json` (todas texto): `base_url`, `token`, `username`, `password`, `page_size` (5–100), `lang` (`pt`/`en`; use `en` se algum acento ainda sair errado nas telas de aviso), `insecure` (`1` aceita certificado inválido), `font_size` (opcional, tamanho de fonte das listas).

## Se algo der errado

| Sintoma | O que fazer |
|---|---|
| O app não abre | Veja `System/logs/romm_library.log`: a 1ª linha (`launch.sh iniciou`) mostra se o script chegou a rodar. |
| "Não encontrei o servidor" | O nome (MagicDNS) não resolve no aparelho. Use o IP `100.x.y.z`. O app também tenta resolver o nome pelo próprio Tailscale. |
| "Não consegui conectar" | Servidor desligado, porta errada, ou Tailscale parado (o app avisa o estado do Tailscale). |
| "Login recusado" | Usuário/senha ou token errados. O app tenta também o login OAuth caso o Basic seja recusado. |
| Download parou / caiu | Baixe o mesmo jogo de novo: continua de onde parou. *Configurações → Apagar downloads incompletos* limpa restos. |
| "Sem espaço livre" | O app confere o espaço antes (e dobra a conta para jogos extraídos de ZIP). |
| Texto embaralhado ou cortado nas telas de download e de aviso | Essas telas usam o `infoscreen` do sistema, que desenha o texto como Latin-1 e não quebra linhas. O app converte os acentos, troca o que a fonte não tem por ASCII (aspas curvas, `…`, `–`) ou por `?` (japonês, chinês) e quebra as linhas (`lib/screentext.awk`, `data/latin1.tsv`). Os menus usam o `selector`, que lê UTF-8. Se ainda aparecer algo estranho, tire uma foto da tela e abra um issue. |

## Limitações

- Endereços IPv6 literais não são suportados.
- Os arquivos não são verificados por hash: o app só confere o tamanho esperado.
- Feito para a API do RomM 4.x. Se uma rota de download não existir na sua versão, o app tenta as outras duas conhecidas.

## Desenvolvimento

`bash tests/romm_library/run.sh` roda testes unitários e de ponta a ponta contra um servidor RomM simulado (`tests/romm_library/mock_server.py`) com `selector`, teclado virtual e `infoscreen` simulados. Precisa de `python3`, `jq`, `curl` e `dash`. Isso **não substitui** teste no aparelho.
