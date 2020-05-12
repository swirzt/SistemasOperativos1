#include <netinet/in.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

/*
Se compila con make

Servidor se ejecuta de la siguiente manera:
./Servidor <Puerto>
donde <Puerto> es el puerto libre donse se quiere crear el servidor

Si se presiona Ctrl+C el programa termina y avisa al cliente que termine
*/

// Es necesario que sean globales para que sigMain pueda liberarlos
int sock, *soclient;
pthread_t thread[2];  // Es necesario que sea global para que recibir pueda
                      // enviar la señal

void error(char *msg) { exit((perror(msg), 1)); }

void sigMain(int sig) {
  shutdown(*soclient, 2);
  close(*soclient);
  close(sock);
}

void sigKill(int sig) { pthread_exit(NULL); }

void *enviar(void *_arg) {
  signal(1, sigKill);
  int socket = *(int *)_arg;
  char buf[1024];
  while (1) {
    fgets(buf, sizeof(buf), stdin);
    if (send(socket, buf, sizeof(buf), 0) < 0) break;
  }
  return NULL;
}

void *recibir(void *_arg) {
  int socket = *(int *)_arg;
  char buf[1024];
  while (recv(socket, buf, sizeof(buf), 0) > 0) printf("Cliente: %s", buf);
  pthread_kill(thread[0], 1);
  return NULL;
}

int main(int argc, char **argv) {
  if (argc <= 1) error("Faltan argumentos");
  if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) error("Socket Init");
  signal(SIGINT, sigMain);
  struct sockaddr_in servidor, clientedir;
  servidor.sin_family = AF_INET;         /* Internet */
  servidor.sin_addr.s_addr = INADDR_ANY; /**/
  servidor.sin_port = htons(atoi(argv[1]));

  if (bind(sock, (struct sockaddr *)&servidor, sizeof(servidor)))
    error("Error en el bind");
  printf("Binding successful, and listening on %s\n", argv[1]);

  if (listen(sock, 1) == -1)
    error(" Listen error ");  // Solo trabajamos con un cliente

  soclient = malloc(sizeof(int));
  socklen_t clientelen = sizeof(clientedir);
  if ((*soclient = accept(sock, (struct sockaddr *)&clientedir, &clientelen)) ==
      -1)
    error("No se puedo aceptar la conexión. ");

  pthread_create(&thread[0], NULL, enviar, (void *)soclient);
  pthread_create(&thread[1], NULL, recibir, (void *)soclient);
  pthread_join(thread[0], NULL);
  pthread_join(thread[1], NULL);

  // Fin
  close(*soclient);
  free(soclient);
  close(sock);
  return 0;
}
