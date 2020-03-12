// a) No llega a 2N porque las instrucciones de copiar de la pila y pegar en la
// pila puede ndesfazarse y provocar que se calcule 2 veces el mismo numero en
// vez de incrementar el total

// b) Para números pequeños no hay tanto tiempo de ejecución para permitir la
// generación de un desfaze

// c) El mínimo valor que puede imprimir es NVisitantes, donde la copia de la
// pila esta siempre desfazada en cada hilo por lo tanto cada hilo incrementaría
// Nvisitantes veces y nunca cambiarían el numero del otro.

/* POSIX Threads */
#include <pthread.h>
/* Assert library */
#include <assert.h>
/* I/O*/
#include <stdio.h>
/*malloc*/
#include <stdlib.h>

/* Constantes */
#define NVisitantes 1000000000
/*
  Problema introductorio a exclusión mutua.
 */

void *turnstile(void *argV) {
  for (int j = 0; j < NVisitantes; j++) (*(int *)argV)++;
  return NULL;
}

int flag1 = 0, flag2 = 0, turno = 1;
void *FakeThread1(void *arg) {
  for (int i = 0; i < NVisitantes; i++) {
    flag1 = 1;
    turno = 2;
    while (flag2 && turno == 2)
      ;
    (*(int *)arg)++;
    flag1 = 0;
  }
  return NULL;
}

void *FakeThread2(void *arg) {
  for (int i = 0; i < NVisitantes; i++) {
    flag2 = 1;
    turno = 1;
    while (flag1 && turno == 1)
      ;
    (*(int *)arg)++;
    flag2 = 0;
  }
  return NULL;
}

pthread_mutex_t mut = PTHREAD_MUTEX_INITIALIZER;

void *MutexThread(void *arg) {
  for (int i = 0; i < NVisitantes; i++) {
    pthread_mutex_lock(&mut);
    (*(int *)arg)++;
    pthread_mutex_unlock(&mut);
  }
}

int main(void) {
  pthread_t ts[2];

  /* Variable compartida */
  int *counter = malloc(sizeof(int));
  *counter = 0;
  /********************/

  /********************/
  /* Se crean NHilos */
  // Llamado original
  // assert(!pthread_create(&ts[0], NULL, turnstile, (void *)(counter)));
  // assert(!pthread_create(&ts[1], NULL, turnstile, (void *)(counter)));

  // Forma en teoría
  // assert(!pthread_create(&ts[0], NULL, FakeThread1, (void *)(counter)));
  // assert(!pthread_create(&ts[1], NULL, FakeThread2, (void *)(counter)));

  // Forma con mutex
  assert(!pthread_create(&ts[0], NULL, MutexThread, (void *)(counter)));
  assert(!pthread_create(&ts[1], NULL, MutexThread, (void *)(counter)));
  /* Se espera a que terminen */
  assert(!pthread_join(ts[0], NULL));
  assert(!pthread_join(ts[1], NULL));

  /* Se muestra el resultado del día */
  printf("NVisitantes en total: %d\n", *counter);
  /*
    Resultado esperado sería NVisitantes*NHilos. ¿Siempre entrega el mismo
    resultado?
   */
  free(counter);
  return 0;
}
