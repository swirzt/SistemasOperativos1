#include <signal.h>
#include <stdio.h>  /* printf() */
#include <stdlib.h> /* exit()*/
#include <unistd.h> /* sleep()*/

void manejadorSenal(int sig) { fputc('\n', stdin); }

int main(void) {
  signal(SIGINT, manejadorSenal);
  char buf[1024];
  scanf("%[^\n]", buf);
  printf("Sali\n");
  return 0;
}
