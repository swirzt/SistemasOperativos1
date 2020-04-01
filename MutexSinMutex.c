#include <assert.h>
#include <pthread.h>
#include <semaphore.h>
#include <stdio.h>
#include <stdlib.h>

#define NVisitantes 100000
int *counter;
sem_t *sem;
pthread_t ts[2];

void *turnstile(void *argV) {
  for (int j = 0; j < NVisitantes; j++) {
    sem_wait(sem);
    (*(int *)argV)++;
    sem_post(sem);
  }
  return NULL;
}

int main() {
  counter = malloc(sizeof(int));
  *counter = 0;
  sem = malloc(sizeof(sem_t));
  sem_init(sem, 0, 1);
  assert(!pthread_create(&ts[0], NULL, turnstile, (void *)(counter)));
  assert(!pthread_create(&ts[1], NULL, turnstile, (void *)(counter)));
  assert(!pthread_join(ts[0], NULL));
  assert(!pthread_join(ts[1], NULL));
  sem_destroy(sem);
  printf("%d\n", *counter);
  return 0;
}