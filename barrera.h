#include <pthread.h>
#include <stdlib.h>

pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

/* Definición de la estructura y sinónimo de tipo.*/
struct cond_barrier {
  unsigned int objetivo;
  unsigned int actual;
  pthread_cond_t cond;
};

typedef struct cond_barrier barrier_t;
/************/

/************/
/* Operaciones*/

/* Creación de una barrera de condición, tomando como argumento la cantidad de
hilos que se van a esperar*/
int barrier_init(barrier_t *barr, unsigned int count) {
  barr->objetivo = count;
  barr->actual = 0;
  pthread_cond_init(&barr->cond, NULL);
  return count;
}

/* Función *bloqueante* para esperar a los demás hilos */
int barrier_wait(barrier_t *barr) {
  pthread_mutex_lock(&mutex);
  barr->actual++;
  if (barr->actual == barr->objetivo)
    pthread_cond_broadcast(&barr->cond);
  else
    pthread_cond_wait(&barr->cond, &mutex);
  pthread_mutex_unlock(&mutex);
  return 0;
}

/* Eliminación de la barrera */
int barrier_destroy(barrier_t *barr) {
  free(barr);
  return 0;
}
