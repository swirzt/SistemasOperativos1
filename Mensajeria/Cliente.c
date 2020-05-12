#include <netdb.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

/*
Se compila con make

Cliente se ejecuta de la siguiente manera:
./Cliente <Dirección> <Puerto>
  - Donde <Dirección> es la dirección de la pc del servidor
  - <Puerto> es el puerto donde esta escuchando el servidor

Si se presiona Ctrl+C el programa termina y avisa al servidor que termine
*/

int sock;  // Es necesario que sea global para que sigMain pueda liberarlo
pthread_t thread[2];  // Es necesario qeu sea global para que recibir pueda
                      // enviar la señal

// Funcion para notificar errores
void error(char *msg) { exit((perror(msg), 1)); }

// Funcioon signal handler para el hilo Main
void sigMain(int sig) {
  shutdown(sock, 2);
  close(sock);
}

// Funcion signal handler para hilos que se deban terminar
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
  while (recv(socket, buf, sizeof(buf), 0) > 0) printf("Servidor: %s", buf);
  pthread_kill(thread[0], 1);  // Le avisa al otro hilo que debe cortarse
  return NULL;
}

int main(int argc, char **argv) {
  signal(SIGINT, sigMain);
  struct addrinfo *resultado;

  /*Chequeamos mínimamente que los argumentos fueron pasados*/
  if (argc != 3) {
    fprintf(stderr, "El uso es \'%s IP port\'\n", argv[0]);
    exit(1);
  }

  /* Inicializamos el socket */
  if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    error("No se pudo iniciar el socket");

  /* Buscamos la dirección del hostname:port */
  if (getaddrinfo(argv[1], argv[2], NULL, &resultado)) {
    fprintf(stderr, "No se encontro el host: %s \n", argv[1]);
    exit(2);
  }
  if (connect(sock, (struct sockaddr *)resultado->ai_addr,
              resultado->ai_addrlen) != 0)
    error("No se pudo conectar :(. ");

  // Inicializamos los hilos
  pthread_create(&thread[0], NULL, enviar, (void *)&sock);
  pthread_create(&thread[1], NULL, recibir, (void *)&sock);
  printf("La conexión fue un éxito!\n");

  // Final
  pthread_join(thread[0], NULL);
  pthread_join(thread[1], NULL);
  freeaddrinfo(resultado);
  close(sock);
  return 0;
}