#include "Game.h"

#include "Board.h"

#define C(x) x == ALIVE ? DEAD : ALIVE
#define DIS1(n, y) n == 0 ? y - 1 : n - 1
#define AUM1(n, y) (n + 1) % y
#define MAX(x, y) x > y ? x : y

barrier_t barrera;

int destino(tablero_h tablero, int i, int j) {
  int limitex = tablero->n;
  int limitey = tablero->m;
  size_t vecinosVivos = 0;
  //-------------------
  if (tablero->tab[DIS1(i, limitey)][DIS1(j, limitex)].estado == ALIVE)
    vecinosVivos++;
  if (tablero->tab[DIS1(i, limitey)][j].estado == ALIVE) vecinosVivos++;
  if (tablero->tab[DIS1(i, limitey)][(j + 1) % limitex].estado == ALIVE)
    vecinosVivos++;
  if (tablero->tab[i][DIS1(j, limitex)].estado == ALIVE) vecinosVivos++;
  if (tablero->tab[i][AUM1(j, limitex)].estado == ALIVE) vecinosVivos++;
  if (tablero->tab[AUM1(i, limitey)][DIS1(j, limitex)].estado == ALIVE)
    vecinosVivos++;
  if (tablero->tab[AUM1(i, limitey)][j].estado == ALIVE) vecinosVivos++;
  if (tablero->tab[AUM1(i, limitey)][AUM1(j, limitex)].estado == ALIVE)
    vecinosVivos++;
  //-----------------
  if (tablero->tab[i][j].estado == ALIVE) {
    if (2 == vecinosVivos || vecinosVivos == 3)  // 2 <= vecinosVivos <= 3
      return 0;
    else  // vecinosVivos == 1 || 4 <= vecinosVivos
      return 1;
  } else {  // == DEAD
    if (vecinosVivos == 3)
      return 1;
    else  // vecinosVivos != 3
      return 0;
  }
}

void agente_check(tablero_h tablero) {
  for (size_t i = tablero->intM.inicio; i < tablero->intM.fin; i++)
    for (size_t j = tablero->intN.inicio; j < tablero->intN.fin; j++) {
      tablero->tab[i][j].futuro = destino(tablero, i, j);
    }
}

void agente_update(tablero_h tablero) {
  for (size_t i = tablero->intM.inicio; i < tablero->intM.fin; i++)
    for (size_t j = tablero->intN.inicio; j < tablero->intN.fin; j++) {
      if (tablero->tab[i][j].futuro) {
        tablero->tab[i][j].estado = C(tablero->tab[i][j].estado);
        tablero->tab[i][j].futuro = 0;
      }
    }
}

void dividir(size_t max, size_t procs, intervalo* intervalos) {
  int tam = max / procs;
  int sobra = max % procs;
  int extremo = 0;
  for (int i = 0; i < procs; i++) {
    if (sobra) {
      intervalos[i].inicio = extremo;
      extremo += tam + 1;
      intervalos[i].fin = extremo;
      sobra--;
    } else {
      intervalos[i].inicio = extremo;
      extremo += tam;
      intervalos[i].fin = extremo;
    }
  }
}

tablero_h* calcular_intervalos(board_t tablero, size_t procs, int ciclos) {
  intervalo* intervalos = malloc(sizeof(intervalo) * procs);
  tablero_h* conjuntosTablero = malloc(sizeof(tablero_h) * procs);
  if (tablero->m >= tablero->n) {
    dividir(tablero->m, procs, intervalos);
    for (int i = 0; i < procs; i++) {
      conjuntosTablero[i] = malloc(sizeof(struct tablero_hilo));
      conjuntosTablero[i]->tab = tablero->tab;
      conjuntosTablero[i]->intM = intervalos[i];
      conjuntosTablero[i]->intN.inicio = 0;
      conjuntosTablero[i]->intN.fin = tablero->n;
      conjuntosTablero[i]->ciclos = ciclos;
      conjuntosTablero[i]->m = tablero->m;
      conjuntosTablero[i]->n = tablero->n;
    }
  } else {
    dividir(tablero->n, procs, intervalos);
    for (int i = 0; i < procs; i++) {
      conjuntosTablero[i] = malloc(sizeof(struct tablero_hilo));
      conjuntosTablero[i]->tab = tablero->tab;
      conjuntosTablero[i]->intN = intervalos[i];
      conjuntosTablero[i]->intM.inicio = 0;
      conjuntosTablero[i]->intM.fin = tablero->m;
      conjuntosTablero[i]->ciclos = ciclos;
      conjuntosTablero[i]->m = tablero->m;
      conjuntosTablero[i]->n = tablero->n;
    }
  }
  free(intervalos);
  return conjuntosTablero;
}

void libera_intervalos(tablero_h* conjunto, size_t procs) {
  for (size_t i = 0; i < procs; i++) free(conjunto[i]);
  free(conjunto);
}

void* hiloworker(void* tabinter) {
  tablero_h tablero = tabinter;
  int ciclos = tablero->ciclos;
  for (int i = 0; i < ciclos; i++) {
    agente_check(tablero);
    barrier_wait(&barrera);
    agente_update(tablero);
    barrier_wait(&barrera);
  }
  return NULL;
}

game_t* loadGame(const char* filename) {
  game_t* juego = malloc(sizeof(game_t));
  FILE* arch = fopen(filename, "r");
  size_t i, n, m;
  fscanf(arch, "%lu %lu %lu", &i, &m, &n);
  juego->cycles = i;
  juego->board = board_init(m, n);
  board_fill(arch, juego->board);
  fclose(arch);
  return juego;
}

/* Guardamos el tablero 'board' en el archivo 'filename' */
void writeBoard(board_t board, const char* filename) {
  size_t m = board->m;
  size_t n = board->n;
  FILE* arch = fopen(filename, "w");
  for (int i = 0; i < m; i++) {
    for (int j = 0; j < n; j++) fputc(board->tab[i][j].estado, arch);
    fputc('\n', arch);
  }
  fclose(arch);
}

board_t congwayGoL(game_t* juego, const int nuproc) {
  size_t cic = juego->cycles;
  tablero_h* tableroPorHilo = calcular_intervalos(juego->board, nuproc, cic);
  barrier_init(&barrera, nuproc);
  pthread_t trabajadores[nuproc];
  for (int i = 0; i < nuproc; i++)
    pthread_create(&trabajadores[i], NULL, hiloworker,
                   (void*)(tableroPorHilo[i]));
  for (int i = 0; i < nuproc; i++) pthread_join(trabajadores[i], NULL);
  libera_intervalos(tableroPorHilo, nuproc);
  return juego->board;
}
