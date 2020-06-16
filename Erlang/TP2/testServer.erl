-module(testServer).

-compile(export_all).

-define(Puerto, 8000).


main(master) ->
    {ok, LSocket} = gen_tcp:listen(?Puerto, [binary, {packet, 0}, {active, false}]),
    escuchar(LSocket).

escuchar(LSocket) ->
    {ok, Socket} = gen_tcp:accept(LSocket),
    io:format("Ey, el socket esta de lujo~n"),
    spawn(?MODULE, psocket, [Socket,noname]),
    escuchar(LSocket).

psocket(Socket,noname) ->
    {ok,Packet} = gen_tcp:recv(Socket,0,0),
    io:format("I received - ~p -~n",[binary_to_term(Packet)]),
    psocket(Socket,noname).

pcomando({con,_,Id}) -> Id ! {error, pff}.

conectarYname() -> {ok , Socket} = gen_tcp:connect("localhost"
                                   , ?Puerto
                                    %% El socket es activo por defecto.
                                   , [binary, {packet, 0}, {active, false}]),
                    io:format("Socket es ~p ~n",[Socket]),               
                    io:format("Ey, me conecte~n"),
                    gen_tcp:send(Socket, term_to_binary({con, "swirzt"})),
                    io:format("Ey, mande~n"),
                    gen_tcp:close(Socket).


