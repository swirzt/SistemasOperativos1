/* RemoteClient.c
   Se introducen las primitivas necesarias para establecer una conexión simple
   dentro del lenguaje C utilizando sockets.
*/
/* Cabeceras de Sockets */
#include <sys/socket.h>
#include <sys/types.h>
/* Cabecera de direcciones por red */
#include <netdb.h>
/**********/
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

//////////////////////////////// 3 signal handler
////////////////// el de main no ahce nada
///////////////// el de enciar le avisa que palma y palma
//////////////// el de recibir palma

/*
  El archivo describe un sencillo cliente que se conecta al servidor establecido
  en el archivo RemoteServer.c. Se utiliza de la siguiente manera:
  $cliente IP port
 */
int sock;
pthread_t thread[2];

void error(char *msg) { exit((perror(msg), 1)); }

void sigMain(int sig) {
  shutdown(sock, 2);
  close(sock);
}

void sigHijos(int sig) { pthread_exit(NULL); }

void *enviar(void *_arg) {
  signal(42, sigHijos);
  int socket = *(int *)_arg;
  char buf[1024];
  while (1) {
    fgets(buf, sizeof(buf), stdin);
    if (send(socket, buf, sizeof(buf), 0) == -1) {
      break;
    }
  }
  return NULL;
}

void *recibir(void *_arg) {
  int socket = *(int *)_arg;
  char buf[1024];
  while (1) {
    if (recv(socket, buf, sizeof(buf), 0) == 0) {
      pthread_kill(thread[0], 42);
      break;
    }
    printf("Servidor: %s", buf);
  }
  return NULL;
}

int main(int argc, char **argv) {
  signal(SIGINT, sigMain);
  char buf[1024];
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
    /* if(connect(sock, (struct sockaddr *) &servidor, sizeof(servidor)) != 0)
     */
    error("No se pudo conectar :(. ");
  // Inicializamos los hilos
  pthread_create(&thread[0], NULL, enviar, (void *)&sock);
  pthread_create(&thread[1], NULL, recibir, (void *)&sock);
  printf("La conexión fue un éxito!\n");
  pthread_join(thread[0], NULL);
  pthread_join(thread[1], NULL);
  /* Cerramos :D!*/
  freeaddrinfo(resultado);
  close(sock);
  return 0;
}