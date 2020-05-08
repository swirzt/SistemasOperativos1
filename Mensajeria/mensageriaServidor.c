/* RemoteMultiThreadServer.c */
/* Cabeceras de Sockets */
#include <sys/types.h>
#include <sys/socket.h>
/* Cabecera de direcciones por red */
#include <netinet/in.h>
/**********/
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <signal.h>
/**********/
/* Threads! */
#include <pthread.h>

/* Asumimos que el primer argumento es el puerto por el cual escuchará nuestro
servidor */

/* Maxima cantidad de cliente que soportará nuestro servidor */
#define MAX_CLIENTS 25

/* Anunciamos el prototipo del hijo */
void *enviar(void *arg);
void *recibir(void *arg);
/* Definimos una pequeña función auxiliar de error */
void error(char *msg);


//Armamor el manejo de señales con mutex
pthread_mutex_t mut;
void manejadorSenal(int sig){
	pthread_mutex_lock(&mut);  
	printf("Seguro que desea salir? Presione y para cortar la comuniacion, n si no desea terminar\n");
	char x;
	x = getc(stdin);
	if(x == 'y') exit(0);
	pthread_mutex_unlock(&mut);
	return;
}

int main(int argc, char **argv){
  int sock, *soclient;
  struct sockaddr_in servidor, clientedir;
  socklen_t clientelen;
  pthread_t thread[2];
  pthread_attr_t attr;

  if (argc <= 1) error("Faltan argumentos");
	//Iniciamos el mutex
	pthread_mutex_init(&mut,NULL);

  /* Creamos el socket */
  if( (sock = socket(AF_INET, SOCK_STREAM, 0)) < 0 )
    error("Socket Init");

  /* Creamos a la dirección del servidor.*/
  servidor.sin_family = AF_INET; /* Internet */
  servidor.sin_addr.s_addr = INADDR_ANY; /**/
  servidor.sin_port = htons(atoi(argv[1]));

  /* Inicializamos el socket */
  if (bind(sock, (struct sockaddr *) &servidor, sizeof(servidor)))
    error("Error en el bind");

  printf("Binding successful, and listening on %s\n",argv[1]);

  /************************************************************/
  /* Creamos los atributos para los hilos.*/
  pthread_attr_init(&attr);
  /* Hilos que no van a ser *joinables* */
  pthread_attr_setdetachstate(&attr,PTHREAD_CREATE_DETACHED);
  /************************************************************/

  /* Ya podemos aceptar conexiones */
  if(listen(sock, MAX_CLIENTS) == -1)
    error(" Listen error ");

  for(;;){ /* Comenzamos con el bucle infinito*/
    /* Pedimos memoria para el socket */
    soclient = malloc(sizeof(int));

    /* Now we can accept connections as they come*/
    clientelen = sizeof(clientedir);
    if ((*soclient = accept(sock
                          , (struct sockaddr *) &clientedir
                          , &clientelen)) == -1)
      error("No se puedo aceptar la conexión. ");

    /* Le enviamos el socket al hijo*/
    pthread_create(&thread[0] , NULL , enviar, (void *) soclient);
		pthread_create(&thread[1] , NULL , recibir, (void *) soclient);
  }

  /* Código muerto */
  close(sock);

  return 0;
}

void *enviar(void *_arg){
  int socket = *(int*) _arg;
  char buf[1024];
  for(;;){
 	gets(buf);
	send(socket, buf,sizeof(buf),0);
	printf("Servidor: %s\n",buf);
}
  free((int*)_arg);
  return NULL;
}

void *recibir(void *_arg){
	int socket = *(int*) _arg;
	char buf[1024];
  for(;;){
	recv(socket, buf,sizeof(buf),0);
  printf("Cliente[%ld]: %s\n",pthread_self(),buf);
  signal(SIGINT, manejadorSenal);
}
	free((int*) _arg);
	return NULL;
}

void error(char *msg){
  exit((perror(msg), 1));
}

