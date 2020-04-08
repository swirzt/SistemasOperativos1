#include <stdlib.h>

/* Definición de la estructura y sinónimo de tipo.*/
struct cond_barrier {
  unsigned int objetivo;
  unsigned int actual;
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
  return count;
}

/* Función *bloqueante* para esperar a los demás hilos */
int barrier_wait(barrier_t *barr) {
  while (barr->actual < barr->objetivo)
    ;
  return 0;
}

/* Eliminación de la barrera */
int barrier_destroy(barrier_t *barr) {
  free(barr);
  return 0;
}
