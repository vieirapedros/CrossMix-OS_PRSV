# RomM Library - screentext.awk: prepara um texto UTF-8 para o infoscreen.
#
# O infoscreen chama o sdl2imgshow, que desenha com TTF_RenderText_Solid: o texto e lido como
# Latin-1 (nao UTF-8) e as linhas nao quebram sozinhas.  Sem tratamento, "nao" com til vira "NÃ£o",
# titulos com aspas curvas ou macrons viram lixo e linhas longas saem da tela.
#
# Entrada (stdin): texto UTF-8, uma linha de tela por linha.
# Saida: as mesmas linhas, quebradas na largura "px" (estimada para a fonte do tema no tamanho "fs"),
#        com tudo que nao e ASCII trocado por escapes "\0ooo" (octal, 1 byte Latin-1) ou por ASCII
#        (aspas curvas, reticencias, macrons...).  O shell converte os escapes com printf %b.
#        A barra invertida do texto original vira "\0134" para nao ser tomada como escape.
# Variaveis: -v fs=30 -v px=880 -v tbl=data/latin1.tsv
# Ao final o que sobrar com byte >= 0x80 (CJK etc.) e trocado por "?" pelo shell (tr).
# POSIX awk puro (mawk e BusyBox awk): so index/substr/length, nada de gsub com "\" na troca.

BEGIN {
  if (fs + 0 <= 0) fs = 30
  if (px + 0 <= 0) px = 880
  n = 0
  if (tbl != "") {
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
# arredondados para cima: melhor quebrar um pouco cedo do que cortar a borda da tela)
function cw(c) {
  if (c == " ") return 0.26
  if (length(c) > 1) return 0.62
  if (index("ijl.,:;'|!()[]I", c) > 0) return 0.36
  if (index("mMwW%@", c) > 0) return 0.90
  if (index("0123456789", c) > 0) return 0.56
  if (index("ABCDEFGHJKLNOPQRSTUVXYZ", c) > 0) return 0.74
  return 0.60
}

function enc(s,    out, i, k, ch) {
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

# quebra uma linha ja codificada: celulas = 1 caractere ASCII ou 1 escape "\0ooo" (5 caracteres)
function wrap(s,    i, L, c, m, w, lw, sp, k, out, first, start) {
  split("", cells)   # esvazia o vetor global (portavel entre mawk e BusyBox awk)
  L = length(s)
  m = 0
  i = 1
  while (i <= L) {
    c = substr(s, i, 1)
    if (c == "\\" && substr(s, i + 1, 1) == "0") { c = substr(s, i, 5); i += 5 } else i++
    cells[++m] = c
  }
  out = ""
  first = 1
  lw = 0
  sp = 0      # posicao (em cells) do ultimo espaco da linha atual
  k = 1
  start = 1
  while (k <= m) {
    c = cells[k]
    w = cw(c) * fs
    if (lw + w > px && k > start) {
      if (sp > start) {
        # quebra no ultimo espaco
        out = out (first ? "" : "\n") join(start, sp - 1)
        first = 0
        start = sp + 1
        k = start
      } else {
        # palavra maior que a linha: quebra dura
        out = out (first ? "" : "\n") join(start, k - 1)
        first = 0
        start = k
      }
      while (start <= m && cells[start] == " ") start++
      k = start
      lw = 0
      sp = 0
      continue
    }
    if (c == " ") sp = k
    lw += w
    k++
  }
  out = out (first ? "" : "\n") join(start, m)
  return out
}

function join(a, b,    r, i) {
  r = ""
  for (i = a; i <= b; i++) r = r cells[i]
  sub(/ +$/, "", r)     # sem espaco sobrando no fim da linha
  return r
}

{
  sub(/\r$/, "")
  print wrap(enc($0))
}
