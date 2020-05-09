#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void manejadorSenal(int sig) {
  printf("MURIO PAPAPAPAPAPA\n");
  exit(0);
  return;
}

void manejadorSenal2(int sig) {
  printf("MURIO JONYYYYYYYYY\n");
  exit(0);
  return;
}

int main() {
  if (!fork()) {
    while (1) {
      printf("Hola pa\n");
      signal(SIGINT, manejadorSenal);
    }
  } else {
    while (1) {
      signal(SIGINT, manejadorSenal2);
      printf("Holanda\n");
    }
  }
  return 0;
}