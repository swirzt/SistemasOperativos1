-module(cliente).
-export([main/1]).
-define(Puerto, 8000).

main(fari) ->
    {ok,Socket} = gen_tcp:connect("localhost", 8000, [{packet, 0}, {active,false}]),
    gen_tcp:send(Socket, "CON Fari"),
    {ok,Data} = gen_tcp:recv(Socket,0),
    io:format("~p~n", [Data]),
    gen_tcp:send(Socket, "NEW 1"),
    {ok,Datb} = gen_tcp:recv(Socket,0),
    io:format("~p~n", [Datb]),
    gen_tcp:send(Socket, "LSG 2"),
    {ok,Datc} = gen_tcp:recv(Socket,0),
    io:format("~p~n", [Datc]),
    timer:sleep(5000),
    gen_tcp:send(Socket, "PLA jugadita 1#nonode@nohost 5"),
    {ok,Dath} = gen_tcp:recv(Socket,0),
    io:format("~p~n", [Dath]),
    gen_tcp:send(Socket, "PLA jugadita 1#nonode@nohost 6"),
    {ok,Dats} = gen_tcp:recv(Socket,0),
    io:format("~p~n", [Dats]);
main(nati)->
    {ok,Socket} = gen_tcp:connect("localhost", 8000, [{packet, 0}, {active,false}]),
    gen_tcp:send(Socket, "CON Nati"),
    {ok,Datd} = gen_tcp:recv(Socket,0),
    io:format("~p~n", [Datd]),
    gen_tcp:send(Socket, "ACC 3 1#nonode@nohost"),
    {ok,Date} = gen_tcp:recv(Socket,0),
    io:format("~p~n", [Date]).


