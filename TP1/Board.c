#include "Board.h"

board_t board_init(size_t m, size_t n) {
  board_t tablero = malloc(sizeof(struct board_));
  tablero->n = n;
  tablero->m = m;
  tablero->tab = malloc(sizeof(tupla *) * m);
  return tablero;
}

void board_fill(FILE *archivo, board_t tablero) {
  size_t n = tablero->n;
  size_t m = tablero->m;
  char *temp = malloc(sizeof(char) * (n + 1));
  for (size_t i = 0; i < m; i++) {
    fscanf(archivo, "%s", temp);
    tablero->tab[i] = malloc(sizeof(tupla) * (n + 1));
    for (int j = 0; j < n; j++) {
      tablero->tab[i][j].estado = temp[j];
      tablero->tab[i][j].futuro = 0;
    }
  }
  free(temp);
}

void board_del(board_t tablero) {
  size_t m = tablero->m;
  for (size_t i = 0; i < m; i++) free(tablero->tab[i]);
  free(tablero->tab);
  free(tablero);
}

void board_print(size_t m, size_t n, tupla **tab) {
  for (int i = 0; i < m; i++) {
    for (int j = 0; j < n; j++) printf("%c", tab[i][j].estado);
    printf("\n");
  }
}