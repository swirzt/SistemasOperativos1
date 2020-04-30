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

typedef struct intervalo_ {
  size_t inicio;
  size_t fin;
} intervalo;

typedef struct tablero_hilo {
  tupla** tab;
  intervalo intN;  // Intervalo de columnas
  intervalo intM;  // Intervalo de filas
  unsigned int ciclos;
  size_t m;
  size_t n;
} * tablero_h;

/******************************************************************************/

//Revisa el valor de las 8  celdas vecinas a la celda que recibe
//Según la cantidad de vecinos vivos y el estado actual de la celda
//revisa que condicion cumple (si vive o muere) y devuelve 1 si debe 
//cambiar su estado o 0 si debe permanecer igual
int destino(tablero_h tablero, int i, int j);

//Revisa cada celda del tablero, de ser necesario modifica el valor almacenado en futuro
void agente_check(tablero_h tablero);

//Revisa cada celda del tablero y según el valor almacenado en futuro la modifica o no
void agente_update(tablero_h tablero);

//Recibe un tamaño de filas o columnas, la cantidad de hilos y un array vacio de intervalo
//Divide los intervalos y los almacena en intervalos
void dividir(size_t max, size_t procs, intervalo* intervalos);

//Según la cantidad de hilos, elmáximo entre filas y columnas y la cantidad de ciclos a ejecutar
//Devuelve un array de tablero_h con todos los elementos listos para ser enviados a sus hilos correspondientes
tablero_h* calcular_intervalos(board_t tablero, size_t procs, int ciclos);

//Elimina un array de tablero_h
void libera_tablero_h(tablero_h* conjunto, size_t procs);

//Recibe un tablero_h de forma void*
//Realiza el casteo correspondiente y realiza la ejecucion de los ciclos correspondientes
void* hiloworker(void* tabinter);

/* Cargamos el juego desde un archivo */
game_t *loadGame(const char *filename);

/* Guardamos el tablero 'board' en el archivo 'filename' */
void writeBoard(board_t board, const char *filename);

/* Simulamos el Juego de la Vida de Conway con game_t* juego
en 'nuprocs' unidades de procesamiento*/
void congwayGoL(game_t* juego, const int nuproc);

#endif
