#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define MSG1 "Billy, yo soy tu padre\n"
#define MSG2 "No! No! No es cierto!\n"

/*
  Nota: Cerrar los descripores de archivos que no se usan no es obligatorio,
  pero si es una buena práctica.
 */
int main(void) {
  int pipa[2], papa[2], child;
  // pipa = hijo -> padre
  // papa = padre -> hijo

  /* Creamos el pipe */
  if (pipe(pipa) < 0) {
    perror("Error en la creación del Pipe");
    exit(1);
  }
  if (pipe(papa) < 0) {
    perror("Error en la creación del Pipe");
    exit(1);
  }
  /* Se lee por sockets[0] / Se escribe por sockets[1] */

  /* Procedemos a la creación de un hijo. */
  if ((child = fork()) == -1) {
    perror("Error en la creación del proceso.");
    exit(1);
  } else {
    if (child) { /* Proceso Padre (child != 0) */
      // char buf[1024];
      // /* El padre va a leer, y por ende cierra la escritura*/
      // close(sockets[1]);
      // /* Leemos con read, es bloqueante */
      // if (read(sockets[0], buf, sizeof(buf)) < 0)  perror("Error Leyendo");
      // printf("Se leyó:%s\n", buf);
      // close(sockets[0]);
      // Usamos pipa para leer del hijo
      close(pipa[1]);
      // Usamos papa para escribirle al hijo
      close(papa[0]);
      char buffer[1024];
      while (1) {
        // El padre le escribe al hijo
        if (write(papa[1], MSG1, sizeof(MSG1)) < 0) perror("Writing error");
        if (read(pipa[0], buffer, sizeof(buffer)) < 0) perror("Error Leyendo");
        printf("%s", buffer);
        sleep(1);
      }

    } else { /* Proceso hijo, (child == 0)*/
      // char buf[] = "Mensaje para papa";
      // /* Dado que escribimos, cerramos la lectura del pipe*/
      // close(sockets[0]);
      // /* Escribimos con write */
      // if (write(sockets[1], buf, sizeof(buf)) < 0) perror("Writing error");
      // close(sockets[1]);
      // Usamos pipa para escribirle al padre
      close(pipa[0]);
      // Usamos papa para leer del padre
      close(papa[1]);
      char buffer[1024];
      while (1) {
        // El padre le escribe al hijo
        if (write(pipa[1], MSG2, sizeof(MSG2)) < 0) perror("Writing error");
        printf("%s", buffer);
        if (read(papa[0], buffer, sizeof(buffer)) < 0) perror("Error Leyendo");
        sleep(1);
      }
    }
  }
  return 0;
}
