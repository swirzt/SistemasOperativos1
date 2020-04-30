#ifndef GAME
#define GAME
#include "Board.h"
#include "barrera.h"
#include <sys/sysinfo.h>
#include <unistd.h>

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

typedef struct tablero_hilo {
  tupla** tab;
  intervalo intN;  // Intervalo de columnas
  intervalo intM;  // Intervalo de filas
  unsigned int ciclos;
  size_t m;
  size_t n;
} * tablero_h;

/******************************************************************************/

int destino(tablero_h tablero, int i, int j);

void agente_check(tablero_h tablero);

void agente_update(tablero_h tablero);

void dividir(size_t max, size_t procs, intervalo* intervalos);

tablero_h* calcular_intervalos(board_t tablero, size_t procs, int ciclos);

void libera_intervalos(tablero_h* conjunto, size_t procs);

void* hiloworker(void* tabinter);

/* Cargamos el juego desde un archivo */
game_t *loadGame(const char *filename);

/* Guardamos el tablero 'board' en el archivo 'filename' */
void writeBoard(board_t board, const char *filename);

/* Simulamos el Juego de la Vida de Conway con tablero 'board' la cantidad de
ciclos indicados en 'cycles' en 'nuprocs' unidades de procesamiento*/
void congwayGoL(game_t* board, const int nuproc);

#endif