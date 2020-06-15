-module(servidor).

-export([dispatcher/1, escuchar/1,psocket/1]).

%mapas
-export([juegos/2,usuarios/1]).

-define(Puerto, 8000).

%% Dispatcher esta siempre esperando conecciones -> les asigna psocket
main(master) ->
    {ok, LSocket} = gen_tcp:listen(?Puerto,
				   [{packet, 0}, {active, false}]),
    U = spawn(?MODULE,usuarios,[maps:new()]), %% ¿Deberia ser un mapa o una lista? ¿Falta el cmdid?
    register(usuarios,U),
    J = spawn(?MODULE,juegos,[maps:new(),1]),
    register(juegos,J),
    escuchar(LSocket).

%% Escucha en el socket asignado los pedidos y crea un proceso que se encargue de manejarlo
escuchar(LSocket) ->
    {ok, Socket} = gen_tcp:accept(LSocket),
    %% TODO: Implementar una funcion que de el nodo de menor carga
    % spawn(nodoMenorCarga, ?MODULE, psocket, [Socket]),
    spawn(?MODULE, psocket, [Socket]),
    escuchar(LSocket).

%% Va a recibir un mensaje y actuar de acorde a eso
psocket(Socket,noname) ->
    case gen_tcp:recv(Socket, 0) of
        {con, Nombre} ->  pcomando({agregarUsuario,Nombre,self()}), 
                          receive
                              {ok,Nombre} -> gen_tcp:sendv(Socket,{ok,Nombre}),psocket(Socket,Nombre); %llama a psocket con user
                              {error, Nombre} -> gen_tcp:sendv(Socket,{error,Nombre}),psocket(Socket,noname) %se llama con nooname y espera otro user
                            
                          end;
        {error, closed} ->
            io:format("El cliente cerró la conexión~n")
    end,
    psocket(Socket,User);
psocket(Socket,User) ->
    case gen_tcp:recv(Socket, 0) of
        %% todos los comandos que estan en el pdf
        {ok, Paquete} ->
            io:format("Me llegó: ~p ~n",[Paquete]),
            gen_tcp:send(Socket, Paquete),
            echoResp(Socket);
        {error, closed} ->ok
            %avisar que se desconecto
    end,
    psocket(Socket,User).

%%self() si guarda la info del nodo en doonde esta
pcomando({agregarUsuario,Nombre,Psid}) ->
  usuarios ! {self(),{nuevo,Nombre,Psid}},
  receive
      {ok,Psid} -> Psid ! {ok,Nombre};
      _ -> Psid ! {error,Nombre}
  end.


%MapaDeNombres es un mapa que tiene como clave el nombre de usuario y como valor el psocket asociado
usuarios(MapaDeUsuarios) ->
    receive
        {Cartero,{nuevo,User,Psid}} -> Mapa = maps:put(User,Psid,MapaDeUsuarios), Cartero ! {ok,Psid}, usuarios(Mapa);
        _ -> usuarios(MapaDeUsuarios)
    end.

%% MapaDeJuegos es un mapa que tiene como clave el numero de juego y como valor una tupla de {local,visitante,espectadores[]}
juegos(MapaDeJuegos,N) ->
    receive
        {nuevo, Cmdid} -> Mapa = maps:put(N,{Cmdid,nadie,[]},MapaDeJuegos), Cmdid ! {ok,Cmdid,N}, juegos(Mapa,N+1);
        _ -> ok
    end.

