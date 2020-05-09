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
int esperar = 1;
int sock;
void error(char *msg) { exit((perror(msg), 1)); }

void sigMain(int sig) {
  shutdown(sock, 2);
  close(sock);
}

void sigHijos(int sig) {
  esperar = 0;
  exit(0);
}

void *enviar(void *_arg) {
  signal(SIGINT, sigHijos);
  printf("Entre a enviar\n");
  int socket = *(int *)_arg;
  printf("Conectado!\n");
  char buf[1024];
  for (;;) {
    gets(buf);
    if (send(socket, buf, sizeof(buf), 0) == -1) {
      break;
    }
  }
  return NULL;
}

void *recibir(void *_arg) {
  signal(SIGINT, sigHijos);
  printf("Entre a recibir\n");
  int socket = *(int *)_arg;
  char buf[1024];
  for (;;) {
    if (recv(socket, buf, sizeof(buf), 0) == 0) break;
    printf("Servidor: %s\n", buf);
  }
  return NULL;
}

int main(int argc, char **argv) {
  pthread_attr_t attr;
  /* Creamos los atributos para los hilos.*/
  pthread_attr_init(&attr);
  /* Hilos que no van a ser *joinables* */
  pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);

  char buf[1024];
  struct addrinfo *resultado;
  pthread_t thread[2];
  /*Chequeamos mínimamente que los argumentos fueron pasados*/
  if (argc != 3) {
    fprintf(stderr, "El uso es \'%s IP port\'", argv[0]);
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
  signal(SIGINT, sigMain);
  while (esperar)
    ;
  /* Cerramos :D!*/
  freeaddrinfo(resultado);
  free(resultado);
  return 0;
}
