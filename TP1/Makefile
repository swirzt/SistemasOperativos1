CC=gcc
FLAGS=-std=c99 -O -g

all: simulador

Board.o: Board.c Board.h
	$(CC) -c Board.c $(FLAGS)

barrera.o: barrera.c barrera.h
	$(CC) -c barrera.c $(FLAGS)

Game.o: Game.c Game.h
	$(CC) -c Game.c $(FLAGS)

simulador: GOL.c barrera.o Board.o Game.o
	$(CC) -o simulador GOL.c barrera.o Board.o Game.o -lpthread $(FLAGS)

clean:
	rm -rf barrera.o
	rm -rf Board.o
	rm -rf Game.o
	rm -rf simulador