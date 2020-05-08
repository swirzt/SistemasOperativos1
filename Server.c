/* Server.c */
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h> /* Unix Connection*/
#include <unistd.h>

#include "Conf.h"

#define LISTEN_MAX 5

pthread_t hilos[LISTEN_MAX];

void *server(void *arg) {
  int sock = *((int *)arg);
  int soclient;
  char buf[1024];
  socklen_t clilen;
  struct sockaddr_un clidir;
  while (1) {
    if (listen(sock, LISTEN_MAX) == -1) {
      perror(" Listen error ");
      exit(1);
    }
    clilen = sizeof(struct sockaddr_un);
    if ((soclient = accept(sock, (struct sockaddr *)&clidir, &clilen)) == -1) {
      perror("Accepting error");
      exit(1);
    }
    recv(soclient, buf, sizeof(buf), 0);
    int k;
    int max = atoi(buf);
    for (k = 0; k < max; k++)
      ;
    send(soclient, &k, sizeof(k), 0);
    printf("Recv: %s\n", buf);
  }
  return NULL;
}

int main(void) {
  remove(Direccion);
  int cond;
  int sock;
  struct sockaddr_un midir;
  if ((sock = socket(AF_UNIX, SOCK_STREAM, 0)) < 0) {
    perror("Socket init");
    exit(1);
  }
  midir.sun_family = AF_UNIX;
  strcpy(midir.sun_path, Direccion);
  if (bind(sock, (struct sockaddr *)&midir, sizeof(struct sockaddr_un)) == -1) {
    perror("Trying to bind");
    exit(1);
  }
  for (int i = 0; i < LISTEN_MAX; i++)
    pthread_create(&hilos[i], NULL, server, (void *)&sock);
  pthread_join(hilos[0], NULL);

  return 0;
}
