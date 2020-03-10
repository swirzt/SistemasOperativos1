#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

#define MAX 300

int main() {
  char comando[MAX];
  while (1) {
    printf(">");
    fgets(comando, MAX, stdin);
    int largo = strlen(comando);
    comando[largo - 1] = '\0';
    largo--;
    if (!fork()) {
      printf("Ejecutando %s\n", comando);
      sleep(5);
      printf("Fin\n");
      break;
    } else {
      if (comando[largo - 1] != '&') wait(NULL);
    }
  }
  return 0;
}