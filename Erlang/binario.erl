-module(binario).

-export([func/0]).

-record(btree, {izq, val, der}).

func() ->
  X20 = #btree{izq = empty, val = 20, der = empty},
  X40 = #btree{izq = empty, val = 40, der = empty},
  X30 = #btree{izq = X20, val = 30, der = X40},
  X100 = #btree{izq = empty, val = 100, der = empty},
  X90 = #btree{izq = empty, val = 90, der = X100},
  X50 = #btree{izq = X30, val = 50, der = X90},
  io:format("~p~n", [X50]).
