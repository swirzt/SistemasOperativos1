/*Se incluyen las librerías necesarias */
#include <pthread.h>
#include <semaphore.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "barrera.h"

pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

/* Estructura para los argumentos */
struct _argument {
  int tabaco, papel, fosforos;
  pthread_cond_t tabacoPapel;
  pthread_cond_t fosforosTabaco;
  pthread_cond_t papelFosforos;
  sem_t otra_vez;
};

typedef struct _argument args_t;

void agente(void *_args) {
  args_t *args = (args_t *)_args;
  for (;;) {
    int caso = random() % 3;
    sem_wait(&args->otra_vez);
    switch (caso) {
      case 0:
        pthread_mutex_lock(&mutex);
        args->tabaco = 1;
        args->papel = 1;
        pthread_cond_signal(&args->tabacoPapel);
        pthread_mutex_unlock(&mutex);
        break;
      case 1:
        pthread_mutex_lock(&mutex);
        args->tabaco = 1;
        args->fosforos = 1;
        pthread_cond_signal(&args->fosforosTabaco);
        pthread_mutex_unlock(&mutex);
        break;
      case 2:
        pthread_mutex_lock(&mutex);
        args->papel = 1;
        args->fosforos = 1;
        pthread_cond_signal(&args->papelFosforos);
        pthread_mutex_unlock(&mutex);
        break;
    }
  }
  /* Dead code */
  return;
}

void fumar(int fumador) {
  printf("Fumador %d: Puf! Puf! Puf!\n", fumador);
  sleep(1);
}

void *fumador1(void *_arg) {
  args_t *args = (args_t *)_arg;
  printf("Fumador 1: Hola!\n");
  for (;;) {
    pthread_mutex_lock(&mutex);
    while (!(args->tabaco && args->papel)) {
      pthread_cond_wait(&args->tabacoPapel, &mutex);
    }
    args->tabaco = 0;
    args->papel = 0;
    fumar(1);
    pthread_mutex_unlock(&mutex);
    sem_post(&args->otra_vez);
  }
  /* Dead code*/
  pthread_exit(0);
}

void *fumador2(void *_arg) {
  args_t *args = (args_t *)_arg;
  printf("Fumador 2: Hola!\n");
  for (;;) {
    pthread_mutex_lock(&mutex);
    while (!(args->tabaco && args->fosforos)) {
      pthread_cond_wait(&args->fosforosTabaco, &mutex);
    }
    args->tabaco = 0;
    args->fosforos = 0;
    fumar(2);
    pthread_mutex_unlock(&mutex);
    sem_post(&args->otra_vez);
  }
  /* Dead code*/
  pthread_exit(0);
}

void *fumador3(void *_arg) {
  args_t *args = (args_t *)_arg;
  printf("Fumador 3: Hola!\n");
  for (;;) {
    pthread_mutex_lock(&mutex);
    while (!(args->fosforos && args->papel)) {
      pthread_cond_wait(&args->papelFosforos, &mutex);
    }
    args->fosforos = 0;
    args->papel = 0;
    fumar(3);
    pthread_mutex_unlock(&mutex);
    sem_post(&args->otra_vez);
  }
  /* Dead code*/
  pthread_exit(0);
}

int main() {
  /* Memoria para los hilos */
  pthread_t s1, s2, s3;
  /* Memoria dinámica para los argumentos */
  args_t *args = malloc(sizeof(args_t));
  /* Se inicializan los semáforos */
  sem_init(&args->otra_vez, 0, 1);
  pthread_cond_init(&args->fosforosTabaco, NULL);
  pthread_cond_init(&args->papelFosforos, NULL);
  pthread_cond_init(&args->tabacoPapel, NULL);
  args->fosforos = 0;
  args->papel = 0;
  args->tabaco = 0;
  /************/

  /* Se inicializan los hilos*/
  pthread_create(&s1, NULL, fumador1, (void *)args);
  pthread_create(&s2, NULL, fumador2, (void *)args);
  pthread_create(&s3, NULL, fumador3, (void *)args);
  /************/

  /* Y el agente que provee con los elemetos*/
  agente((void *)args);
  /************/

  return 0;
}
