-module(testServer).

-compile(export_all).

-define(Puerto, 8000).


main(master) ->
    {ok, LSocket} = gen_tcp:listen(?Puerto, [{packet, 0}, {active, false}]),
    escuchar(LSocket).

escuchar(LSocket) ->
    {ok, Socket} = gen_tcp:accept(LSocket),
    io:format("Ey, el socket esta de lujo~n"),
    spawn(?MODULE, psocket, [Socket,noname]),
    escuchar(LSocket).

psocket(Socket,noname) ->
    io:format("I received - ~p -~n",[gen_tcp:recv(Socket,0)]).

pcomando({con,_,Id}) -> Id ! {error, pff}.

conectarYname() -> {ok , Socket} = gen_tcp:connect("localhost"
                                   , ?Puerto
                                    %% El socket es activo por defecto.
                                   , [binary, {packet, 0}, {active, false}]),
                    io:format("Socket es ~p ~n",[Socket]),               
                    io:format("Ey, me conecte~n"),
                    s = {con, "swirzt"},
                    gen_tcp:send(Socket, binarytoterm),
                    io:format("Ey, mande~n"),
                    gen_tcp:close(Socket).


