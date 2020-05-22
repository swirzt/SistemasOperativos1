-module(broadcast).

-export([inicializar/0, broadcaster/1, subscribir/2, enviar/2, destruir/1]).

%% Ejemplo

-export([echo/0, start/0]).

%% Función de inicialización `inicializar/0` que devuelve el Pid del
%% proceso encargado de repartir los mensajes.

inicializar() ->
  io:format("Comienza el Broadcasting~n"),
  spawn(?MODULE, broadcaster, [[]]).

%% Función de subscripción `subscribir/2` que tome el Pid de un proceso
%% que subscribiese al servicio de repartición de mensajes y el
%% PId del proceso encargado de repartir los mensajes.

subscribir(Pid, Broad) -> Broad ! {subs, Pid}.

%% Función de envío de un mensaje a *todos* los subscriptores `enviar/2`, que
%% toma un mensaje y el Pid del proceso encargado de repartir el mensaje.

enviar(Msj, Broad) -> Broad ! {env, Msj}.

%% Función de eliminación del servicio de repartición de mensajes `destruir/1`
%% que toma el PId de un proceso y le indica que ya no se necesitarán sus servicios.

destruir(Broad) -> Broad ! dest.

%% Función auxiliar que envía el mensaje `Msj`
%% a cada Pid de la lista `Ps`.

broadcast(_, []) -> ok;

broadcast(Msj, [Pid | Ps]) ->
  Pid ! Msj,
  broadcast(Msj, Ps),
  ok.

%% Proceso encargado de repartir los mensajes.
%% Recordar que al igual que en el ejemplo visto de
%% `Ping Pong` la forma de hacer que el proceso siga
%% vivo es a través de llamadas recursivas.
%% Al finalizar el proceso con 'dest', este envia 'dest' a todos sus suscriptores

broadcaster(Ps) ->
  receive
    {subs, Pid} -> broadcaster([Pid | Ps]);

    {env, Msj} ->
      broadcast(Msj, Ps),
      broadcaster(Ps);

    dest -> broadcast(dest, Ps)
  end.

%% Si recibe 'dest' termina, de lo contrario muestra el mensaje y muere.

echo() ->
  receive
    dest -> io:format("Soy ~p y terminé~n", [self()]);

    Msj ->
      io:format("Soy ~p me llego ~p~n", [self(), Msj]),
      echo()
  end.


start() ->
  Gen1 = spawn(?MODULE, echo, []),
  Gen2 = spawn(?MODULE, echo, []),
  Gen3 = spawn(?MODULE, echo, []),
  BCaster = inicializar(),
  subscribir(Gen1, BCaster),
  subscribir(Gen2, BCaster),
  subscribir(Gen3, BCaster),
  enviar("Holis!", BCaster),
  enviar("Chau!", BCaster),
  destruir(BCaster),
  ok.
