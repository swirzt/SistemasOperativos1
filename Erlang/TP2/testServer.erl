-module(testServer).

-compile(export_all).

-define(Puerto, 8000).

printearBin() -> io:format("~p~n",[error]),
io:format("~p~n",[term_to_binary(error)]).

echo()->io:format("nodito ~p~n",[node()]).

testing() ->
    [X|_] = nodes(),
    spawn(X,?MODULE,echo,[]).

main(master) ->
    {ok, LSocket} = gen_tcp:listen(?Puerto, [{packet, 0}, {active, false}]),
    escuchar(LSocket).

escuchar(LSocket) ->
    {ok, Socket} = gen_tcp:accept(LSocket),
    io:format("Ey, el socket esta de lujo~n"),
    spawn(?MODULE, psocket, [Socket,noname]),
    escuchar(LSocket).

psocket(Socket,noname) ->
    {ok,Packet} = gen_tcp:recv(Socket,0,0),
    io:format("I received - ~p -~n",[Packet]),
    psocket(Socket,noname).

pcomando({con,_,Id}) -> Id ! {error, pff}.

conectarYname() -> {ok , Socket} = gen_tcp:connect("localhost"
                                   , ?Puerto
                                    %% El socket es activo por defecto.
                                   , [{packet, 0}, {active, false}]),
                    io:format("Socket es ~p ~n",[Socket]),               
                    io:format("Ey, me conecte~n"),
                    gen_tcp:send(Socket, "CON swirzt"),
                    io:format("Ey, mande~n"),
                    gen_tcp:close(Socket).


jugada([X|Xs],N,Turno) -> 
    if
        N == 0 ->  if
                        X == 0 -> [Turno] ++ Xs;
                        true   -> [X]++Xs
                   end;
        N > 0 -> [X] ++ jugada(Xs,N-1,Turno)
    end.

imprimeTablero([A1,A2,A3,B1,B2,B3,C1,C2,C3]) ->
    io:format("~p | ~p | ~p ~n",[A1,A2,A3]),
    io:format("---------~n"),
    io:format("~p | ~p | ~p ~n",[B1,B2,B3]),
    io:format("---------~n"),
    io:format("~p | ~p | ~p ~n",[C1,C2,C3]).

%% "# /"
comaAlfinal([]) -> [];
comaAlfinal([X]) -> [X];
comaAlfinal([X|Xs]) -> [(X ++ ",")|comaAlfinal(Xs)].
parseoDeJuegos(Lista) ->
    ListaDeListas = [maps:to_list(X) || X <- Lista],
    io:format("~p ~n",[ListaDeListas]),
    Unidos = lists:concat(ListaDeListas),
    io:format("~p ~n",[Unidos]),
    Stringueado = [lists:concat([A,"/",B,"/",C]) || {A,{B,C,_,_}} <- Unidos],
    io:format("~p ~n",[Stringueado]),
    lists:concat(comaAlfinal(Stringueado)).
    % lists:concat(comaAlfinal([lists:concat([A,"/",B,"/",C]) || {A,{B,C,_,_}} <- lists:concat([maps:to_list(X) || X <- Lista])])).

    testScope() ->
        self() ! {holis,9},
        self() ! chau,
        receive
            {L,X} -> ok
        end,
        io:format(" ~p ~p~n",[L,X]),
        receive
            chau -> Y = 5
        end,
        io:format("~p~n",[Y]).

pedro() ->
    io:format("~p~n",[registered()]).