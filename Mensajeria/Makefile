CC=gcc
FLAGS= -O3 -lpthread -Wno-unused-result -g

all: Servidor Cliente

Servidor: mensageriaServidor.c
	$(CC) -o Servidor mensageriaServidor.c $(FLAGS)

Cliente: mensageriaCliente.c
	$(CC) -o Cliente mensageriaCliente.c $(FLAGS)

clean:
	rm -rf Cliente
	rm -rf Servidor