#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <pthread.h>
#include <assert.h>

#define NThreads 10
#define NPoints 10000000
#define R NPoints / 1000

#define sqrR R* R
#define R2 2 * R

// Sol seccuencial
double piCalculationSec(void) {
  int a, b;
  double c;
  double totalCirc = 0;
  for (int i = 0; i < NPoints; i++) {
    a = rand() % (R2 + 1);
    b = rand() % (R2 + 1);
    c = pow(a - R, 2) + pow(b - R, 2);
    // printf("a vale %d b vale %d c vale %f\n", a, b, c);
    if (c <= (double)sqrR) totalCirc++;
  }
  return 4 * totalCirc / NPoints;
}

// Sol Thread
pthread_mutex_t mut = PTHREAD_MUTEX_INITIALIZER;
void* Thread(void* arg) {
  int a, b;
  double c;
  for (int i = 0; i < NPoints / NThreads; i++) {
    a = rand() % (R2 + 1);
    b = rand() % (R2 + 1);
    c = pow(a - R, 2) + pow(b - R, 2);
    pthread_mutex_lock(&mut);
    if (c <= (double)sqrR) (*(double*)arg)++;
    pthread_mutex_unlock(&mut);
  }
  return NULL;
}

double piCalculationThr(void) {
  double* dentroCirc = malloc(sizeof(double));
  *dentroCirc = 0;
  pthread_t ts[NThreads];

  for (int i = 0; i < NThreads; i++) {
    assert(!pthread_create(&ts[i], NULL, Thread, (void*)(dentroCirc)));
  }

  for (int i = 0; i < NThreads; i++) {
    assert(!pthread_join(ts[i], NULL));
  }

  return *dentroCirc * 4 / NPoints;
}

int main(void) {
  double pi, pi2;
  // Seed setting
  srandom(4);

  pi = piCalculationThr();
  pi2 = piCalculationSec();
  printf("Approximación de pi PThreads con %d puntos es: %'.10f\n", NPoints,
         pi);
  printf("Approximación de pi Secuencial con %d puntos es: %'.10f\n", NPoints,
         pi2);

  return 0;
}
