/* RemoteMultiThreadServer.c */
/* Cabeceras de Sockets */
#include <sys/socket.h>
#include <sys/types.h>
/* Cabecera de direcciones por red */
#include <netinet/in.h>
/**********/
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
/**********/
/* Threads! */
#include <pthread.h>

/* Asumimos que el primer argumento es el puerto por el cual escuchará nuestro
servidor */

/* Maxima cantidad de cliente que soportará nuestro servidor */

void *enviar(void *arg);
void *recibir(void *arg);
int esperar = 1;
int sock, *soclient;
struct sockaddr_in servidor, clientedir;
socklen_t clientelen;
pthread_t thread[2];

void error(char *msg) { exit((perror(msg), 1)); }

void sigMain(int sig) {
  shutdown(*soclient, 2);
  close(sock);
}

void sigHijos(int sig) {
  esperar = 0;
  exit(0);
}

int main(int argc, char **argv) {
  pthread_attr_t attr;
  /* Creamos los atributos para los hilos.*/
  pthread_attr_init(&attr);
  /* Hilos que no van a ser *joinables* */
  pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);

  if (argc <= 1) error("Faltan argumentos");
  // Iniciamos el mutex

  /* Creamos el socket */
  if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) error("Socket Init");

  /* Creamos a la dirección del servidor.*/
  servidor.sin_family = AF_INET;         /* Internet */
  servidor.sin_addr.s_addr = INADDR_ANY; /**/
  servidor.sin_port = htons(atoi(argv[1]));

  /* Inicializamos el socket */
  if (bind(sock, (struct sockaddr *)&servidor, sizeof(servidor)))
    error("Error en el bind");

  printf("Binding successful, and listening on %s\n", argv[1]);

  /* Ya podemos aceptar conexiones */
  if (listen(sock, 1) == -1) error(" Listen error ");

  /* Comenzamos con el bucle infinito*/
  /* Pedimos memoria para el socket */
  soclient = malloc(sizeof(int));
  /* Now we can accept connections as they come*/
  clientelen = sizeof(clientedir);
  if ((*soclient = accept(sock, (struct sockaddr *)&clientedir, &clientelen)) ==
      -1)
    error("No se puedo aceptar la conexión. ");

  /* Le enviamos el socket al hijo*/
  pthread_create(&thread[0], NULL, enviar, (void *)soclient);
  pthread_create(&thread[1], NULL, recibir, (void *)soclient);
  signal(SIGINT, sigMain);
  while (esperar)
    ;
  /* Código muerto */
  free(soclient);

  return 0;
}

void *enviar(void *_arg) {
  signal(SIGINT, sigHijos);
  int socket = *(int *)_arg;
  char buf[1024];
  while (1) {
    gets(buf);
    if (send(socket, buf, sizeof(buf), 0) == -1) {
      break;
    }
  }
  return NULL;
}

void *recibir(void *_arg) {
  signal(SIGINT, sigHijos);
  int socket = *(int *)_arg;
  char buf[1024];
  while (1) {
    if (recv(socket, buf, sizeof(buf), 0) == 0) break;
    printf("Cliente[%ld]: %s\n", pthread_self(), buf);
  }
  return NULL;
}
