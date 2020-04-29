#include "Game.h"

char* transformaFinal(char* entrada) {
  int largo = strlen(entrada);
  char* final = malloc(sizeof(char) * (largo + 2));
  strncpy(final, entrada, largo - 4);
  final[largo - 4] = '\0';
  strcat(final, "final");
  return final;
}

int main(int argc, char* argv[]) {
  int cantHilos = get_nprocs();  // PREGUNTAR
  game_t* jueguito = loadGame(argv[1]);
  board_t tablero = congwayGoL(jueguito, cantHilos);
  char* guardado = transformaFinal(argv[1]);
  writeBoard(tablero, guardado);
  free(guardado);
  return 0;
}