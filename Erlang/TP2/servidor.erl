-module(servidor).
%% CHEQUEAR QUE SI ESTA JUGANDOO NO SE SUSCRIBA
-export([main/1,psocket/2,pcomando/1,usuarios/1,juegos/2]).
-export([tateti/4,pstat/0,pbalance/1,imprimeTablero/1]).

-define(Puerto, 8000).
-define(Intervalo, 1000).
-define(Newtab,[0,0,0,0,0,0,0,0,0]).

%% list_to_atom
%% JuegoId = N#Nodo

%%Conectar rapido: {ok,Socket} = gen_tcp:connect("localhost", 8000, [{packet, 0}, {active,false}]).
%%Usuario nuevo: gen_tcp:send(Socket, "CON Gurvich").
%%Recibir mensaje: {ok,Data} = gen_tcp:recv(Socket,0).

%% ------------------ ZONA DISPATCHER ------------------------------%%
%% Dispatcher esta siempre esperando conecciones -> les asigna psocket
main(master) ->
    case gen_tcp:listen(?Puerto, [{packet, 0}, {active, false}]) of
        {ok, LSocket} -> ok;
        {error,_} -> io:format("Puerto ocupado~n"),
                     {ok, LSocket} = gen_tcp:listen(0, [{packet, 0}, {active, false}])
    end,
    {_,Port} = inet:port(LSocket),
    io:format("Abierto en puerto ~p~n",[Port]),
    U = spawn(?MODULE, usuarios, [maps:new()]),
    register(usuarios, U),
    J = spawn(?MODULE, juegos, [maps:new(), 1]),
    register(juegos, J),
    B = spawn(?MODULE, pbalance, [maps:new()]),
    register(pbalance, B),
    spawn(?MODULE, pstat, []),
    escuchar(LSocket);
main(nodo) ->
    J = spawn(?MODULE, juegos, [nodo, 0]),
    register(juegos, J),
    spawn(?MODULE, pstat, []).


%% Escucha en el socket asignado los pedidos y crea un proceso que se encargue de manejarlo
escuchar(LSocket) ->
    {ok, Socket} = gen_tcp:accept(LSocket),
    io:format("Nuevo conectado ~p~n",[Socket]),
    %% TODO: Implementar una funcion que de el nodo de menor carga
    % spawn(nodoMenorCarga, ?MODULE, psocket, [Socket]),
    spawn(?MODULE, psocket, [Socket,noname]),
    escuchar(LSocket).
%% ------------------ FIN ZONA DISPATCHER --------------------------%%

%% ------------------ ZONA PSOCKET ---------------------------------%%
-define(TIMEOUT,1).
%% Va a recibir un mensaje y actuar de acorde a eso
psocket(Socket, noname) ->
    case gen_tcp:recv(Socket, 0) of
        {ok, Packet} -> [X|Xs] = string:lexemes(Packet, " "),
                        case X of
                            "CON" ->pbalance ! {best, self()},
                                    receive
                                        {best, N} -> spawn(N,?MODULE,pcomando,[{con, Xs, node(), self()}])
                                    end,
                                    receive
                                        {ok, Nuevonombre, DATA} ->
                                            gen_tcp:send(Socket, DATA),
                                            psocket(Socket, Nuevonombre); %llama a psocket con user
                                        {error, DATA} ->
                                            gen_tcp:send(Socket, DATA),
                                            psocket(Socket, noname) %se llama con noname y espera otro user
                                    end;
                            _ ->    gen_tcp:send(Socket, "ERROR noregistrado"),
                                    psocket(Socket, noname)
                        end;
        {error, closed} -> gen_tcp:close(Socket)
    end;

psocket(Socket, User) ->
    case gen_tcp:recv(Socket, 0,?TIMEOUT) of
        {ok, Packet} -> [X|Xs] = string:lexemes(Packet, " "),
                        io:format("~p~n",[Xs]),
                        pbalance ! {best, self()},
                        receive
                            {best, N} -> ok
                        end,
                        case X of
                           "CON" -> gen_tcp:send(Socket,"ERROR yaregistrado"),
                                    psocket(Socket,User);
                           "LSG" -> spawn(N,?MODULE,pcomando,[{lsg, Xs, self()}]),
                                    psocket(Socket,User);
                           "NEW" -> spawn(N,?MODULE,pcomando,[{new, Xs, User, self()}]),
                                    psocket(Socket, User);
                           "ACC" -> spawn(N,?MODULE,pcomando,[{acc, Xs, User, self()}]),
                                    psocket(Socket, User);
                           "PLA" -> spawn(N,?MODULE,pcomando,[{pla, Xs, User, self()}]),
                                    psocket(Socket, User);
                           "OBS" -> spawn(N,?MODULE,pcomando,[{obs, Xs, User, self()}]),
                                    psocket(Socket, User);
                           "LEA" -> spawn(N,?MODULE,pcomando,[{lea, Xs, User, self()}]),
                                    psocket(Socket, User);
                           "BYE" -> pcomando({bye, User}),
                                    gen_tcp:close(Socket);
                            _    -> case Xs of
                                        []  ->  gen_tcp:send(Socket, "ERROR wrongformat");
                                        _   ->  CMDID = lists:nth(1,Xs),   
                                                gen_tcp:send(Socket, lists:concat(["ERROR ",CMDID," wrongcommand"])),
                                                psocket(Socket, User)
                                    end
                        end;
        {error, closed} ->  pcomando({bye, User}),
                            gen_tcp:close(Socket);
        {error, timeout} -> receive
                                {ok, Data} ->   gen_tcp:send(Socket, Data),
                                                psocket(Socket,User);
                                {error, Data} ->    gen_tcp:send(Socket, Data),
                                                    psocket(Socket,User);
                                {update, Data} -> gen_tcp:send(Socket, Data),
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
    X = length([{juegos,Node} ! {listaPersonal,self()} || Node <- [node()|nodes()]]), %%Soy re tonto
    Y = pedirListaJuegos(X,[]),
    Z = parseoDeJuegos(Y),
    L = lists:concat(["OK ", CMDID, " ", Z]),
    Psid ! {ok, L};
pcomando({lsg, _, Psid}) -> Psid ! {error, "ERROR badargument"};

pcomando({new, [CMDID], User, Psid}) ->
    juegos ! {nuevo, self(),{User}},
    receive
        {ok,N} -> Psid ! {ok, lists:concat(["OK ",CMDID," ",N])}
    end;
pcomando({new, _, _, Psid}) -> Psid ! {error, "ERROR badargument"};

%% Hacer en todos y poner cuando no matchea
pcomando({acc, [CMDID, Juegoid], User, Psid}) ->
    juegos ! {acc,self(),{User,Juegoid}},
    receive
        ok -> usuarios ! {acc,User,Juegoid,self()}, 
                        receive
                            ok -> Psid ! {ok, lists:concat(["OK ",CMDID, " ", Juegoid])} %%Fijate de devolver el tablero
                        end;
        {error, ocupado}  -> Psid ! {error, lists:concat(["ERROR ",CMDID," ",Juegoid])};
        {error, noExiste} -> Psid ! {error, lists:concat(["ERROR ",CMDID," ",Juegoid])}
    end;
pcomando({acc, _, _, Psid}) -> Psid ! {error, "ERROR badargument"};

%% Esperar a implementar el juego para ver que onda
pcomando({pla, [CMDID, Juegoid, JugadaS], User, Psid}) ->
    Jugada = list_to_integer(JugadaS),
    if
        (Jugada > 9) or (Jugada < 1) -> Psid !{error, lists : concat([ "ERROR ", CMDID, " JUEGO ", Juegoid, " JUGADA ", Jugada ])};
        true ->     [_,NodoPcS] = string:lexemes(Juegoid,"#"),
                    NodoPc = list_to_atom(NodoPcS),
                    {juegos,NodoPc} ! {obtener, self(), {Juegoid}},
                    receive
                        {_,_,_,sinjuego} -> Psid ! {error,lists:concat(["ERROR ", CMDID, " ",Juegoid, " ", Jugada])};
                        {User,Visitante,Espectadores,JuegoTateti} -> JuegoTateti ! {self(),local,Jugada}, 
                                                                     receive
                                                                        error -> Psid ! {error,lists:concat(["ERROR ", CMDID, " ",Juegoid, " ", Jugada])};  
                                                                        {Cond,Tablero}  -> TableroN = lists:concat([integer_to_list(L) || L <- Tablero]),broadcasterTablero([Visitante | Espectadores], {Cond,Tablero,Juegoid}), Psid ! {ok,lists:concat(["OK ",CMDID, " ",Juegoid," ",Cond, " ",Jugada, " ",TableroN])}
                                                                     end;
                        {Local,User,Espectadores,JuegoTateti} ->    JuegoTateti ! {self(),away,Jugada},
                                                                    receive
                                                                        error -> Psid ! {error,lists:concat(["ERROR ", CMDID, " ",Juegoid, " ", Jugada])};
                                                                        {Cond,Tablero}  -> TableroN = lists:concat([integer_to_list(L) || L <- Tablero]),broadcasterTablero([Local | Espectadores], {Cond,Tablero,Juegoid}), Psid ! {ok,lists:concat(["OK ",CMDID, " ",Juegoid, " ",Jugada," ",TableroN])}     
                                                                    end;
                        _ ->Psid ! {error, lists:concat(["ERROR ",CMDID, " ",Juegoid, " ",Jugada])}
                    end
    end;
pcomando({pla, _, _, Psid}) -> Psid ! {error, "ERROR badargument"};

pcomando({obs, [CMDID, Juegoid], User, Psid}) -> %% Si no nos da paja, ver de agregar el juego a observar en la lista de usuarios
    [_,NodoPcS] = string:lexemes(Juegoid,"#"),
    NodoPc = list_to_atom(NodoPcS),
    {juegos,NodoPc} ! {obs, self(), {User, Juegoid}},
    receive
        error -> Psid ! {error,lists:concat(["ERROR ", CMDID, " ", Juegoid])};
        ok -> Psid ! {ok,lists:concat(["OK ", CMDID, " ", Juegoid])}
    end;
pcomando({obs, _, _, Psid}) -> Psid ! {error, "ERROR badargument"};

pcomando({lea, [CMDID, Juegoid], User, Psid}) ->
    [_,NodoPcS] = string:lexemes(Juegoid,"#"),
    NodoPc = list_to_atom(NodoPcS),
    {juegos,NodoPc} ! {noObs, self(), {User, Juegoid}},
    receive
        error -> Psid ! {error,lists:concat(["ERROR ", CMDID, " ", Juegoid])};
        ok -> Psid ! {ok,lists:concat(["OK ", CMDID, " ", Juegoid])}
    end;
pcomando({lea, _, _, Psid}) -> Psid ! {error, "ERROR badargument"};

pcomando({bye,User}) ->
    %% Avisar que perdió todo: Ahora!
    %% Desligar name: check
    %% Salir de observar:stand by me
    [_,NodoPcS] = string:lexemes(User,"#"),
    NodoPc = list_to_atom(NodoPcS),
    {usuarios,NodoPc} ! {obtener,User,self()},
    receive
        {_,Juegos} -> eliminarJugador(Juegos,User);
        error -> ok
    end,
    {usuarios,NodoPc} ! {bye,User}.

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
    [_,NodoPcS] = string:lexemes(X,"#"),
    NodoPc = list_to_atom(NodoPcS),
    {juegos,NodoPc} ! {borrar,self(),{X,User}},
    receive
        ok -> eliminarJugador(Xs,User);
        error -> eliminarJugador(Xs,User)
    end.
%% ------------------ FIN ZONA PCOMANDO ----------------------------%%

%% ------------------ ZONA MAPAS -----------------------------------%%
%MapaDeNombres es un mapa que tiene como clave el nombre de usuario y como valor una tupla {psocket,listaDeJuegos[]}
%Un User es nombre#nodo@pc 
usuarios(MapaDeUsuarios) ->
    receive
        {Cartero, nuevo, User, Psid} ->
            case maps:find(User,MapaDeUsuarios) of 
                error -> Mapa = maps:put(User, {Psid,[]}, MapaDeUsuarios),Cartero ! ok,usuarios(Mapa);
                _ -> Cartero ! error,usuarios(MapaDeUsuarios)
            end;
        {acc,User,Juegoid,Cartero} -> {ok,{Psid,JuegosActuales}} = maps:find(User,MapaDeUsuarios), Mapa = maps:put(User, {Psid,[Juegoid | JuegosActuales]},MapaDeUsuarios),Cartero ! ok, usuarios(Mapa);
        {obtener,User,Cartero} ->   case maps:find(User, MapaDeUsuarios) of
                                            {ok, Tupla} -> Cartero ! Tupla, usuarios(MapaDeUsuarios);
                                            error -> Cartero ! error, usuarios(MapaDeUsuarios)
                                    end;
        {bye, User} -> Mapa = maps:remove(User,MapaDeUsuarios), usuarios(Mapa);
        {borrarJuego,User,Juegoid} -> {ok,{Psid,JuegosActuales}} = maps:find(User,MapaDeUsuarios),
                                      Mapa = maps:put(User, {Psid, JuegosActuales -- [Juegoid]}, MapaDeUsuarios),
                                      usuarios(Mapa);
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
          Mapa = maps:put(Id, {User, nadie, [],sinjuego}, MapaDeJuegos), 
          Cartero ! {ok, N},
          juegos(Mapa, N + 1);
      {listaPersonal, Cmdid} -> Cmdid ! {listaPersonal,MapaDeJuegos}, juegos(MapaDeJuegos,N);
      {acc,Cartero,{User,Juegoid}} -> 
          case maps:find(Juegoid,MapaDeJuegos) of
              {ok, {Local, nadie ,Espectadores,sinjuego}} -> 
                  Mapa = maps:put(Juegoid, {Local,User,Espectadores,spawn(?MODULE,tateti,[?Newtab,0,1,Juegoid])},MapaDeJuegos), %% Cuando alguien acepta amrcamos el primer turno
                  Cartero ! ok,
                  juegos(Mapa, N);
              {ok, {_, _, _,_}} -> Cartero ! {error,ocupado}, juegos(MapaDeJuegos,N);
              error -> Cartero ! {error,noExiste}, juegos(MapaDeJuegos, N)
          end;
      {obtener,Cartero,{Juegoid}} -> case maps:find(Juegoid, MapaDeJuegos) of
                                        {ok,Juego} ->Cartero ! Juego, juegos(MapaDeJuegos,N);
                                        error -> Cartero ! error, juegos(MapaDeJuegos,N)
                                    end;
      {obs,Cartero,{User,Juegoid}} -> 
          case maps:find(Juegoid,MapaDeJuegos) of 
            error -> Cartero ! error,juegos(MapaDeJuegos,N) ;
            {ok,{Local,Visitante,Espectadores,JuegoTateti}} -> Mapa = maps:put(Juegoid, {Local,Visitante, [User] ++ Espectadores, JuegoTateti},MapaDeJuegos), Cartero ! ok,juegos(Mapa,N)    
          end;
      {noObs, Cartero,{User,Juegoid}} ->
          case maps:find(Juegoid,MapaDeJuegos) of
            error -> Cartero ! error,juegos(MapaDeJuegos,N);
            {ok,{Local,Visitante,Espectadores,JuegoTateti}} -> Mapa = maps:put(Juegoid, {Local, Visitante, Espectadores -- [User],JuegoTateti},MapaDeJuegos), Cartero ! ok,juegos(Mapa,N)
          end;
      {borrar,Cartero,{Juegoid,User}} -> 
          case maps:find(Juegoid,MapaDeJuegos) of 
            error -> Cartero ! error,juegos(MapaDeJuegos,N);
            {ok,{User,_,_,JuegoTateti}} -> JuegoTateti ! {self(),local,bye}, Cartero ! ok,Mapa = maps:remove(Juegoid,MapaDeJuegos),juegos(Mapa,N);
            {ok,{_,User,_,JuegoTateti}} -> JuegoTateti ! {self(),away,bye}, Cartero ! ok,Mapa = maps:remove(Juegoid,MapaDeJuegos),juegos(Mapa,N)    
          end;
      {borrarJuego,_,{Juegoid}} -> Mapa = maps:remove(Juegoid,MapaDeJuegos),juegos(Mapa,N);
      _ -> juegos(MapaDeJuegos,N)
    end.
%% ----------------- FIN ZONA MAPAS --------------------------------%%



%% ------------------ ZONA JUEGO -----------------------------------%%
checkGanador([A1,A2,A3,B1,B2,B3,C1,C2,C3]) ->
    %% filas
    F1 = A1 + A2 +A3, F2 = B1 + B2 + B3, F3 = C1 + C2 + C3,
    %% columnas
    Col1 = A1 + B1 + C1, Col2 = A2 + B2 + C2, Col3 = A3 + B3 + C3,
    %% diagonales
    Diag1 = A1 + B2 + C3, Diag2 = C1 + B2 + A3,
    %% Hardcoded because why not, termina siendo O(1)
    Max = lists:max([F1,F2,F3,Col1,Col2,Col3,Diag1,Diag2]),
    Min = lists:min([F1,F2,F3,Col1,Col2,Col3,Diag1,Diag2]),
    if 
        %% Gano J1
        Max == 3 -> w1; 
        %% Gano J2
        Min == -3 -> w2;
        %% Nadie
        true -> nada    
    end.
%% Me doy asco
jugada([X|Xs],N,Turno) -> 
    if
        N == 1 ->  if
                        X == 0 -> {ok,[Turno | Xs]};
                        true   -> error
                   end;
        N > 1 -> case jugada(Xs,N-1,Turno) of
                    {ok, TableroN} -> {ok, [X | TableroN]};
                    error -> error
                 end
    end.

%% Turno vale 1 o -1
%% Pueden jugar local o away, 1 es local y -1 es away. Se identifican en el MapaDeJuegos
%% Salame chequea que sea tu turno
tateti(Tablero, Plays,Turno,Juegoid) ->
    imprimeTablero(Tablero),
    receive
        {Cartero,local,bye} -> {Jugada,Jugador} = {abandon,w2};
        {Cartero,away, bye} -> {Jugada,Jugador} = {abandon,w1};
        {Cartero,local ,Pos} -> {Jugada,Jugador} = {Pos,local};
        {Cartero,away  ,Pos} -> {Jugada,Jugador} = {Pos,away}
    end,
    if 
        Jugada == abandon -> Cartero ! {Jugador,Tablero}, funcionMataJuego(Juegoid);
        (Jugador == local) and (Turno == -1) -> Cartero ! error, tateti(Tablero, Plays, Turno,Juegoid);
        (Jugador == away) and (Turno == 1)   -> Cartero ! error, tateti(Tablero, Plays, Turno,Juegoid);
        true -> case jugada(Tablero,Jugada,Turno) of
                        {ok, TableroN} -> 
                            K = Plays + 1,
                            case checkGanador(TableroN) of
                                w1 -> Cartero ! {w1,TableroN}, funcionMataJuego(Juegoid);
                                w2 -> Cartero ! {w2,TableroN}, funcionMataJuego(Juegoid);
                                nada -> if
                                            K == 9 -> Cartero ! {empate,TableroN}, funcionMataJuego(Juegoid);
                                            true -> Cartero ! {tablero,TableroN},tateti(TableroN,K,-Turno,Juegoid)
                                        end
                            end;
                        error -> Cartero ! error, tateti(Tablero, Plays, Turno, Juegoid)
                end
    end.
funcionMataJuego(Juegoid) ->
    juegos ! {obtener, self(),{Juegoid}},
    receive
        {Local, Visitante, _, _} -> usuarios ! {borrarJuego,Local,Juegoid}, usuarios ! {borrarJuego,Visitante, Juegoid};
        error -> ok
    end,
    juegos ! {borrarJuego, self(), {Juegoid}}.
%% Envía a todos los procesos de la lista un mensaje
broadcasterTablero([],_) -> ok;
%% Es una lista de jugadores
broadcasterTablero([X|Xs],{Cond,Tablero,Juegoid}) -> 
    [_,NodoPcS] = string:lexemes(X,"#"),
    NodoPc = list_to_atom(NodoPcS),
    {usuarios,NodoPc} ! {obtener,X,self()},
    receive
        {Psid,_} -> {_,{H,M,S}} = erlang:localtime(), TableroN = lists:concat([integer_to_list(L) || L <- Tablero]),Cmdid = lists:concat([H,":",M,":",S]),Psid ! {update, lists:concat(["UPD ",Cmdid," ",Juegoid," ",Cond,"/",TableroN])};
        error -> ok
    end,
    broadcasterTablero(Xs,{Cond,Tablero,Juegoid}).

imprimeTablero([A1,A2,A3,B1,B2,B3,C1,C2,C3]) ->
    io:format("~p | ~p | ~p ~n",[A1,A2,A3]),
    io:format("---------~n"),
    io:format("~p | ~p | ~p ~n",[B1,B2,B3]),
    io:format("---------~n"),
    io:format("~p | ~p | ~p ~n",[C1,C2,C3]).
%% ------------------ FIN ZONA JUEGO -------------------------------%%

%% ------------------ ZONA PSTAT -----------------------------------%%
pstat() ->
    X = erlang:statistics(run_queue),
    [{pbalance, Node} ! {stat, node(), X} || Node <- [node()|nodes()]], 
    timer:sleep(?Intervalo),
    pstat().

pbalance(MapaNodos) ->
    receive
        {stat, Nodo, Val} -> NMap = maps:put(Nodo, Val, MapaNodos),
                             pbalance(NMap);
        {best, PId} -> LNodos = maps:to_list(MapaNodos),
                       Invert = [{B,A} || {A,B} <- LNodos],
                       {_,Node} = lists:min(Invert),
                       PId ! {best, Node},
                       pbalance(MapaNodos)
    end.
%% ------------------ FIN ZONA PSTAT -------------------------------%%