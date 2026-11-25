# RomM Library - screentext.awk: prepara texto UTF-8 para os programas de tela do sistema.
#
# Os dois desenham com TTF_RenderText_Solid/Blended, que leem o texto como Latin-1 (nao UTF-8):
#   - infoscreen (sdl2imgshow): desenha UMA linha so.  Quebra de linha vira o quadradinho "sem glifo" e o
#     que passa da largura sai da tela.  Entao: tudo numa linha, cortado com "..." para caber.
#   - selector (menus, titulos, avisos): aceita varias linhas no titulo, mas tambem le Latin-1.
#
# Modos (-v mode=):
#   conv  converte linha a linha, sem quebrar nem juntar  (itens e titulos do selector)
#   line  junta todas as linhas em UMA ("a - b - c"), converte e corta com "..." na largura px; com
#         -v tail=TEXTO anexa " - TEXTO" ao fim, que nunca e cortado  (infoscreen)
#   wrap  NAO converte (continua UTF-8): so quebra as linhas por palavra na largura px  (avisos no selector)
#
# Conversao (conv e line): U+00A0..FF viram \0ooo (octal, 1 byte Latin-1; o shell converte com printf %b);
#   pontuacao tipografica e letras latinas fora do Latin-1 viram ASCII (data/latin1.tsv); a barra
#   invertida do texto vira \0134.  O que sobrar com byte >= 0x80 (CJK...) o shell troca por "?" (tr).
# Variaveis: -v fs=30 -v px=880 -v tbl=data/latin1.tsv [-v tail=...]
# POSIX awk puro (mawk e BusyBox awk): so index/substr/length, nada de gsub com "\" na troca.

BEGIN {
  if (fs + 0 <= 0) fs = 30
  if (px + 0 <= 0) px = 880
  if (mode == "") mode = "conv"
  ns = 0
  n = 0
  if (mode != "wrap" && tbl != "") {
    while ((getline ln < tbl) > 0) {
      if (ln == "" || substr(ln, 1, 1) == "#") continue
      t = index(ln, "\t")
      if (t < 2) continue
      n++
      from[n] = substr(ln, 1, t - 1)
      to[n] = substr(ln, t + 1)
    }
    close(tbl)
  }
}

# troca todas as ocorrencias de a por b em s (sem regex, sem tratar "\" ou "&" na troca)
function repl(s, a, b,    out, i, la) {
  la = length(a)
  if (la == 0) return s
  out = ""
  while ((i = index(s, a)) > 0) {
    out = out substr(s, 1, i - 1) b
    s = substr(s, i + la)
  }
  return out s
}

# largura estimada de uma celula, em fracao do corpo da fonte (valores medidos na fonte do tema,
# arredondados para cima: melhor quebrar/cortar um pouco cedo do que sair da borda da tela)
function cw(c) {
  if (c == " ") return 0.26
  if (length(c) > 1) return 0.62
  if (index("ijl.,:;'|!()[]I", c) > 0) return 0.36
  if (index("mMwW%@", c) > 0) return 0.90
  if (index("0123456789", c) > 0) return 0.56
  if (index("ABCDEFGHJKLNOPQRSTUVXYZ", c) > 0) return 0.74
  return 0.60
}

function enc(s,    out, i, k) {
  # 1) barra invertida do original
  out = ""
  while ((i = index(s, "\\")) > 0) {
    out = out substr(s, 1, i - 1) "\\0134"
    s = substr(s, i + 1)
  }
  s = out s
  # 2) Latin-1 / ASCII da tabela (so se houver algo fora do ASCII imprimivel)
  if (s ~ /[^ -~]/) {
    for (k = 1; k <= n; k++) {
      if (index(s, from[k]) > 0) s = repl(s, from[k], to[k])
    }
  }
  return s
}

# separa s em celulas (arr): 1 caractere ou, se tok, 1 escape "\0ooo" (5 caracteres). Devolve o numero.
function cells_of(s, arr, tok,    i, L, c, m) {
  split("", arr)
  L = length(s)
  m = 0
  i = 1
  while (i <= L) {
    c = substr(s, i, 1)
    if (tok && c == "\\" && substr(s, i + 1, 1) == "0") { c = substr(s, i, 5); i += 5 } else i++
    arr[++m] = c
  }
  return m
}

function join(arr, a, b,    r, i) {
  r = ""
  for (i = a; i <= b; i++) r = r arr[i]
  sub(/ +$/, "", r)     # sem espaco sobrando no fim da linha
  return r
}

# largura estimada, em px, de um texto ja codificado
function width(s,    m, i, w) {
  m = cells_of(s, wc, 1)
  w = 0
  for (i = 1; i <= m; i++) w += cw(wc[i]) * fs
  return w
}

# corta s (ja codificado) para caber em maxpx, terminando em "..." se precisou cortar
function fit(s, maxpx,    m, i, w, ell, out) {
  if (width(s) <= maxpx) return s
  m = cells_of(s, fc, 1)
  ell = 3 * cw(".") * fs
  w = 0
  out = ""
  for (i = 1; i <= m; i++) {
    w += cw(fc[i]) * fs
    if (w + ell > maxpx) break
    out = out fc[i]
  }
  sub(/ +$/, "", out)
  return out "..."
}

# quebra uma linha por palavra na largura px.  No modo wrap (tok=0) o texto e UTF-8: uma palavra maior que a
# linha NAO e partida (cortaria um caractere ao meio); ela so passa da largura.
function wrap(s, tok,    m, k, start, lw, sp, w, c, out, first) {
  m = cells_of(s, ca, tok)
  out = ""
  first = 1
  lw = 0
  sp = 0      # posicao (em celulas) do ultimo espaco da linha atual
  start = 1
  k = 1
  while (k <= m) {
    c = ca[k]
    w = cw(c) * fs
    if (lw + w > px && k > start) {
      if (sp > start) {
        out = out (first ? "" : "\n") join(ca, start, sp - 1)
        first = 0
        start = sp + 1
        k = start
        lw = 0
        sp = 0
        continue
      }
      # sem onde quebrar antes: deixa a palavra passar ate o proximo espaco
      while (k <= m && ca[k] != " ") { lw += cw(ca[k]) * fs; k++ }
      if (k > m) break
      out = out (first ? "" : "\n") join(ca, start, k - 1)
      first = 0
      start = k + 1
      k = start
      lw = 0
      sp = 0
      continue
    }
    if (c == " ") sp = k
    lw += w
    k++
  }
  out = out (first ? "" : "\n") join(ca, start, m)
  return out
}

{
  sub(/\r$/, "")
  if (mode == "wrap") {
    print wrap($0, 0)
  } else if (mode == "line") {
    if ($0 ~ /[^ \t]/) seg[++ns] = $0
  } else {
    print enc($0)
  }
}

END {
  if (mode == "line") {
    main = ""
    for (i = 1; i <= ns; i++) main = main (i > 1 ? " - " : "") seg[i]
    main = enc(main)
    te = enc(tail)
    avail = px
    if (te != "") avail = px - width(" - " te)
    if (avail < 4 * fs) avail = 4 * fs
    out = fit(main, avail)
    if (te != "") out = (out != "" ? out " - " : "") te
    print out
  }
}
