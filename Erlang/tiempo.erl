-module(tiempo).

-export([wait/1, cronometro/3]).

wait(T) -> receive after T -> ok end.

cronometro(_, Time, Int) when Time < Int -> ok;

cronometro(Func, Time, Int) ->
  wait(Int),
  Func(),
  cronometro(Func, Time - Int, Int).
