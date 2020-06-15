-module(testcarga).

-export([pepe/0, start/0, recibeprintea/0]).

head([X | _]) ->
   X.

start() ->
   spawn(head(nodes()), ?MODULE, pepe, []).

pepe() ->
   io:format("~p~n", [self()]).

recibeprintea() ->
   receive
     X ->
        io:format("~p~n", [X])
   end.

