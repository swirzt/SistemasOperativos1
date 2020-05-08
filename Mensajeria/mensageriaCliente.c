/* RemoteClient.c
   Se introducen las primitivas necesarias para establecer una conexión simple
   dentro del lenguaje C utilizando sockets.
*/
/* Cabeceras de Sockets */
#include <sys/types.h>
#include <sys/socket.h>
/* Cabecera de direcciones por red */
#include <netdb.h>
/**********/
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <pthread.h>
#include <signal.h>
/*
  El archivo describe un sencillo cliente que se conecta al servidor establecido
  en el archivo RemoteServer.c. Se utiliza de la siguiente manera:
  $cliente IP port
 */

void error(char *msg){
  exit((perror(msg), 1));
}

void *enviar(void *_arg){
printf("Entre a enviar\n");
  int socket = *(int*) _arg;
	printf("Conectado!\n");
	char buf[1024];  
	for(;;){
 	gets(buf);
	send(socket, buf,sizeof(buf),0);
	printf("Cliente: %s\n",buf);
}
  free((int*)_arg);
  return NULL;
}

void *recibir(void *_arg){
printf("Entre a recibir\n");
  int socket = *(int*) _arg;
	char buf[1024];
  for(;;){
	recv(socket, buf,sizeof(buf),0);
  printf("Servidor: %s\n",buf);
}
  free((int*)_arg);
	return NULL;
}

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
  int sock;
  char buf[1024];
  struct addrinfo *resultado;
	pthread_t thread[2];
  /*Chequeamos mínimamente que los argumentos fueron pasados*/
  if(argc != 3){
    fprintf(stderr,"El uso es \'%s IP port\'", argv[0]);
    exit(1);
  }
	
	//Iniciamos el mutex
	pthread_mutex_init(&mut,NULL);	

  /* Inicializamos el socket */
  if( (sock = socket(AF_INET , SOCK_STREAM, 0)) < 0 )
    error("No se pudo iniciar el socket");

  /* Buscamos la dirección del hostname:port */
  if (getaddrinfo(argv[1], argv[2], NULL, &resultado)){
    fprintf(stderr,"No se encontro el host: %s \n",argv[1]);
    exit(2);
  }
	if(connect(sock, (struct sockaddr *) resultado->ai_addr, resultado->ai_addrlen) != 0)
    /* if(connect(sock, (struct sockaddr *) &servidor, sizeof(servidor)) != 0) */
    error("No se pudo conectar :(. ");
	//Inicializamos los hilos
 	pthread_create(&thread[0] , NULL , enviar, (void *) &sock);
	pthread_create(&thread[1] , NULL , recibir, (void *) &sock);
  signal(SIGINT, manejadorSenal);
	pthread_join(thread[0],NULL);
  
  printf("La conexión fue un éxito!\n");

  /* Cerramos :D!*/
  freeaddrinfo(resultado);
  close(sock);

  return 0;
}


