#include <pthread.h>
#include <stdio.h>
// -lpthread

// El deadlock ocurre si la cuanta A quiere enviar a la cuenta B y viceversa
// luego si el hilo de AB hace mutex de A y el hilo BA hace mutex de B se llega
// a un deadlock

// Solucion, hacer que el mutex sea una sola instruccion
#define n 100
int cuentas[n];
pthread_mutex_t banquero = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t locks[n] = PTHREAD_MUTEX_INITIALIZER;

int transferir(int cuenta_fuente, int cuenta_destino, int cantidad) {
  int rta;
  pthread_mutex_lock(&banquero);
  pthread_mutex_lock(&locks[cuenta_fuente]);
  pthread_mutex_lock(&locks[cuenta_destino]);
  pthread_mutex_unlock(&banquero);
  if (cuentas[cuenta_fuente] >= cantidad) {
    rta = 0;
    cuentas[cuenta_fuente] -= cantidad;
    cuentas[cuenta_destino] += cantidad;
  } else
    rta = 1;
  pthread_mutex_unlock(&locks[cuenta_fuente]);
  pthread_mutex_unlock(&locks[cuenta_destino]);
  return rta;
}

int main() {
  // p_thread hilos[k];
  // pthread_create()
  cuentas[0] = 100;
  cuentas[1] = 10;
  transferir(0, 1, 90);
  printf("%d %d\n", cuentas[0], cuentas[1]);
  return 0;
}