#include <pthread.h>
#include <stdlib.h>

struct semaphore_t {
  pthread_mutex_t mut;
  int s;
  pthread_cond_t espera;
};

typedef struct semaphore_t sem_t;

/* Función de creación de Semáforo */
void sem_init(sem_t *sem, int init) {
  sem->mut = PTHREAD_MUTEX_INITIALIZER;
  sem->espera = PTHREAD_COND_INITIALIZER;
  sem->s = init;
}

/* Incremento del semáforo. */
void sem_incr(sem_t *sem) {
  pthread_mutex_lock(&sem->mut);
  sem->s++;
  pthread_cond_signal(&sem->espera);
  pthread_mutex_unlock(&sem->mut);
}

/* Decremento del semáforo. Notar que es una función que puede llegar a bloquear
   el proceso.*/
int sem_decr(sem_t *sem) {
  pthread_mutex_lock(&sem->mut);
  if (sem->s > 0) {
    sem->s--;
  } else {
    pthread_cond_wait(&sem->espera, &sem->mut);
    sem->s--;
  }
  pthread_mutex_unlock(&sem->mut);
}

/* Destrucción de un semáforo */
int sem_destroy(sem_t *sem) {
  free(sem);
  return 0;
}
