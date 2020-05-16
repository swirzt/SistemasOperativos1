-module(buzon).
-export([what/1,buzon/0,pruebaBuzon/0]).
-import(tiempo,[wait/1]).

what(msj1) ->
    io:format("Llegó el mensaje1 !! ~n");
what(msj2) ->
    io:format("Llegó el mensaje2 !! ~n");
what(_) ->
    io:format("Llegó cualquier cosa Martín!~n").

buzon() ->
    receive
        Msj -> what(Msj), buzon()
    after
        1000 -> io:format("Hello darkness my old friend~n")
    end.

pruebaBuzon()->
    PBuzon = spawn(?MODULE, buzon, []),
    wait(100),
    PBuzon ! msj1,
    PBuzon ! cualca,
    PBuzon ! msj2,
    io:format("Fin de Prueba de Buzon~n").
