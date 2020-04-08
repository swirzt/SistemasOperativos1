#include <assert.h>
#include <pthread.h>
#include <semaphore.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define N_FILOSOFOS 5
#define ESPERA 5000000

pthread_mutex_t tenedor[N_FILOSOFOS];
sem_t *sem;
pthread_t filo[N_FILOSOFOS];

void pensar(int i) {
  printf("Filosofo %d pensando...\n", i);
  usleep(random() % ESPERA);
}

void comer(int i) {
  printf("Filosofo %d comiendo...\n", i);
  usleep(random() % ESPERA);
}

void tomar_tenedores(int i) {
  pthread_mutex_lock(&tenedor[i]); /* Toma el tenedor a su derecha */
  pthread_mutex_lock(
      &tenedor[(i + 1) % N_FILOSOFOS]); /* Toma el tenedor a su izquierda */
}

void dejar_tenedores(int i) {
  pthread_mutex_unlock(&tenedor[i]); /* Deja el tenedor de su derecha */
  pthread_mutex_unlock(
      &tenedor[(i + 1) % N_FILOSOFOS]); /* Deja el tenedor de su izquierda */
}

void *filosofo(void *arg) {
  int i = (*(int *)arg);
  for (;;) {
    sem_wait(sem);
    printf("%d ya espere\n", i);
    tomar_tenedores(i);
    printf("%d ya tome\n", i);
    comer(i);
    printf("%d ya comi\n", i);
    dejar_tenedores(i);
    printf("%d ya deje\n", i);
    pensar(i);
    printf("%d Ya pense\n", i);
    sem_post(sem);
    printf("%d ya avise\n", i);
  }
}

int main() {
  sem = malloc(sizeof(sem_t));
  sem_init(sem, 0, N_FILOSOFOS - 2);
  int i;
  for (i = 0; i < N_FILOSOFOS; i++) pthread_mutex_init(&tenedor[i], NULL);
  for (i = 0; i < N_FILOSOFOS; i++)
    pthread_create(&filo[i], NULL, filosofo, (void *)&i);
  pthread_join(filo[0], NULL);
  return 0;
}