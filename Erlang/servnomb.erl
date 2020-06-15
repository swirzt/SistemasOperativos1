-module(servnomb).

%% Creación y eliminación del servicio

-export([iniciar/0, finalizar/1]).

%% Servidor

-export([servnombres/2]).

%% Librería de Acceso

-export([nuevoNombre/2, quienEs/2, listaDeIds/1]).

% Iniciar crea el proceso servidor, y devuelve el PId.
iniciar() ->
  spawn(
    ?MODULE,
    %% El servidor comienza con un mapa vacío
    %% y el contador en 1
    servnombres,
    [maps:new(), 1]
  ).

%% Función de servidor de nombres.

servnombres(Map, N) ->
  receive
    %% Llega una petición para crear un Id para nombre
    {nuevoId, Nombre, CId} ->
      MapN = maps:put(Nombre, N, Map),
      CId ! N,
      servnombres(MapN, N + 1);

    %% Llega una petición para saber el nombre de tal Id
    {buscarId, NId, CId} ->
      CId ! maps:find(NId, Map),
      servnombres(Map, N);

    %% Entrega la lista completa de Ids con Nombres.
    {verLista, CId} ->
      CId ! maps:keys(Map),
      servnombres(Map, N);

    %% Cerramos el servidor. Va gratis
    {finalizar, CId} -> CId ! ok
  end.

%% Dado un nombre y un servidor le pide que cree un identificador
%% único.

nuevoNombre(Nombre, NMServ) ->
  NMServ ! {nuevoId, Nombre, self()},
  receive X -> X end.

%% Función que recupera el nombre desde un Id

quienEs(Id, NMServ) ->
  NMServ ! {buscarId, Id, self()},
  receive
    error -> nada;
    {ok, Idd} -> Idd
  end.

%% Pedimos la lista completa de nombres e identificadores.

listaDeIds(NMServ) ->
  NMServ ! {verLista, self()},
  receive X -> io:format("~p~n", [X]) end.


% Ya implementada :D!
finalizar(NMServ) ->
  NMServ ! {finalizar, self()},
  receive ok -> ok end.
