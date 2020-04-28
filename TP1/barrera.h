#ifndef COLA
#define COLA

#include <pthread.h>
#include <stdlib.h>

/* Definición de la estructura y sinónimo de tipo.*/
struct cond_barrier {
  pthread_mutex_t mutex;
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
int barrier_init(barrier_t *barr, unsigned int count);

/* Función *bloqueante* para esperar a los demás hilos */
void barrier_wait(barrier_t *barr);

/* Eliminación de la barrera */
void barrier_destroy(barrier_t *barr);

#endif