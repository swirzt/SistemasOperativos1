-module(semaphore).

-export([semP/1, semV/1, crearSem/1, eliminarSem/1, locker_sem/1]).

%test
-export([sem/2, testSem/0, waiter_sem/2]).

locker_sem(0) ->
  receive
    {v, PId} ->
      PId ! thanks,
      locker_sem(1);

    {s, PId} ->
      PId ! 0,
      locker_sem(0)
  end;

locker_sem(N) ->
  receive
    {p, PId} ->
      PId ! yours,
      locker_sem(N - 1);

    {v, PId} ->
      PId ! thanks,
      locker_sem(N + 1);

    {s, PId} ->
      PId ! 0,
      locker_sem(N)
  end.


crearSem(C) -> spawn(?MODULE, locker_sem, [C]).

eliminarSem(S) -> S ! final.

semP(S) ->
  S ! {p, self()},
  receive yours -> ok end.


semV(S) ->
  S ! {v, self()},
  receive thanks -> ok end.


sem(S, W) ->
  semP(S),
  io:format("uno ~p~n", [self()]),
  io:format("dos ~p~n", [self()]),
  semV(S),
  W ! finished.


testSem() ->
  % a lo sumo dos usando io al mismo tiempo
  S = crearSem(2),
  W = spawn(?MODULE, waiter_sem, [S, 5]),
  spawn(?MODULE, sem, [S, W]),
  spawn(?MODULE, sem, [S, W]),
  spawn(?MODULE, sem, [S, W]),
  spawn(?MODULE, sem, [S, W]),
  spawn(?MODULE, sem, [S, W]),
  eliminarSem(S).


waiter_sem(_, 0) -> ok;
waiter_sem(S, N) -> receive finished -> waiter_sem(S, N - 1) end.
