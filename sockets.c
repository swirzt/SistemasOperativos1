#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

/* Los mensajes que vamos a intercambiar */
#define MSG1 "Hola pa, cómo estás?"
#define MSG2 "Bien, vos?"

int main(void) {
  int sockets[2], child;
  char buf[1024];

  /* Inicialización del Socket, como es local usamos `AF_LOCAL`,
  y usaremos un canal bidireccional de transmisión `SOCK_STREAM`*/
  if ((socketpair(AF_LOCAL, SOCK_STREAM, 0, sockets)) < 0) {
    perror("Error Initializing Sockets");
    exit(1);
  }
  /* Realizamos la creación de un nuevo proceso hijo*/
  if ((child = fork()) < 0)
    perror("Error Forking"), exit(1);
  else {
    if (child) {         /* Proceso padre*/
      close(sockets[0]); /* Cerramos el socket del hijo.*/
      /* Leemos lo que venga por el socket */
      if ((read(sockets[1], buf, sizeof(buf))) < 0)
        perror("Parent error while reading"), exit(1);
      printf("Padre -->:%s\n", buf);
      /*Escribimos nuestro mensaje */
      if ((write(sockets[1], MSG2, sizeof(MSG2))) < 0)
        perror("Parent error while writing"), exit(1);
      close(sockets[1]);
    } else {             /* Hijo */
      close(sockets[1]); /* Cerramos el socket del padre */
      /* Escribimos nuestro mensaje*/
      if ((write(sockets[0], MSG1, sizeof(MSG1))) < 0)
        perror("Child error while writing"), exit(1);
      /* Esperamos la respuesta del proceso padre */
      if ((read(sockets[0], buf, sizeof(buf))) < 0)
        perror("Child error while Reading"), exit(1);
      printf("Hijo -->:%s\n", buf);
      close(sockets[0]);
    }
  }
  return 0;
}
