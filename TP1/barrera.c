#include "barrera.h"

/* Creación de una barrera de condición, tomando como argumento la cantidad de
hilos que se van a esperar*/
int barrier_init(barrier_t *barr, unsigned int count) {
  barr->objetivo = count;
  barr->actual = 0;
  pthread_mutex_init(&barr->mutex, NULL);
  pthread_cond_init(&barr->cond, NULL);
  return count;
}

/* Función *bloqueante* para esperar a los demás hilos */
void barrier_wait(barrier_t *barr) {
  pthread_mutex_lock(&barr->mutex);
  barr->actual++;
  if (barr->actual == barr->objetivo) {
    barr->actual = 0;
    pthread_cond_broadcast(&barr->cond);
  } else
    pthread_cond_wait(&barr->cond, &barr->mutex);
  pthread_mutex_unlock(&barr->mutex);
}

/* Eliminación de la barrera */
void barrier_destroy(barrier_t *barr) { free(barr); }
