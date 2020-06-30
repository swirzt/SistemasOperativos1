-module(cliente).

-export([main/2, loopRecv/1, sacarJuego/1, imprimeTablero/1]).

-define(StringScreen,"Ingrese un número para seleccionar un comando, sus opciones son:~n
1)Lista de juegos~n
2)Nuevo juego~n
3)Aceptar un juego~n
4)Jugar una jugada~n
5)Observar un juego~n
6)Dejar de observar un juego~n
7)Cerrar la conexión~n").

%%Elimina \n de una cadena
quitabarran([$\n | Xs]) ->
    Xs;
quitabarran([C | Xs]) ->
    [C | quitabarran(Xs)].

%% Se usan para mostrar la lista de juegos
parsearJuegos([]) ->
    io:format("No hay juegos disponibles~n");
parsearJuegos(Xs) ->
    SinComas = string:lexemes(Xs, ","),
    sacarJuego(SinComas).

sacarJuego([]) ->
    ok;
sacarJuego([X | Xs]) ->
    [A, B, C] = string:lexemes(X, "/"),
    io:format("Juego: ~p, Local: ~p, Visitante: ~p~n", [A, B, C]),
    sacarJuego(Xs).

%% Inicia la conexión con el servidor
main(IP, Puerto) ->
    case gen_tcp:connect(IP, Puerto, [{packet, 0}, {active, false}]) of
      {ok, Socket} ->
          io:format("Conexión exitosa!~n"),
          io:format("Bienvenido! Por favor ingrese su nombre: ~n"),
          Nombre = quitabarran(io:get_line("Nombre:")),
          registrarse(Nombre, Socket),
          io:format("Registrado exitosamente~n"),
          spawn_link(?MODULE, loopRecv, [Socket]),
          process_flag(trap_exit, true),
          clienteBonito(Socket, 1);
      {error, Reason} ->
          io:format("No se pudo conectar por ~p ~n", [Reason])
    end.

%% Función que encapsula el loop de registrarse
registrarse(Nombre, Socket) ->
    case gen_tcp:send(Socket, lists:concat(["CON ", Nombre])) of
      ok ->
          case gen_tcp:recv(Socket, 0) of
            {ok, Data} ->
                [X, Xs | _] = string:lexemes(Data, " "),
                case X of
                  "OK" ->
                      ok;
                  "ERROR" ->
                      case Xs of
                        "invalidchar" ->
                            io:format("Nombre inválido, intente otro nombre~n"),
                            Name = quitabarran(io:get_line("Nombre:")),
                            registrarse(Name, Socket);
                        "usedname" ->
                            io:format("Nombre ya usado, intente otro nombre~n"),
                            Name = quitabarran(io:get_line("Nombre:")),
                            registrarse(Name, Socket);
                        "badarg" ->
                            io:format("Nombre inválido, intente otro nombre~n"),
                            Name = quitabarran(io:get_line("Nombre:")),
                            registrarse(Name, Socket)
                      end
                end;
            {error, Reason} ->
                io:format("El registro falló por ~p, intentando otra vez... ~n", [Reason]),
                registrarse(Nombre, Socket)
          end;
      {error, Reason} ->
          io:format("El registro falló por ~p, intentando otra vez... ~n", [Reason]),
          registrarse(Nombre, Socket)
    end.

%% Función que se encarga de enviar mensajes al servidor
clienteBonito(Socket, N) ->
    io:format(?StringScreen),
    case quitabarran(io:get_line("Opción:")) of
      "1" ->
          gen_tcp:send(Socket, lists:concat(["LSG ", N])),
          io:format("El número de pedido es ~p~n", [N]);
      "2" ->
          gen_tcp:send(Socket, lists:concat(["NEW ", N])),
          io:format("El número de pedido es ~p~n", [N]);
      "3" ->
          Juego = quitabarran(io:get_line("Juego:")),
          gen_tcp:send(Socket, lists:concat(["ACC ", N, " ", Juego])),
          io:format("El número de pedido es ~p~n", [N]);
      "4" ->
          Juego = quitabarran(io:get_line("Juego:")),
          Jugada = quitabarran(io:get_line("Jugada:")),
          gen_tcp:send(Socket, lists:concat(["PLA ", N, " ", Juego, " ", Jugada])),
          io:format("El número de pedido es ~p~n", [N]);
      "5" ->
          Juego = quitabarran(io:get_line("Juego:")),
          gen_tcp:send(Socket, lists:concat(["OBS ", N, " ", Juego])),
          io:format("El número de pedido es ~p~n", [N]);
      "6" ->
          Juego = quitabarran(io:get_line("Juego:")),
          gen_tcp:send(Socket, lists:concat(["LEA ", N, " ", Juego])),
          io:format("El número de pedido es ~p~n", [N]);
      "7" ->
          gen_tcp:send(Socket, "BYE"),
          gen_tcp:close(Socket);
      _ ->
          io:format("Comando no existente, intente otra vez ~n")
    end,
    receive
      {'EXIT', _, _} ->
          io:format("Servidor desconectado ~n")
      after 0 ->
                clienteBonito(Socket, N + 1)
    end.

%% Función que se encarga de recibir y parsear los mensajes del servidor
loopRecv(Socket) ->
    case gen_tcp:recv(Socket, 0) of
      {ok, Data} ->
          [X, Xs, Xss | Xsss] = string:lexemes(Data, " "),
          case X of
            "OK" ->
                case Xss of
                  "list" ->
                      parsearJuegos(Xsss);
                  "game" ->
                      io:format("Su id de juego es: ~p~n", Xsss);
                  "tablero" ->
                      case lists:nth(2, Xsss) of
                        "tablero" ->
                            io:format("Juego:~p~nTablero:~n", [lists:nth(1, Xsss)]);
                        "w1" ->
                            io:format("Juego:~p~nGanó el jugardor local~n", [lists:nth(1, Xsss)]);
                        "w2" ->
                            io:format("Juego:~p~nGanó el jugardor visitante~n",
                                      [lists:nth(1, Xsss)]);
                        "empate" ->
                            io:format("Juego:~p~nEmpate!~n", [lists:nth(1, Xsss)])
                      end,
                      imprimeTablero(string:lexemes(lists:nth(4, Xsss), ","));
                  "obs" ->
                      io:format("Observando el juego ~p~n", [Xsss]);
                  "lea" ->
                      io:format("Ya no se observa el juego ~p~n", [Xsss]);
                  "acc" ->
                      io:format("Jugando en ~p como Visitante~n", Xsss)
                end;
            "ERROR" ->
                case Xss of
                  "occupied" ->
                      io:format("Juego ocupado en el pedido ~p~n", [Xs]);
                  "badarg" ->
                      io:format("Argumentos inválidos en el pedido ~p~n", [Xs]);
                  "noExist" ->
                      io:format("Juego inexistente en el pedido ~p~n", [Xs]);
                  "alreadyReg" ->
                      io:format("Usuario ya registrado en el pedido ~p~n", [Xs]);
                  "badNode" ->
                      io:format("Servidor no existente en el pedido ~p~n", [Xs]);
                  "badFormat" ->
                      io:format("Formato equivocado en el pedido ~p~n", [Xs]);
                  "invalid" ->
                      io:format("Jugada inválida en el pedido ~p~n", [Xs]);
                  "badTurn" ->
                      io:format("Turno equivocado en el pedido ~p~n", [Xs]);
                  "noStarted" ->
                      io:format("El juego no comenzó en el pedido ~p~n", [Xs]);
                  "noOpponent" ->
                      io:format("Juego sin oponente en el pedido ~p~n", [Xs]);
                  "unknown" ->
                      io:format("Error desconocidoen el pedido ~p~n", [Xs]);
                  "wrongcmd" ->
                      io:format("Comando erróneo ~p~n", [Xs])
                end;
            "UPD" ->
                case Xss of
                  "tablero" ->
                      case lists:nth(2, Xsss) of
                        "tablero" ->
                            io:format("Juego:~p~nTablero:~n", [lists:nth(1, Xsss)]);
                        "w1" ->
                            io:format("Juego:~p~nGanó el jugardor local~n", [lists:nth(1, Xsss)]);
                        "w2" ->
                            io:format("Juego:~p~nGanó el jugardor visitante~n",
                                      [lists:nth(1, Xsss)]);
                        "empate" ->
                            io:format("Juego:~p~nEmpate!~n", [lists:nth(1, Xsss)])
                      end,
                      imprimeTablero(string:lexemes(lists:nth(3, Xsss), ","));
                  "abandon" ->
                      io:format("El juego ~p se canceló~n", Xsss),
                      gen_tcp:send(Socket, lists:concat(["OK ", Xs]));
                  "accept" ->
                      io:format("Nuevo oponente en el juego ~p~n", Xsss);
                  _ ->
                      gen_tcp:send(Socket, lists:concat(["ERROR ", Xs]))
                end
          end,
          loopRecv(Socket);
      {error, Reason} ->
          io:format("No fue posible conectarse al servidor por ~p~n", [Reason]),
          exit(euMorri)
    end.

%% Imprime en pantalla una lista formateada como tablero
imprimeTablero([A1, A2, A3, B1, B2, B3, C1, C2, C3]) ->
    io:format("~p | ~p | ~p ~n", [A1, A2, A3]),
    io:format("---------------~n"),
    io:format("~p | ~p | ~p ~n", [B1, B2, B3]),
    io:format("---------------~n"),
    io:format("~p | ~p | ~p ~n", [C1, C2, C3]).

