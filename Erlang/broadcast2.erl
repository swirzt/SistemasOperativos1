-module(broadcast2).
-export([iniciar/0,finalizar/0,start/0]).
-export([broadcaster/1,registrar/1,echo/0]).

broadcast(_, []) -> ok;
broadcast(Msj, [Pid | Ps]) ->
    Pid ! Msj,
    broadcast(Msj, Ps),
    ok.

broadcaster(Ps) ->
    receive
        {subs, Pid } ->
            broadcaster([Pid | Ps]);
        {env , Msj } ->
            broadcast(Msj, Ps),
            broadcaster(Ps);
        dest -> broadcast(dest, Ps)
    end.

iniciar() ->
    BC = spawn(?MODULE, broadcaster, [[]]),
    registrar(BC).

registrar(Pid) ->
    register(broadcaster,Pid).

finalizar() ->
    broadcaster ! dest,
    unregister(broadcaster).

subscribir(Pid) -> broadcaster ! {subs, Pid}.

enviar(Msj) -> broadcaster ! {env, Msj}.

echo() ->
    receive
        dest -> io:format("Soy ~p y terminé~n",[self()]);     
        Msj -> io:format("Soy ~p me llego ~p~n",[self(), Msj]),
               echo()
    end.

start() ->
    Gen1 = spawn(?MODULE, echo, []),
    Gen2 = spawn(?MODULE, echo, []),
    Gen3 = spawn(?MODULE, echo, []),
    iniciar(),
    subscribir(Gen1),
    subscribir(Gen2),
    subscribir(Gen3),
    enviar("Holis!"),
    enviar("Chau!"),
    finalizar(),
    ok.
