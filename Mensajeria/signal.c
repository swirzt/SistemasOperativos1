#include <unistd.h> /* sleep()*/
#include <stdio.h> /* printf() */
#include <stdlib.h> /* exit()*/
#include <signal.h>

void manejadorSenal(int sig){
  printf("Seguro que desea salir? Presione y para cortar la comuniacion, n si no desea terminar\n");
	char x;
	x = getc(stdin);
	if(x == 'y') exit(0);
	return;
}

int main(void){
  signal(SIGINT, manejadorSenal);

  for(;;){
    printf("Esperando para salir de casa\n");
    sleep(1);
  }
  return 0;
}

