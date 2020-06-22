-module(servidor).

-compile(export_all).

-define(Puerto, 8000).

%% list_to_atom
%% JuegoId = N#Nodo

%% ------------------ ZONA DISPATCHER ------------------------------%%
%% Dispatcher esta siempre esperando conecciones -> les asigna psocket
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
                            "CON" ->pcomando({con, Xs, node(), self()}),
                                    receive
                                        {ok, Nuevonombre, DATA} ->
                                            gen_tcp:sendv(Socket, DATA),
                                            psocket(Socket, Nuevonombre); %llama a psocket con user
                                        {error, DATA} ->
                                            gen_tcp:sendv(Socket, DATA),
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
                           "LSG" -> pcomando({lsg, Xs, self()}),
                                    psocket(Socket,User);
                           "NEW" -> pcomando({new, Xs, User, self()}),
                                    psocket(Socket, User);
                           "ACC" -> pcomando({acc, Xs, User, self()}),
                                    psocket(Socket, User);
                           "PLA" -> pcomando({pla, Xs, User, self()}),
                                    psocket(Socket, User);
                           "OBS" -> pcomando({obs, Xs, User, self()}),
                                    psocket(Socket, User);
                           "LEA" -> pcomando({lea, Xs, User, self()}),
                                    psocket(Socket, User);
                           "BYE" -> pcomando({bye, User}),
                                    gen_tcp:close(Socket);
                            _    -> if
                                        Xs == [] -> gen_tcp:send(Socket, "ERROR wrongformat");
                                        true     -> CMDID = lists:nth(1,Xs),   
                                                    gen_tcp:send(Socket, lists:concat("ERROR ",CMDID," wrongcommand")),
                                                    psocket(Socket, User)
                                    end
                        end;
        {error, closed} ->  pcomando({bye, User, self()}),
                            %Es lo mismo que BYE
                            gen_tcp:close(Socket);
        {error, timeout} -> receive
                                {ok, Data} ->   gen_tcp:send(Socket, Data),
                                                psocket(Socket,User);
                                {error, Data} ->    gen_tcp:send(Socket, Data),
                                                    psocket(Socket,User);
                                _ -> ok
                            after ?TIMEOUT -> psocket(Socket,User)
                            end;
        _ -> psocket(Socket, User)
    end.
%% ------------------ FIN ZONA PSOCKET -----------------------------%%

%% ------------------ ZONA PCOMANDO --------------------------------%%
pcomando({con, [User], Nodo, Psid}) ->
    Nombre = lists:concat([User,'#',Nodo]),
    usuarios ! {self(), nuevo, Nombre, Psid},
    receive
      ok -> Psid ! {ok, Nombre, "OK " ++ User};
      error -> Psid ! {error, "ERROR " ++ User}
    end;
pcomando({con, _, _, Psid}) -> Psid ! {error, "ERROR badargument"};

pcomando({lsg, [CMDID], Psid}) ->
    X = length([{juegos,Node} ! {listaCompleta,self()} || Node <- nodes()]),
    Y = pedirListaJuegos(X,[]),
    Z = parseoDeJuegos(Y),
    Psid ! {ok, lists:concat("OK ", CMDID, " ", Z)};
pcomando({lsg, _, Psid}) -> Psid ! {error, "ERROR badargument"};

pcomando({new, [CMDID], User, Psid}) ->
    juegos ! {nuevo, self(),{User}},
    receive
        {ok,N} -> Psid ! {ok, lists:concat("OK ",CMDID," ",N)}
    end;
pcomando({new, _, _, Psid}) -> Psid ! {error, "ERROR badargument"};

%% Hacer en todos y poner cuando no matchea
pcomando({acc, [CMDID, Juegoid], User, Psid}) ->
    juegos ! {acc,self(),{User,Juegoid}},
    receive
        ok -> usuarios ! {acc,User,Juegoid,self()},
                        receive
                            ok -> Psid ! {ok, lists:concat("OK ",CMDID, " ", Juegoid)} %%Fijate de devolver el tablero
                        end;
        {error, ocupado}  -> Psid ! {error, lists:concat("ERROR ",CMDID," ",Juegoid)};
        {error, noExiste} -> Psid ! {error, lists:concat("ERROR ",CMDID," ",Juegoid)}
    end;
pcomando({acc, _, _, Psid}) -> Psid ! {error, "ERROR badargument"};

%% Esperar a implementar el juego para ver que onda
pcomando({pla, [CMDID, Juegoid, Jugada], _, Psid}) when (Jugada > 9) or (Jugada < 1) -> Psid ! {error, lists:concat("ERROR ",CMDID," JUEGO ",Juegoid, " JUGADA ",Jugada)};
pcomando({pla, [CMDID, Juegoid, Jugada], User, Psid}) ->
    [Id,NodoPc] = string:lexemes(Juegoid,"#"),
    {juegos,NodoPc} ! {obtener, self(), {Id}},
    receive
        {User,Visitante,Espectadores,JuegoTateti} -> JuegoTateti ! {self(),local,Jugada}, %%Si pudo jugar re piola, recibe un ok y el tablero, sino recibe un error. IMPLEMENTAR CUANDO HAGAMOS BIEN EL JUEGO
                                                     receive
                                                        {ok,Tablero} ->  broadcasterTablero([Visitante] ++ Espectadores, {Tablero,Juegoid}), Psid ! {ok,lists:concat("OK ",CMDID, " ",Juegoid, " ",Jugada)}     
                                                     end;
        {Local,User,Espectadores,JuegoTateti} -> JuegoTateti ! {self(),away,Jugada},
                                                 receive
                                                    {ok,Tablero} ->  broadcasterTablero([Local] ++ Espectadores, Tablero), Psid ! {ok,lists:concat("OK ",CMDID, " ",Juegoid, " ",Jugada)}     
                                                 end;
        _ -> Psid ! {error, User,Juegoid,Jugada}
    end;
pcomando({pla, _, _, Psid}) -> Psid ! {error, "ERROR badargument"};

pcomando({obs, [CMDID, Juegoid], User, Psid}) -> %% Si no nos da paja, ver de agregar el juego a observar en la lista de usuarios
    [Id,NodoPc] = string:lexemes(Juegoid,"#"),
    {juegos,NodoPc} ! {obs, self(), {User, Id}},
    receive
        error -> Psid ! {error,lists:concat("ERROR ", CMDID, " ", Juegoid)};
        ok -> Psid ! {ok,lists:concat("OK ", CMDID, " ", Juegoid)}
    end;
pcomando({obs, _, _, Psid}) -> Psid ! {error, "ERROR badargument"};

pcomando({lea, [CMDID, Juegoid], User, Psid}) ->
    [Id,NodoPc] = string:lexemes(Juegoid,"#"),
    {juegos,NodoPc} ! {noObs, self(), {User, Id}},
    receive
        error -> Psid ! {error,lists:concat("ERROR ", CMDID, " ", Juegoid)};
        ok -> Psid ! {ok,lists:concat("OK ", CMDID, " ", Juegoid)}
    end;
pcomando({lea, _, _, Psid}) -> Psid ! {error, "ERROR badargument"};

pcomando({bye,User}) ->
    %% Avisar que perdió todo
    %% Desligar name
    %% Salir de observar
    juegos ! {bye,self(),{User}}.

%%Auxiliares  de lsg
pedirListaJuegos(0,M) -> M;
pedirListaJuegos(N,M) ->
    receive
        empty -> pedirListaJuegos(N-1,M);
        {listaPersonal,Mapa} -> pedirListaJuegos(N-1,[Mapa|M])
    end.
comaAlfinal([]) -> [];
comaAlfinal([X]) -> [X];
comaAlfinal([X|Xs]) -> [(X ++ ",")|comaAlfinal(Xs)].
parseoDeJuegos(Lista) ->
    ListaDeListas = [maps:to_list(X) || X <- Lista],
    Unidos = lists:concat(ListaDeListas),
    Stringueado = [lists:concat([A,"/",B,"/",C]) || {A,{B,C,_,_}} <- Unidos],
    lists:concat(comaAlfinal(Stringueado)).

%% Dada una lista con id de juegos, busca en el mapa de juegos coincidencias y los reemplaza por un atomo 'abandono'
eliminarJugador([],_) -> ok;
eliminarJugador([X|Xs],User) ->
    [Id,NodoPc] = string:lexemes(X,"#"),
    {juegos,NodoPc} ! {borrar,self(),{Id,User}},
    receive
        ok -> eliminarJugador(Xs,User);
        error -> error
    end.
%% ------------------ FIN ZONA PCOMANDO ----------------------------%%


%% ------------------ ZONA MAPAS -----------------------------------%%
%MapaDeNombres es un mapa que tiene como clave el nombre de usuario y como valor una tupla {psocket,listaDeJuegos[]}
%Un User es nombre#nodo@pc 
usuarios(MapaDeUsuarios) ->
    receive
      {Cartero, nuevo, User, Psid} ->
          case maps:find(User,MapaDeUsuarios) of 
            error -> Mapa = maps:put(User, {Psid,[]}, MapaDeUsuarios),
                     Cartero ! ok,
                     usuarios(Mapa);
            _ -> Cartero ! error,usuarios(MapaDeUsuarios)
          end;
      {acc,User,Juegoid,Cartero} -> {Psid,JuegosActuales} = maps:find(User,MapaDeUsuarios), Mapa = maps:put (User, {Psid,[Juegoid] ++ JuegosActuales}), Cartero ! {ok,Juegoid}, usuarios(Mapa);
      {listaEliminar,User,Cartero} -> {_,JuegosActuales} = maps:find(User,MapaDeUsuarios), Cartero ! {juegosActuales,JuegosActuales}, Mapa = maps:remove(User,MapaDeUsuarios), usuarios(Mapa);
      {obtener,User,Cartero} -> Cartero ! {maps:find(User,MapaDeUsuarios)}, usuarios(MapaDeUsuarios);
      {bye,User} -> {_,JuegosActuales} = maps:find(User,MapaDeUsuarios), eliminarJugador(JuegosActuales,User),usuarios(MapaDeUsuarios);
      _ -> usuarios(MapaDeUsuarios)
    end.

%% MapaDeJuegos es un mapa que tiene como clave Id#nodo@pc y como valor una tupla de {local,visitante,espectadores[],procesoDeJuego}
%% ID: N#Nodo@PC, Local, Visitante, Suscritos, ProcesoDeJuego
juegos(nodo,_) -> %%Versión que no hace nada
    receive
        {_, Cartero, _} -> Cartero ! empty
    end,
    juegos(nodo,0);
juegos(MapaDeJuegos, N) ->
    receive
      {nuevo,Cartero,{User}} ->
          Id = lists:concat([N,"#",atom_to_list(node())]),
          Mapa = maps:put(Id, {User, nadie, [],sinjuego}, MapaDeJuegos), %% El turno arranca en cero para ver que nadie esta jugando
          Cartero ! {ok, N},
          juegos(Mapa, N + 1);
      {listaPersonal, Cmdid} -> Cmdid ! {listaPersonal,MapaDeJuegos}, juegos(MapaDeJuegos,N+1);
      {acc,Cartero,{User,Juegoid}} -> 
          case maps:find(Juegoid,MapaDeJuegos) of
              {ok, {Local, nadie ,Espectadores,sinjuego}} -> 
                  Mapa = maps:put(Juegoid, {Local,User,Espectadores,spawn(?MODULE,tateti,[newtab,1,1])},MapaDeJuegos), %% Cuando alguien acepta amrcamos el primer turno
                  Cartero ! {ok},
                  juegos(Mapa, N);
              {ok, {_, _, _,_}} -> Cartero ! {error,ocupado}, juegos(MapaDeJuegos,N);
              error -> Cartero ! {error,noExiste}, juegos(MapaDeJuegos, N)
          end;
      {obtener,Cartero,{Juegoid}} -> Cartero ! {maps:find(Juegoid, MapaDeJuegos)}, juegos(MapaDeJuegos,N);
      {obs,Cartero,{User,Juegoid}} -> 
          case maps:find(Juegoid,MapaDeJuegos) of 
            error -> Cartero ! error,juegos(MapaDeJuegos,N) ;
            {Local,Visitante,Espectadores,JuegoTateti} -> Mapa = maps:put(Juegoid, {Local,Visitante, [User] ++ Espectadores, JuegoTateti}), Cartero ! ok,juegos(Mapa,N)    
          end;
      {noObs, Cartero,{User,Juegoid}} ->
          case maps:find(Juegoid,MapaDeJuegos) of
            error -> Cartero ! {error,noExiste},juegos(MapaDeJuegos,N);
            {Local,Visitante,Espectadores,JuegoTateti} -> Mapa = maps:put(Juegoid, {Local, Visitante, Espectadores -- [User],JuegoTateti}), Cartero ! {ok,noMiro},juegos(Mapa,N)
          end;
      {borrar,Cartero,{Juegoid,User}} -> 
          case maps:find(Juegoid,MapaDeJuegos) of 
            error -> Cartero ! error,juegos(MapaDeJuegos,N) ;
            {User,Visitante,Espectadores,JuegoTateti} -> Mapa = maps:put(Juegoid, {abandono,Visitante, Espectadores, JuegoTateti}), Cartero ! ok,juegos(Mapa,N);
            {Local,User,Espectadores,JuegoTateti} -> Mapa = maps:put(Juegoid, {Local,abandono, Espectadores, JuegoTateti}), Cartero ! ok,juegos(Mapa,N)    
          end;
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
    K = Plays + 1,
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

%% Esta creo que va en el cliente
imprimeTablero([]) -> ok;
imprimeTablero([A|B|C|XS]) -> 
    io:format("~p | ~p | ~p ~n",[A,B,C]),
    io:format("-------------~n"),
    imprimeTablero(XS).
%% ------------------ FIN ZONA JUEGO -------------------------------%%