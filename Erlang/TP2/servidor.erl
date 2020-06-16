-module(servidor).

-compile(export_all).

%% -export([dispatcher/1, escuchar/1, psocket/1]).
%mapas
%% -export([juegos/2, usuarios/1]).

-define(Puerto, 8000).

%% Dispatcher esta si0re esperando conecciones -> les asigna psocket
main(master) ->
    {ok, LSocket} = gen_tcp:listen(?Puerto, [binary, {packet, 0}, {active, false}]),
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
%% TODO: Pasar todo a binary
psocket(Socket, noname) ->
    case gen_tcp:recv(Socket, 0) of
        {ok, Packet} -> case binary_to_term(Packet) of
                            {con, Nombre} ->
                                pcomando({con, Nombre, self()}),
                                receive
                                    {ok, Nombre} ->
                                        gen_tcp:sendv(Socket, term_to_binary({ok, Nombre})),
                                        psocket(Socket, Nombre); %llama a psocket con user
                                    {error, Nombre} ->
                                        gen_tcp:sendv(Socket, term_to_binary({error, Nombre})),
                                        psocket(Socket, noname) %se llama con noname y espera otro user
                                end;
                            _ -> gen_tcp:sendv(Socket, term_to_binary({error, noRegistrado})),
                                 psocket(Socket, noname)
                            end;
        {error, closed} -> gen_tcp:close(Socket)
    end;
psocket(Socket, User) ->
    case gen_tcp:recv(Socket, 0,0) of
        {ok, Packet} -> case binary_to_term(Packet) of
                            {con, Nombre} -> gen_tcp:send(Socket,term_to_binary({{error,Nombre}})),
                                             psocket(Socket,User);
                            {lsg, Nombre} -> pcomando({lsg,self()}),
                                             receive
                                                 {ok, Mapa} -> gen_tcp:send(Socket,term_to_binary({ok,Nombre,Mapa})),
                                                               psocket(Socket,User);
                                                 {error, _} -> gen_tcp:send(Socket, term_to_binary({error,Nombre})),
                                                               psocket(Socket,User)
                                             end;
                            {new, User} -> pcomando({new, User, self()}),
                                           receive
                                               {ok, N} -> gen_tcp:send(Socket, term_to_binary({ok, User, N}))
                                           end,
                                           psocket(Socket, User);
                            {new, Nombre} -> gen_tcp:send(Socket, term_to_binary({error, User})),
                                             psocket(Socket, User);
                            {acc, User, Nid} -> pcomando({acc, User, self(), Nid}),
                                                receive
                                                    {ok, User, Nid} -> algo;
                                                    {error, User, Nid} -> otro
                                                end,
                                                psocket(Socket, User);
                            {acc, Nombre, _} -> otro,
                                                psocket(Socket, User);
                            {}
                            _ -> ok
                            end;
        {error, closed} -> %desregistrar nombre
                           %terminar juegos y dar victoria por abandono
                           %cerrar socket
                           gen_tcp:close(Socket);
        {error, timeout} -> receive
                                _ -> ok %este tambien llama a Pscoket
                            after 0 -> psocket(Socket,User)
                            end
    end.

%%self() sí guarda la info del nodo en donde esta
pcomando({con, Nombre, Psid}) ->
    usuarios ! {self(), {nuevo, Nombre, Psid}},
    receive
      {ok, Psid} ->
          Psid ! {ok, Nombre};
      _ ->
          Psid ! {error, Nombre}
    end;

%% Tenemos que mandar la lista de juegos, o imprimirla desde aca?
pcomando({lsg, Psid}) ->
    juegos ! {lista,self()},
    receive
        {lista,MapaDeJuegos} -> Psid ! {ok,MapaDeJuegos};
        _ -> Psid ! {error, Psid}
    end;

pcomando({new,User,Psid}) ->
    juegos ! {nuevo, User,self()},
    receive
        {ok,N} -> Psid ! {ok, N}
    end;

pcomando({acc,User,Psid,Juegoid}) ->
    juegos ! {acc,User,Juegoid,self()},
    receive
        {ok, Id} -> Psid ! {ok,Psid,Id};
        {error,ocupado,Juegoid} -> Psid ! {error,User,Juegoid};
        {error,noExiste,Juegoid} -> Psid ! {error,User,Juegoid}
    end,
    usuarios ! {acc,User,Juegoid,self()},
    receive
        {ok,User,Juegoid}
    end; 

%% Esperar a implementar el juego para ver que onda
pcomando({pla, User, Juegoid, Jugada,Psid}) when (Jugada > 9) or (Jugada < 1) -> Psid ! {error, User, Juegoid,Jugada};
pcomando({pla, User, Juegoid, Jugada,Psid}) ->
    juegos ! {obtener,Juegoid,self()}, 
    receive
        {User,Visitante,Espectadores,JuegoTateti,{TableroActual,Jugada,1}} -> JuegoTateti ! {self(),local,Jugada}, receive
                                                                                                                        {Tablero} -> juegos ! {updateGame,Tablero}, broadcaster([Visitante] ++ Espectadores, Tablero), Psid ! {ok,User,Juegoid,Jugada}     
                                                                                                                   end;
        {Local,User,Espectadores,JuegoTateti,{TableroActual,Jugada,-1}} -> JuegoTateti ! {self(),away,Jugada}
        _ -> Psid ! {error, User,Juegoid,Jugada}
    end;

pcomando({obs, User, Juegoid }) -> ok;
pcomando({lea, User, Juegoid}) -> ok;

pcomando({bye,User,Psid}) -> 
    usuarios ! {listaEliminar,User,self()},
    receive
        {juegosActuales,JuegosActuales} -> ok
    end.

%MapaDeNombres es un mapa que tiene como clave el nombre de usuario y como valor una tupla {psocket,listaDeJuegos[]}
usuarios(MapaDeUsuarios) ->
    receive
      {Cartero, {nuevo, User, Psid}} ->
          case maps:find(User,MapaDeUsuarios) of 
            error -> Mapa = maps:put(User, {Psid,[]}, MapaDeUsuarios),
                     Cartero ! {ok, Psid},
                     usuarios(Mapa);
            _ -> Cartero ! {error, Psid},usuarios(MapaDeUsuarios)
          end;
      {acc,User,Juegoid,Cartero} -> {Psid,JuegosActuales} = maps:find(User,MapaDeUsuarios), Mapa = maps:put (User, {Psid,Juegoid ++ JuegosActuales}), Cartero ! {ok,Juegoid}, usuarios(Mapa);
      {listaEliminar,User,Cartero} -> {_,JuegosActuales} = maps:find(User,MapaDeUsuarios), Cartero ! {juegosActuales,JuegosActuales}, Mapa = maps:remove(User,MapaDeUsuarios), usuarios(Mapa);
      _ -> usuarios(MapaDeUsuarios)
    end.

%% MapaDeJuegos es un mapa que tiene como clave el numero de juego y como valor una tupla de {local,visitante,espectadores[],procesoDeJuego}
juegos(MapaDeJuegos, N) ->
    receive
      {nuevo, User,Cartero} ->
          Mapa = maps:put(N, {User, nadie, [],sinjuego,{newtab,0,1}}, MapaDeJuegos), %% El turno arranca en cero para ver que nadie esta jugando
          Cartero ! {ok, N},
          juegos(Mapa, N + 1);
      {lista, Cmdid} -> Cmdid ! {lista,MapaDeJuegos}, juegos(MapaDeJuegos,N+1);
      {acc,User,Juegoid,Cartero} -> 
          case maps:find(Juegoid,MapaDeJuegos) of
              {ok, {Local, nadie ,Espectadores,sinjuego,{Tablero,0,1}}} -> 
                  Mapa = maps:put(Juegoid, {Local,User,Espectadores,spawn(?MODULE,tateti,[newtab,1,1]),{Tablero,1,1}},MapaDeJuegos), %% Cuando alguien acepta amrcamos el primer turno
                  Cartero ! {ok, Juegoid},
                  juegos(Mapa, N);
              {ok, {_, _, _,_,{_,_,_}}} -> Cartero ! {error,ocupado,Juegoid}, juegos(MapaDeJuegos,N);
              error -> Cartero ! {error,noExiste,Juegoid}, juegos(MapaDeJuegos, N)
          end;
      {obtener,User,Cartero} -> Cartero ! {maps:find(User, MapaDeJuegos)}, juegos(MapaDeJuegos,N);
      _ ->   ok
    end.

%% 1 | 2 | 3
%% ---------
%% 4 | 5 | 6
%% ---------
%% 7 | 8 | 9

-define(newtab,[0,0,0,0,0,0,0,0,0]).

checkGanador([A1,A2,A3,B1,B2,B3,C1,C2,C3]) ->
    %% filas
    F1 = A1 + A2 +A3, F2 = B1 + B2 + B3, F3 = C1 + C2 + C3,
    %% columnas
    Col1 = A1 + B1 + C1, Col2 = A2 + B2 + C2, Col3 = A3 + B3 + C3,
    %% diagonales
    Diag1 = A1 + B2 + C3, Diag2 = C1 + B2 + C3,
    %% Hardcoded because why not
    if 
        %% Gano J1
        (F1 == 3) or (F2 == 3) or (F3 == 3) or (Col1 == 3) or (Col2 == 3) or (Col3 == 3) or (Diag1 == 3) or (Diag2 == 3) -> w1; 
        %% Gano J2
        (F1 == -3) or (F2 == -3) or (F3 == -3) or (Col1 == -3) or (Col2 == -3) or (Col3 == -3) or (Diag1 == -3) or (Diag2 == -3) -> w2;
        %% Nadie
        true -> nada    
    end.
%% Me doy asco

jugada([X|Xs],N,Turno) -> 
    if
        N == 1 ->  if
                        X == 0 -> Turno ++ Xs;
                        true   -> X++Xs
                   end;
        N > 1 -> X ++ jugada(Xs,N-1,Turno)
    end.


%% Turno vale 1 o -1
%% Pueden jugar local o away, 1 es local y -1 es away. Se identifican en el MapaDeJuegos
tateti(Tablero, Plays,Turno) ->
    receive
        {Cartero,local, Pos} -> noimplementado;
        {Cartero,away, Pos} -> noimplementado
    end,
    % De arriba saco TableroN y K = Plays + 1
    % Le manda a los demás la jugada
    %ahora checkeamos
    case checkGanador(TableroN) of
        w1 -> hacercuandoganaLocal;
        w2 -> hacercuandoganaAway;
        nada -> if
                    K == 9 -> hacercuandoEmpate;
                    true -> juego(TableroN,K)
                end
    end.