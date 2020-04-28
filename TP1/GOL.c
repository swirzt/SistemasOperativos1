#include "Game.h"
#define MAX(x, y) x > y ? x : y

game_t* jueguito;

int main(int argc, char* argv[]) {
  int cantHilos;
  printf("¿Cuántos hilos desea utilizar? \n");
  printf(
      "Nota: Seleccionar 0 hilos creará tantos hilos como unidades de "
      "procesamiento disponibles \n");
  scanf("%d", &cantHilos);
  jueguito = loadGame(argv[1]);
  size_t cic = jueguito->cycles;
  if (cantHilos > MAX(jueguito->board->n, jueguito->board->m))
    cantHilos = MAX(jueguito->board->n, jueguito->board->m);
  board_t tablero = congwayGoL(jueguito, cic, cantHilos);
  writeBoard(tablero, "salida.txt");
  return 0;
}