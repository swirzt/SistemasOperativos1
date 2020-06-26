-module(cliente).
-export([main/1,loopSend/1,loopRecv/1]).

main(Puerto) ->
    {ok,Socket} = gen_tcp:connect("localhost", Puerto, [{packet, 0}, {active,false}]),
    spawn(?MODULE,loopRecv,[Socket]),
    loopSend(Socket).

quitabarran([$\n | Xs]) -> Xs;
quitabarran([C | Xs]) -> [C | quitabarran(Xs)].

loopSend(Socket) ->
    % io:format("Quiero leer ~n"),
    Lectura = io:get_line("Enviar:"),
    Sending = quitabarran(Lectura),
    io:format("Quiero mandar ~p~n",[Sending]),
    gen_tcp:send(Socket,Sending),
    loopSend(Socket).

loopRecv(Socket) ->
    {ok, Data} = gen_tcp:recv(Socket,0),
    io:format("~p~n",[Data]),
    loopRecv(Socket).