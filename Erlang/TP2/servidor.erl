-module(servidor).

-compile(export_all).

%% -export([dispatcher/1, escuchar/1, psocket/1]).
%mapas
%% -export([juegos/2, usuarios/1]).

-define(Puerto, 8000).

%% Dispatcher esta siempre esperando conecciones -> les asigna psocket
main(master) ->
    {ok, LSocket} = gen_tcp:listen(?Puerto, [{packet, 0}, {active, false}]),
    U = spawn(?MODULE,
              usuarios,
              [maps:new()]), %% Â¿Deberia ser un mapa o una lista? Â¿Falta el cmdid?
    register(usuarios, U),
    J = spawn(?MODULE, juegos, [maps:new(), 1]),
    register(juegos, J),
    escuchar(LSocket).

%% Escucha en el socket asignado los pedidos y crea un proceso que se encargue de manejarlo
escuchar(LSocket) ->
    {ok, Socket} = gen_tcp:accept(LSocket),
    %% TODO: Implementar una funcion que de el nodo de menor carga
    % spawn(nodoMenorCarga, ?MODULE, psocket, [Socket]),
    spawn(?MODULE, psocket, [Socket]),
    escuchar(LSocket).

%% Va a recibir un mensaje y actuar de acorde a eso
psocket(Socket, noname) ->
    case gen_tcp:recv(Socket, 0) of
      {con, Nombre} ->
          pcomando({con, Nombre, self()}),
          receive
            {ok, Nombre} ->
                gen_tcp:sendv(Socket, {ok, Nombre}),
                psocket(Socket, Nombre); %llama a psocket con user
            {error, Nombre} ->
                gen_tcp:sendv(Socket, {error, Nombre}),
                psocket(Socket, noname) %se llama con noname y espera otro user
          end;
      {error, closed} ->
          io:format("El cliente cerró la conexión~n")
    end;
psocket(Socket, User) ->
    case gen_tcp:recv(Socket, 0) of
      %% QUE MIERDA ES CMDID
      {lsg, ALGOGOGOGOG} ->
          pcomando({lsg,self()}),
          receive
            {ok, Mapa} -> gen_tcp:sendv(Socket,)
          end;
      {error, closed} ->
          ok
    end,
    psocket(Socket, User).

%%self() sí guarda la info del nodo en donde esta
%%Preguntar si hay que usar mutex por los problemas de propridad
pcomando({con, Nombre, Psid}) ->
    usuarios ! {self(), {nuevo, Nombre, Psid}},
    receive
      {ok, Psid} ->
          Psid ! {ok, Nombre};
      _ ->
          Psid ! {error, Nombre}
    end;

pcomando({lsg, Psid}) ->
    juegos ! {lista,self()},
    receive
        {lista,MapaDeJuegos} -> Psid ! {ok,MapaDeJuegos}
        _ -> Psid ! {error, Psid}
    end;

pcomando({new,User,Psid}) ->
    juegos ! {nuevo, User,self()},
    receive
        {ok,N} -> Psid ! {ok,Psid} 
    end;

pcomando({acc,User,Psid,Juegoid}) ->
    juegos ! {acc,User,Juegoid,self()},
    receive
        {ok, Id} -> Psid ! {ok,Psid,Id}
        {error,ocupado,Juegoid} -> Psid ! {error,Psid,Juegoid}
        {error,noExiste,Juegoid} -> Psid ! {error,Psid,Juegoid}
    end;

%MapaDeNombres es un mapa que tiene como clave el nombre de usuario y como valor el psocket asociado
usuarios(MapaDeUsuarios) ->
    receive
      {Cartero, {nuevo, User, Psid}} ->
          case maps:find(User,MapaDeUsuarios) of 
            error -> Mapa = maps:put(User, Psid, MapaDeUsuarios),
                     Cartero ! {ok, Psid},
                     usuarios(Mapa);
            _ -> Cartero ! {error, Psid},usuarios(MapaDeUsuarios);
      _ ->
          usuarios(MapaDeUsuarios)
    end.

%% MapaDeJuegos es un mapa que tiene como clave el numero de juego y como valor una tupla de {local,visitante,espectadores[]}
juegos(MapaDeJuegos, N) ->
    receive
      {nuevo, User,Cartero} ->
          Mapa = maps:put(N, {User, nadie, []}, MapaDeJuegos),
          Cartero ! {ok, N},
          juegos(Mapa, N + 1);
      {lista, Cmdid} -> Cmdid ! {lista,MapaDeJuegos}, juegos(MapaDeJuegos);
      {acc,User,Juegoid,Cartero} -> 
          case maps:find(Juegoid,MapaDeJuegos) of
              {ok, {Local, nadie ,Lista}} -> 
                  Mapa = maps:put(Juegoid, {Local,User,Lista},MapaDeJuegos),
                  Cartero ! {ok, Juegoid},
                  juegos(Mapa);
              {ok, {Local, _, Lista}} -> Cartero ! {error,ocupado,Juegoid}, juegos(MapaDeJuegos);
              error -> Cartero ! {error,noExiste,Juegoid}, juegos(MapaDeJuegos);
      _ ->   ok
    end.

