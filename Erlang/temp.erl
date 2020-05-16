-module(temp).
-export([f2c/1,c2f/1]).
-export([convertir/1]).

f2c(F) -> (F-32) * 5 / 9.

c2f(C) -> C * 9 / 5 + 32.

convertir({f,F}) -> {c,f2c(F)};
convertir({c,C}) -> {f,c2f(C)}.
