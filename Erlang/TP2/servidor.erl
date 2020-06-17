-module(servidor).

-compile(export_all).

-define(Puerto, 8000).

%% ------------------ ZONA DISPATCHER ------------------------------%%
%% Dispatcher esta si0re esperando conecciones -> les asigna psocket
%% Tal vez {packet, 0} cierra el socket
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
%% ------------------ FIN ZONA DISPATCHER --------------------------%%


%% ------------------ ZONA PSOCKET ---------------------------------%%
-define(TIMEOUT,1).
%% Va a recibir un mensaje y actuar de acorde a eso
%% TODO: Pasar todo a string
psocket(Socket, noname) ->
    case gen_tcp:recv(Socket, 0) of
        {ok, Packet} -> [X|Xs] = string:lexemes(Packet, " "),
                        case X of
                            "CON" ->Name = lists:nth(1,Xs),
                                    pcomando({con, Name, self()}),
                                    receive
                                        {ok, Name} ->
                                            gen_tcp:sendv(Socket, "OK " ++  Name),
                                            psocket(Socket, Name); %llama a psocket con user
                                        {error, Name} ->
                                            gen_tcp:sendv(Socket, "ERROR " ++ Name),
                                            psocket(Socket, noname) %se llama con noname y espera otro user
                                    end;
                            _ ->    gen_tcp:sendv(Socket, "ERROR noregistrado"),
                                    psocket(Socket, noname)
                        end;
        {error, closed} -> gen_tcp:close(Socket)
    end;

psocket(Socket, User) ->
    case gen_tcp:recv(Socket, 0,?TIMEOUT) of
        {ok, Packet} -> [X|Xs] = string:lexemes(Packet, " "),
                        case X of
                           "CON" -> gen_tcp:send(Socket,"ERROR yaregistrado"),
                                    psocket(Socket,User);
                           "LSG" -> Cmdid = lists:nth(1,Xs),
                                    pcomando({lsg, self()}),
                                    receive
                                        {ok, Mapa} -> gen_tcp:send(Socket,parsemaeelmapa,Mapa);
                                        {error, _} -> gen_tcp:send(Socket, "ERROR " ++ Cmdid)
                                    end,
                                    psocket(Socket,User);
                           "NEW" -> Cmdid = lists:nth(1,Xs),
                                    pcomando({new, User, self()}),
                                    receive
                                        {ok, N} -> gen_tcp:send(Socket, lists:concat(["OK ",Cmdid," ",N]));
                                        {error, _} -> gen_tcp:send(Socket, "ERROR " ++ Cmdid)
                                    end,
                                    psocket(Socket, User);
                           "ACC" -> Cmdid = lists:nth(1,Xs),
                                    Gid = lists:nth(2,Xs),
                                    pcomando({acc, User, self(), Gid}),
                                    receive
                                        {ok, User, Gid} -> gen_tcp:send(Socket, term_to_binary({ok, Cmdid, Nid}));
                                        {error, User, Gid} -> gen_tcp:send(Socket, term_to_binary({error, Cmdid, Nid}))
                                    end,
                                    psocket(Socket, User);
                            {pla, Cmdid, Nid, Jugada} -> pcomando({pla, User, Nid, Jugada, self()}),
                                                         receive %%Esto cambia con el tablero
                                                             {error, User, Nid, Jugada} -> gen_tcp:send(Socket, term_to_binary({error, Cmdid, Nid, Jugada}));
                                                             {ok, User, Nid, Jugada} -> gen_tcp:send(Socket, term_to_binary({ok, Cmdid, Nid, Jugada}))
                                                         end,psocket(Socket, User);
                            {obs, Cmdid, Nid} -> pcomando({obs, User, Nid, self()}),
                                                 receive %Ni bien se suscribe enviarle el estado del tablero
                                                     {ok, User, Nid} -> gen_tcp:send(Socket, term_to_binary({ok, Cmdid, Nid}));
                                                     {error, User, Nid} -> gen_tcp:send(Socket, term_to_binary({ok, Cmdid, Nid}))
                                                 end,psocket(Socket, User);
                            {lea, Cmdid, Nid} -> pcomando({lea, User, Nid, self()}),
                                                 receive
                                                     {ok} -> ok;
                                                     {error} -> error
                                                 end,psocket(Socket, User);
                            {bye} -> pcomando({bye, User, self()});
                            _ -> enviarerror,
                                psocket(Socket, User)
                        end;
        {error, closed} -> %desregistrar nombre
                           %terminar juegos y dar victoria por abandono
                           %cerrar socket
                           gen_tcp:close(Socket);
        {error, timeout} -> receive
                                _ -> ok %este tambien llama a Pscoket
                            after ?TIMEOUT -> psocket(Socket,User)
                            end
    end.
%% ------------------ FIN ZONA PSOCKET -----------------------------%%


%% ------------------ ZONA PCOMANDO --------------------------------%%
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
        {ok, Id} -> usuarios ! {acc,User,Juegoid,self()},
                        receive
                            {ok,User,Juegoid} -> Psid ! {ok,Psid,Id}
                        end;
        {error,ocupado,Juegoid} -> Psid ! {error,User,Juegoid};
        {error,noExiste,Juegoid} -> Psid ! {error,User,Juegoid}
    end;

%% Esperar a implementar el juego para ver que onda
pcomando({pla, User, Juegoid, Jugada,Psid}) when (Jugada > 9) or (Jugada < 1) -> Psid ! {error, User, Juegoid,Jugada};
pcomando({pla, User, Juegoid, Jugada,Psid}) ->
    juegos ! {obtener,Juegoid,self()}, 
    receive
        {User,Visitante,Espectadores,JuegoTateti} -> JuegoTateti ! {self(),local,Jugada},
                                                     receive
                                                        {Tablero} ->  broadcasterTablero([Visitante] ++ Espectadores, {Tablero,Juegoid}), Psid ! {ok,User,Juegoid,Jugada,Tablero}     
                                                     end;
        {Local,User,Espectadores,JuegoTateti} -> JuegoTateti ! {self(),away,Jugada},
                                                 receive
                                                    {Tablero} ->  broadcasterTablero([Local] ++ Espectadores, Tablero), Psid ! {ok,User,Juegoid,Jugada,Tablero}     
                                                 end;
        _ -> Psid ! {error, User,Juegoid,Jugada}
    end;

pcomando({obs, User, Juegoid, Psid}) -> 
    juegos ! {obs,User,Juegoid,self()},
    receive
        {error,noExiste} -> Psid ! {error,Juegoid};
        {ok,observando} -> Psid ! {ok,Juegoid}
    end;

pcomando({lea, User, Juegoid,Psid}) -> 
        juegos ! {noObs,User,Juegoid,self()},
    receive
        {error,noExiste} -> Psid ! {error,Juegoid};
        {ok,noMiro} -> Psid ! {ok,Juegoid}
    end;

pcomando({bye,User,Psid}) -> 
    juegos ! {bye,User}
.
%% ------------------ FIN ZONA PCOMANDO ----------------------------%%


%% ------------------ ZONA MAPAS -----------------------------------%%
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
      {acc,User,Juegoid,Cartero} -> {Psid,JuegosActuales} = maps:find(User,MapaDeUsuarios), Mapa = maps:put (User, {Psid,[Juegoid] ++ JuegosActuales}), Cartero ! {ok,Juegoid}, usuarios(Mapa);
      {listaEliminar,User,Cartero} -> {_,JuegosActuales} = maps:find(User,MapaDeUsuarios), Cartero ! {juegosActuales,JuegosActuales}, Mapa = maps:remove(User,MapaDeUsuarios), usuarios(Mapa);
      {obtener,User,Cartero} -> Cartero ! {maps:find(User,MapaDeUsuarios)}, usuarios(MapaDeUsuarios);
      {bye,User} -> {_,JuegosActuales} = maps:find(User,MapaDeUsuarios), eliminarJugador(JuegosActuales,User),usuarios(MapaDeUsuarios);
      _ -> usuarios(MapaDeUsuarios)
    end.

%% MapaDeJuegos es un mapa que tiene como clave el numero de juego y como valor una tupla de {local,visitante,espectadores[],procesoDeJuego}
juegos(MapaDeJuegos, N) ->
    receive
      {nuevo, User,Cartero} ->
          Mapa = maps:put(N, {User, nadie, [],sinjuego}, MapaDeJuegos), %% El turno arranca en cero para ver que nadie esta jugando
          Cartero ! {ok, N},
          juegos(Mapa, N + 1);
      {lista, Cmdid} -> Cmdid ! {lista,MapaDeJuegos}, juegos(MapaDeJuegos,N+1);
      {acc,User,Juegoid,Cartero} -> 
          case maps:find(Juegoid,MapaDeJuegos) of
              {ok, {Local, nadie ,Espectadores,sinjuego}} -> 
                  Mapa = maps:put(Juegoid, {Local,User,Espectadores,spawn(?MODULE,tateti,[newtab,1,1])},MapaDeJuegos), %% Cuando alguien acepta amrcamos el primer turno
                  Cartero ! {ok, Juegoid},
                  juegos(Mapa, N);
              {ok, {_, _, _,_}} -> Cartero ! {error,ocupado,Juegoid}, juegos(MapaDeJuegos,N);
              error -> Cartero ! {error,noExiste,Juegoid}, juegos(MapaDeJuegos, N)
          end;
      {obtener,Juegoid,Cartero} -> Cartero ! {maps:find(Juegoid, MapaDeJuegos)}, juegos(MapaDeJuegos,N);
      {obs,User,Juegoid,Cartero} -> 
          case maps:find(Juegoid,MapaDeJuegos) of 
            error -> Cartero ! {error,noExiste},juegos(MapaDeJuegos,N) ;
            {Local,Visitante,Espectadores,JuegoTateti} -> Mapa = maps:put(Juegoid, {Local,Visitante, [User] ++ Espectadores, JuegoTateti}), Cartero ! {ok, observando},juegos(Mapa,N)    
          end;
      {noObs, User,Juegoid,Cartero} ->
          case maps:find(Juegoid,MapaDeJuegos) of
            error -> Cartero ! {error,noExiste},juegos(MapaDeJuegos,N);
            {Local,Visitante,Espectadores,JuegoTateti} -> Mapa = maps:put(Juegoid, {Local, Visitante, Espectadores -- [User],JuegoTateti}), Cartero ! {ok,noMiro},juegos(Mapa,N)
          end;
      {borrar,Juegoid,User} -> %% Implementa el borrado pedazo de pajero
      _ -> juegos(MapaDeJuegos,N)
    end.
%% ----------------- FIN ZONA MAPAS --------------------------------%%



%% ------------------ ZONA JUEGO -----------------------------------%%
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

%% Envía a todos los procesos de la lista un mensaje
broadcasterTablero([],_) -> ok;
broadcasterTablero([X|Xs],{Tablero,Juegoid}) -> 
    usuarios ! {obtener,X,self()},
    receive
        {Psid,_} -> Psid ! {upd, Tablero,Juegoid}
    end,
    broadcasterTablero(Xs,{Tablero,Juegoid}).

%% Dada una lista con id de juegos, busca en el mapa de juegos coincidencias y los reemplaza por un atomo 'abandono'
eliminarJugador([],_) -> ok;
eliminarJugador([X|Xs],User) ->
    juegos ! {borrar,X,User},
    receive
        {ok,borrado} -> eliminarJugador(Xs,User);
        {error,noBorrado} -> error
    end.

%% Esta creo que va en el cliente
imprimeTablero([]) -> ok;
imprimeTablero([A|B|C|XS]) -> 
    io:format("~p | ~p | ~p ~n",[A,B,C]),
    io:format("-------------~n"),
    imprimeTablero(XS).
%% ------------------ FIN ZONA JUEGO -------------------------------%%