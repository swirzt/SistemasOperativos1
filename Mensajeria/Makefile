CC=gcc
FLAGS= -O3 -lpthread -Wno-unused-result

all: Servidor Cliente

Servidor: Servidor.c
	$(CC) -o Servidor Servidor.c $(FLAGS)

Cliente: Cliente.c
	$(CC) -o Cliente Cliente.c $(FLAGS)

clean:
	rm -rf Cliente
	rm -rf Servidor