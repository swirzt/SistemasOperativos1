-module(listas).

-export([min/1, max/1, min_max/1, map/2, foreach/2, fecha_actual/0]).
-export([concat/1, fechaLista/1, arregla1/1, arregla2/1, arreglador/1]).

min([X | []]) -> X;

min([X | Xs]) ->
  Y = min(Xs),
  if
    X =< Y -> X;
    true -> Y
  end.


max([X | []]) -> X;

max([X | Xs]) ->
  Y = max(Xs),
  if
    X >= Y -> X;
    true -> Y
  end.


min_max(Xs) -> {min(Xs), max(Xs)}.

map(_, []) -> [];
map(Func, [X | Xs]) -> [Func(X) | map(Func, Xs)].

foreach(_, []) -> ok;

foreach(Func, [X | Xs]) ->
  Func(X),
  foreach(Func, Xs).


concat([]) -> [];
concat([X | Xs]) -> X ++ concat(Xs).

arregla1(DM) when length(DM) < 2 -> "0" ++ DM;
arregla1(DM) -> DM.

arregla2(A) when length(A) == 2 -> A;
arregla2([_ | As]) -> arregla2(As).

arreglador([X | []]) -> [arregla2(X)];
arreglador([X | Xs]) -> [arregla1(X) | arreglador(Xs)].

fechaLista({A, M, D}) -> [D, M, A].

fecha_actual() -> concat(arreglador(map(fun (X) -> integer_to_list(X) end, fechaLista(date())))).
