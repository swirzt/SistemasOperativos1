#ifndef BOARD
#define BOARD

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ALIVE 'O'
#define DEAD 'X'

typedef struct _tupla {
  char estado;
  int futuro;
} tupla;

typedef struct intervalo_ {
  size_t inicio;
  size_t fin;
} intervalo;

typedef struct board_ {
  tupla** tab;
  size_t n;  // Columnas
  size_t m;  // Filas
} * board_t;

typedef struct tablero_hilo {
  tupla** tab;
  intervalo intN;  // Intervalo de columnas
  intervalo intM;  // Intervalo de filas
  unsigned int ciclos;
  size_t m;
  size_t n;
} * tablero_h;

// Inicializa el tablero
board_t board_init(size_t m, size_t n);

// Llena un tablero segun un archivo dado
void board_fill(FILE* archivo, board_t tablero);

// Borra un tablero
void board_del(board_t tablero);

// Imprime un tablero en pantalla
void board_print(size_t m, size_t n, tupla** tab);

#endif
