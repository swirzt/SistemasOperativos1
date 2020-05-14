-module(min).
-export([min/1]).

min([Hd]) -> Hd;
min([Hd|Ti]) ->
    Rest = min(Ti),
    if
        Hd =< Rest -> Hd;
        true -> Rest
    end.