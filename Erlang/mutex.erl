-module(mutex).
%% Funciones de la variable mutex
-export[(locker/1)].
-export([crear/0, borrar/1]).
-export([tomar/1, soltar/1]).

%% Funciones para testear la implementación
-export([testLock/0,waiter/2]).
-export([f/2]).

locker(free)->
    receive
        {mut,PId} -> PId ! yours,
                     locker(PId);
        {who, Ask} -> Ask ! noone,
                      locker(free);
        finish -> ok
    end;
locker(PId)->
    receive
        {unmut,PId} -> PId ! ok,
                       locker(free);
        {who, Ask} -> Ask ! PId,
                      locker(PId);
        finish -> ok
    end.

crear() -> spawn(?MODULE,locker,[free]).

borrar(Mut) -> Mut ! finish.

tomar(Mut) ->
    Mut ! {mut,self()},
    receive
        yours -> ok
    end.

soltar(Mut) ->
    Mut ! {unmut,self()},
    receive
        ok -> ok
    end.

testLock () ->
    L = crear(),
    W=spawn(?MODULE,waiter,[L,3]),
    spawn(?MODULE,f,[L,W]),
    spawn(?MODULE,f,[L,W]),
    spawn(?MODULE,f,[L,W]),
    ok.

f (L,W) -> tomar(L),
           % 
           io:format("uno ~p~n",[self()]),
           io:format("dos ~p~n",[self()]),
           io:format("tres ~p~n",[self()]),
           io:format("cuatro ~p~n",[self()]),
           %
           soltar(L),
           W!finished.
waiter (L,0)  -> borrar(L);
waiter (L,N)  -> receive finished -> waiter(L,N-1) end.
