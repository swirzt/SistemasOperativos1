-module(factorial).
-export([factorial/1]).

% Funcion factorial por pattern matching.

factorial(0) -> 1;
factorial(N) -> N * factorial(N-1).