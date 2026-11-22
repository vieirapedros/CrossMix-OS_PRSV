# utilitarios dos mocks: le e remove a primeira linha de uma fila
pop() { # arquivo -> imprime a primeira linha e a remove (vazio se nao houver)
  [ -s "$1" ] || return 0
  head -n 1 "$1"
  sed -i '1d' "$1"
}
