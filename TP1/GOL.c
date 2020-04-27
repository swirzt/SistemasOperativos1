#include <pthread.h>
#include <sys/sysinfo.h>
#include <unistd.h>

#include "Game.h"
#include "barrera.h"

typedef struct intervalo_ {
  size_t inicio;
  size_t fin;
} intervalo;

typedef struct tablero_hilo {
  tupla** tab;
  intervalo intN;  // Intervalo de columnas
  intervalo intM;  // Intervalo de filas
  int ciclos;
} * tablero_h;

#define C(x) x == ALIVE ? DEAD : ALIVE
#define DIS1(n, y) n == 0 ? y - 1 : n - 1
#define AUM1(n, y) (n + 1) % y

pthread_mutex_t mut = PTHREAD_MUTEX_INITIALIZER;
barrier_t barrera;
game_t* jueguito;
size_t m, n;

int destino(tablero_h tablero, int i, int j) {
  size_t vecinosVivos = 0;
  size_t limitex = n;
  size_t limitey = m;
  //-------------------
  if (tablero->tab[DIS1(i, limitey)][DIS1(j, limitex)].estado == ALIVE)
    vecinosVivos++;
  if (tablero->tab[DIS1(i, limitey)][j].estado == ALIVE) vecinosVivos++;
  if (tablero->tab[DIS1(i, limitey)][AUM1(j, limitex)].estado == ALIVE)
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
// XXXXXXX
// XXXXXOX
// XXXOXOX
// XXXXOOX
// XXXXXXX

// XXXXXXX
// XXXXOXX
// XXXXXOO
// XXXXOOX
// XXXXXXX

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
    }
  } else {
    dividir(tablero->n, procs, intervalos);
    for (int i = 0; i < procs; i++) {
      conjuntosTablero[i] = malloc(sizeof(struct tablero_hilo));
      conjuntosTablero[i]->tab = tablero->tab;
      conjuntosTablero[i]->intN = intervalos[i];
      conjuntosTablero[i]->intM.inicio = 0;
      conjuntosTablero[i]->intM.fin = tablero->n;
      conjuntosTablero[i]->ciclos = ciclos;
    }
  }
  return conjuntosTablero;
}

void* hiloworker(void* tabinter) {
  tablero_h tablero = tabinter;
  int ciclos = tablero->ciclos;
  for (int i = 0; i < ciclos; i++) {
    agente_check(tablero);
    barrier_wait(&barrera);
    agente_update(tablero);
    barrier_wait(&barrera);
    pthread_mutex_lock(&mut);
    board_print(m, n, tablero->tab);
    printf("------------------------\n");
    pthread_mutex_unlock(&mut);
  }
  return NULL;
}

int main(int argc, char* argv[]) {
  int cantProcesos = atoi(argv[2]);
  if (!cantProcesos) cantProcesos = get_nprocs();
  barrier_init(&barrera, cantProcesos);
  jueguito = loadGame(argv[1]);
  size_t cic = jueguito->cycles;
  pthread_t trabajadores[cantProcesos];
  m = jueguito->board->m;
  n = jueguito->board->n;
  tablero_h* intervalos =
      calcular_intervalos(jueguito->board, cantProcesos, cic);
  for (int i = 0; i < cantProcesos; i++)
    pthread_create(&trabajadores[i], NULL, hiloworker, (void*)(intervalos[i]));
  for (int i = 0; i < cantProcesos; i++) pthread_join(trabajadores[i], NULL);
  return 0;
}