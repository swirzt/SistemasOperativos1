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
    if (comando[largo - 1] != '&') {
      if (!fork()) {
        printf("Ejecutando %s", comando);
        sleep(5);
        printf("Fin\n");
        break;
      } else {
        wait(NULL);
      }
    } else {
      if (!fork()) {
        printf("Ejecutando %s", comando);
        sleep(5);
        printf("Fin\n");
        break;
      }
    }
  }
  return 0;
}