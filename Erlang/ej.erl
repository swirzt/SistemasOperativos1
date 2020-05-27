-module(ej).

-export([w/0, s/0]).

w() ->
  io:format("Trabajando...~n"),
  timer:sleep(2000),
  w().


s() -> spawn(?MODULE, w, []).
