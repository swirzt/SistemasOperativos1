-module(mensajes).
-export([echo/0]).
-export([start/0]).
-export([inicializar/0]).
-export([subscribir/2]).
-export([enviar/2]).
-export([destruir/1]).
-export([send/2]).
-export([broadCaster/1]).

send([],_) -> empty;
send([PID|List],Msj) ->
    PID ! Msj,
    send(List,Msj),
    ok.

broadCaster(ListaSub) ->
    receive
        {sub,PID} -> broadCaster([PID|ListaSub]);
        {men,Msj} -> send(ListaSub,Msj),
                     broadCaster(ListaSub);
        delete -> final
    end.

inicializar() ->
    P = spawn(mensajes,broadCaster,[[]]),
    P.

subscribir(PSub,PCast) -> PCast ! {sub,PSub}.

enviar(Msj,PCast) -> PCast ! {men,Msj}.

destruir(PCast) -> PCast ! delete.

echo() ->
    receive
        Msj -> io:format("Soy ~p me llego ~p~n",[self(), Msj])
    end.

start() ->
    %% Creamos tres procesos echos
    Gen1 = spawn(mensajes, echo, []),
    Gen2 = spawn(mensajes, echo, []),
    Gen3 = spawn(mensajes, echo, []),
    %% Comenzamos con el servicio de BroadCasting
    BCaster = inicializar(),
    %% Subscribimos a los tres procesos echo
    subscribir(Gen1,BCaster),
    subscribir(Gen2,BCaster),
    subscribir(Gen3,BCaster),
    %% Envíamos un mensaje
    enviar("Holis!", BCaster),
    %% Destruimos el proceso de BroadCasting
    destruir(BCaster),
    ok.
