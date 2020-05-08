#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h> /* Unix Connection*/
#include <unistd.h>

#include "Conf.h"

int main(void) {
  int sock;
  int recibido;
  char buf[1024];
  struct sockaddr_un serverdir;
  if ((sock = socket(AF_UNIX, SOCK_STREAM, 0)) < 0) {
    perror("Socket init");
    exit(1);
  }
  serverdir.sun_family = AF_UNIX;
  strcpy(serverdir.sun_path, Direccion);
  if ((connect(sock, (struct sockaddr *)&serverdir,
               sizeof(struct sockaddr_un))) == -1) {
    perror("Connection failed");
    exit(1);
  }
  gets(buf);
  send(sock, buf, sizeof(buf), 0);
  recv(sock, &recibido, sizeof(recibido), 0);
  printf("Recv:%d\n", recibido);
  close(sock);

  return 0;
}
