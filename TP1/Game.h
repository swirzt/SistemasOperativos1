#include "Board.h"

/******************************************************************************/
/* Representamos las células vivas como 'O' y las muertas como 'X' */
#define ALIVE 'O'
#define DEAD 'X'
/******************************************************************************/
/* La estructura de un juego es simplemente un tablero y la cantidad de veces
que se va a iterar */
typedef struct _game {
  board_t board;
  unsigned int cycles;
} game_t;

/******************************************************************************/

/* Cargamos el juego desde un archivo */
game_t *loadGame(const char *filename) {
  game_t *juego = malloc(sizeof(game_t));
  FILE *arch = fopen(filename, "r");
  size_t i, n, m;
  fscanf(arch, "%lu %lu %lu", &i, &m, &n);
  juego->cycles = i;
  juego->board = board_init(m, n);
  board_fill(arch, juego->board);
  fclose(arch);
  return juego;
}

/* Guardamos el tablero 'board' en el archivo 'filename' */
void writeBoard(board_t board, const char *filename) {
  size_t m = board->m;
  size_t n = board->n;
  FILE *arch = fopen(filename, "w");
  for (int i = 0; i < m; i++) {
    for (int j = 0; j < n; j++) fputc(board->tab[i][j].estado, arch);
    fputc('\n', arch);
  }
  fclose(arch);
}

/* Simulamos el Juego de la Vida de Conway con tablero 'board' la cantidad de
ciclos indicados en 'cycles' en 'nuprocs' unidades de procesamiento*/
board_t congwayGoL(board_t board, unsigned int cycles, const int nuproc);
