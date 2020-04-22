#include "Game.h"
// #include <pthread.h>

void agente(board_t tablero) {
  size_t m = tablero->m, n = tablero->n;
  for (size_t i = 0; i < m; i++)
    for (size_t j = 0; j < m; j++) {
    }
}

int main(int argc, char* argv[]) {
  game_t* jueguito = loadGame(argv[1]);
  size_t m = jueguito->board->m;
  return 0;
}