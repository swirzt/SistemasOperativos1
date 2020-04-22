#include "Game.h"

int main() {
  game_t* jueguito = loadGame("Ejemplo.game");
  writeBoard(jueguito->board, "salida.txt");
  return 0;
}