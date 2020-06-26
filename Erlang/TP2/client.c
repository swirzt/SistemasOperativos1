#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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

void error(char *msg)
{
  exit((perror(msg), 1));
}

int main(int argc, char **argv)
{
  int sock;
  char buf[1024];
  char buf2[1024];
  struct addrinfo *resultado;

  /*Chequeamos mínimamente que los argumentos fueron pasados*/
  if (argc != 3)
  {
    fprintf(stderr, "El uso es \'%s IP port\'", argv[0]);
    exit(1);
  }

  /* Inicializamos el socket */
  if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0)
    error("No se pudo iniciar el socket");

  /* Buscamos la dirección del hostname:port */
  if (getaddrinfo(argv[1], argv[2], NULL, &resultado))
  {
    fprintf(stderr, "No se encontro el host: %s \n", argv[1]);
    exit(2);
  }

  if (connect(sock, (struct sockaddr *)resultado->ai_addr, resultado->ai_addrlen) != 0)
    /* if(connect(sock, (struct sockaddr *) &servidor, sizeof(servidor)) != 0) */
    error("No se pudo conectar :(. ");

  printf("La conexión fue un éxito!\n");

  while (1)
  {
    fgets(buf, 1024, stdin);
    if (!strcmp("SALIR", buf))
      break;
    send(sock, buf, strlen(buf), 0);
    recv(sock, buf2, sizeof(buf2), 0);
    printf("%s\n", buf2);
  }

  /* Cerramos :D!*/
  freeaddrinfo(resultado);
  close(sock);

  return 0;
}