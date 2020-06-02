-module(ej).

-export([w/0, s/1]).

w() ->
  io:format("Trabajando en ~p~n", [node()]),
  timer:sleep(2000),
  w().


keeper([]) ->
  receive
    {'EXIT', P, _} ->
      io:format("El nodo ~p, se desconectó~n", [node(P)]),
      io:format("No quedan más nodos, terminé~n")
  end;

keeper([Nname | Ns]) ->
  receive
    {'EXIT', P, _} ->
      io:format("El nodo ~p, se desconectó~n", [node(P)]),
      io:format("Continuo el trabajo en ~p~n", [Nname]),
      spawn_link(Nname, ?MODULE, w, [])
  end,
  keeper(Ns).


s([Nname | Ns]) ->
  process_flag(trap_exit, true),
  spawn_link(Nname, ?MODULE, w, []),
  keeper(Ns).
