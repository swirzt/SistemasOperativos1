-module(maestro).

-export([start/1, to_slave/2]).
-export([maestro/1, esclavo/0]).

esclavo() ->
  receive
    die ->
      io:format("Mori xd~n"),
      exit(die);

    Msj -> io:format("Recibí '~p'~n", [Msj])
  end,
  esclavo().


reviver(Pid, [P | Ps]) ->
  if
    Pid == P ->
      X = spawn_link(?MODULE, esclavo, []),
      [X | Ps];

    true ->
      Ys = reviver(Pid, Ps),
      [P | Ys]
  end.


enviar(Msj, 0, [P | _]) -> P ! Msj;
enviar(Msj, N, [_ | Ps]) -> enviar(Msj, N - 1, Ps).

maestro({start, N}) ->
  L = spawner(N, []),
  process_flag(trap_exit, true),
  maestro({N, L});

maestro({N, L}) ->
  receive
    {Msj, M} ->
      enviar(Msj, M, L),
      maestro({N, L});

    {'EXIT', P, R} ->
      io:format("~p murio por ~p~n", [P, R]),
      LL = reviver(P, L),
      maestro({N, LL})
  end.


spawner(0, Ps) -> Ps;

spawner(N, Ps) ->
  X = spawn_link(?MODULE, esclavo, []),
  spawner(N - 1, [X | Ps]).


% N es un indice (arranca en 0)
to_slave(Msj, N) -> master ! {Msj, N}.

start(N) ->
  M = spawn(?MODULE, maestro, [{start, N}]),
  register(master, M),
  ok.
