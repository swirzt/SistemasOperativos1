-module(servidor).

-export([dispatcher/1, psocket/2, pcomando/1, usuarios/1, juegos/2]).
-export([pstat/0, pbalance/1, tateti/4]).

-include("tateti.hrl").

-define(Puerto, 8000).
-define(Intervalo, 5000).

%% ------------------ ZONA DISPATCHER ------------------------------%%
%% Inicia un nodo como servidor, con los procesos correspondientes
dispatcher(servidor) ->
    case gen_tcp:listen(?Puerto, [{packet, 0}, {active, false}]) of
      {ok, LSocket} ->
          ok;
      {error, _} ->
          io:format("Puerto ocupado~n"),
          {ok, LSocket} = gen_tcp:listen(0, [{packet, 0}, {active, false}])
    end,
    {_, Port} = inet:port(LSocket),
    io:format("Abierto en puerto ~p~n", [Port]),
    U = spawn(?MODULE, usuarios, [maps:new()]),
    register(usuarios, U),
    J = spawn(?MODULE, juegos, [maps:new(), 1]),
    register(juegos, J),
    B = spawn(?MODULE, pbalance, [maps:new()]),
    register(pbalance, B),
    spawn(?MODULE, pstat, []),
    escuchar(LSocket);
%% Inicia un nodo como trabajador
dispatcher(trabajador) ->
    J = spawn(?MODULE, juegos, [nodo, 0]),
    register(juegos, J),
    spawn(?MODULE, pstat, []).

%% Escucha en el socket asignado los pedidos y crea un proceso psocket que se encargue de manejarlo
escuchar(LSocket) ->
    {ok, Socket} = gen_tcp:accept(LSocket),
    io:format("Nuevo conectado ~p~n", [Socket]),
    spawn(?MODULE, psocket, [Socket, noname]),
    escuchar(LSocket).%% ------------------ FIN ZONA DISPATCHER --------------------------%%

%% ------------------ ZONA PSOCKET ---------------------------------%%
-define(TIMEOUT, 1).

%% Va a recibir un mensaje y actuar de acorde a eso
%% Esta versión solamente puede recibir un comando de nuevo usuario o de salida
psocket(Socket, noname) ->
    case gen_tcp:recv(Socket, 0) of
      {ok, Packet} ->
          [X | Xs] = string:lexemes(Packet, " "),
          case X of
            "CON" ->
                pbalance ! {best, self()},
                receive
                  {best, N} ->
                      spawn(N, ?MODULE, pcomando, [{con, Xs, node(), self()}])
                end,
                receive
                  {ok, Nuevonombre, DATA} ->
                      gen_tcp:send(Socket, DATA),
                      io:format("Cliente en ~p, se registrÃ³ como ~p~n", [Socket, Nuevonombre]),
                      psocket(Socket, Nuevonombre); %llama a psocket con user
                  {error, DATA} ->
                      gen_tcp:send(Socket, DATA),
                      psocket(Socket, noname) %se llama con noname y espera otro user
                end;
            "BYE" ->
                gen_tcp:close(Socket),
                io:format("Se desconectÃ³ en ~p", [Socket]);
            _ ->
                gen_tcp:send(Socket, "ERROR unregistered"),
                psocket(Socket, noname)
          end;
      {error, closed} ->
          gen_tcp:close(Socket)
    end;
%% Esta versión acepta todos los comandos
psocket(Socket, User) ->
    case gen_tcp:recv(Socket, 0, ?TIMEOUT) of
      {ok, Packet} ->
          [X | Xs] = string:lexemes(Packet, " "),
          pbalance ! {best, self()},
          receive
            {best, N} ->
                ok
          end,
          case X of
            "CON" ->
                gen_tcp:send(Socket, lists:concat(["ERROR ", User, " alreadyReg"])),
                psocket(Socket, User);
            "LSG" ->
                spawn(N, ?MODULE, pcomando, [{lsg, Xs, self()}]),
                psocket(Socket, User);
            "NEW" ->
                spawn(N, ?MODULE, pcomando, [{new, Xs, User, self()}]),
                psocket(Socket, User);
            "ACC" ->
                spawn(N, ?MODULE, pcomando, [{acc, Xs, User, self()}]),
                psocket(Socket, User);
            "PLA" ->
                spawn(N, ?MODULE, pcomando, [{pla, Xs, User, self()}]),
                psocket(Socket, User);
            "OBS" ->
                spawn(N, ?MODULE, pcomando, [{obs, Xs, User, self()}]),
                psocket(Socket, User);
            "LEA" ->
                spawn(N, ?MODULE, pcomando, [{lea, Xs, User, self()}]),
                psocket(Socket, User);
            "BYE" ->
                pcomando({bye, User}),
                gen_tcp:close(Socket),
                io:format("~p -> se desconectÃ³ en ~p~n", [User, Socket]);
            "OK" ->
                psocket(Socket, User);
            "ERROR" ->
                psocket(Socket, User);
            _ ->
                case Xs of
                  [] ->
                      gen_tcp:send(Socket, lists:concat(["ERROR ", X, " badformat"])),
                      psocket(Socket, User);
                  _ ->
                      CMDID = lists:nth(1, Xs),
                      gen_tcp:send(Socket, lists:concat(["ERROR ", CMDID, " wrongcmd ", X])),
                      psocket(Socket, User)
                end
          end;
      {error, closed} ->
          pcomando({bye, User}),
          gen_tcp:close(Socket),
          io:format("~p -> se desconectÃ³ en ~p~n", [User, Socket]);
      {error, timeout} ->
          receive
            {update, Data} ->
                gen_tcp:send(Socket, Data),
                psocket(Socket, User);
            {_, Data} ->
                gen_tcp:send(Socket, Data),
                psocket(Socket, User);
            _ ->
                ok
            after ?TIMEOUT ->
                      psocket(Socket, User)
          end;
      _ ->
          psocket(Socket, User)
    end.

%% ------------------ FIN ZONA PSOCKET -----------------------------%%

%% ------------------ ZONA PCOMANDO --------------------------------%%
%% Los distintos tipos de pcomando
pcomando({con, [User], Nodo, Psid}) ->
    %% No #, no @, No /, No " ", No ","
    Tiene = multiIn([32, $#, $@, $/, $,], User), %% 32 es el ASCII de " "
    if Tiene ->
           Psid ! {error, lists:concat(["ERROR invalidchar ", User])};
       true ->
           Nombre = lists:concat([User, '#', Nodo]),
           {usuarios, Nodo} ! {self(), nuevo, Nombre, Psid},
           receive
             ok ->
                 Psid ! {ok, Nombre, "OK " ++ User};
             error ->
                 Psid ! {error, lists:concat(["ERROR usedname ", User])}
           end
    end;
pcomando({con, _, _, Psid}) ->
    Psid ! {error, "ERROR badarg"};
pcomando({lsg, [CMDID], Psid}) ->
    X = length([{juegos, Node} ! {listaPersonal, self()} || Node <- [node() | nodes()]]),
    Y = pedirListaJuegos(X, []),
    Z = parseoDeJuegos(Y),
    L = lists:concat(["OK ", CMDID, " list ", Z]),
    Psid ! {ok, L};
pcomando({lsg, _, Psid}) ->
    Psid ! {error, lists:concat(["ERROR ", lsg, " badarg"])};
pcomando({new, [CMDID], User, Psid}) ->
    {ok, Nodo} =
        obtieneNodo(User), %% No provoca badmatch porque User siempre es creado correctamente
    {juegos, Nodo} ! {nuevo, self(), {User}},
    receive
      {ok, J} ->
          {usuarios, Nodo} ! {acc, User, J, self()},
          Psid ! {ok, lists:concat(["OK ", CMDID, " game ", J])};
      error ->
          Psid ! {error, lists:concat(["ERROR ", CMDID, " unknown"])}
    end;
pcomando({new, _, _, Psid}) ->
    Psid ! {error, lists:concat(["ERROR ", new, " badarg"])};
pcomando({acc, [CMDID, Juegoid], User, Psid}) ->
    case obtieneNodo(Juegoid) of
      {ok, NodoPc} ->
          {juegos, NodoPc} ! {acc, self(), {User, Juegoid}},
          receive
            {ok, Local} ->
                {ok, NodoPc} = obtieneNodo(User),
                {usuarios, NodoPc} ! {acc, User, Juegoid, self()},
                receive
                  ok ->
                      Psid ! {ok, lists:concat(["OK ", CMDID, " acc ", Juegoid])},
                      {ok, Nodito} = obtieneNodo(Local),
                      {usuarios, Nodito} ! {obtener, Local, self()},
                      receive
                        {IdSock, _} ->
                            IdSock ! {ok, lists:concat(["UPD ", CMDID, " accept ", Juegoid])}
                      end;
                  error ->
                      Psid ! {error, lists:concat(["ERROR ", CMDID, " badarg ", Juegoid])}
                end;
            {error, ocupado} ->
                Psid ! {error, lists:concat(["ERROR ", CMDID, " occupied ", Juegoid])};
            _ ->
                Psid ! {error, lists:concat(["ERROR ", CMDID, " noExist ", Juegoid])}
          end;
      {error, Reason} ->
          Psid ! {error, lists:concat(["ERROR ", CMDID, " ", Reason])}
    end;
pcomando({acc, _, _, Psid}) ->
    Psid ! {error, lists:concat(["ERROR ", acc, " badarg"])};
pcomando({pla, [CMDID, Juegoid, [JugadaS]], User, Psid}) ->
    if ((JugadaS > $9) or (JugadaS < $1)) and JugadaS /= $0 ->
           Psid ! {error, lists:concat(["ERROR ", CMDID, " invalid ", Juegoid, " ", JugadaS])};
       true ->
           Jugada = list_to_integer([JugadaS]),
           case obtieneNodo(Juegoid) of
             {ok, Nodo} ->
                 {juegos, Nodo} ! {obtener, self(), {Juegoid}},
                 receive
                   {User, _, _, sinjuego} ->
                       case Jugada of
                         0 ->
                             funcionMataJuego(Juegoid),
                             Psid ! {ok, lists:concat(["OK ", CMDID, " ", Juegoid, " ", Jugada])};
                         _ ->
                             Psid !
                               {error,
                                lists:concat(["ERROR ",
                                              CMDID,
                                              " noStarted ",
                                              Juegoid,
                                              " ",
                                              Jugada])}
                       end;
                   {User, Visitante, Espectadores, JuegoTateti} ->
                       JuegoTateti ! {self(), local, Jugada},
                       receive
                         error ->
                             Psid !
                               {error,
                                lists:concat(["ERROR ", CMDID, " badTurn ", Juegoid, " ", Jugada])};
                         {Cond, Tablero} ->
                             TableroN = lists:concat([integer_to_list(L) ++ "," || L <- Tablero]),
                             broadcaster([Visitante | Espectadores], {Cond, Tablero, Juegoid}, 1),
                             Psid !
                               {ok,
                                lists:concat(["OK ",
                                              CMDID,
                                              " tablero ",
                                              Juegoid,
                                              " ",
                                              Cond,
                                              " ",
                                              Jugada,
                                              " ",
                                              TableroN])}
                       end;
                   {Local, User, Espectadores, JuegoTateti} ->
                       JuegoTateti ! {self(), away, Jugada},
                       receive
                         error ->
                             Psid !
                               {error,
                                lists:concat(["ERROR ", CMDID, " badTurn ", Juegoid, " ", Jugada])};
                         {Cond, Tablero} ->
                             TableroN = lists:concat([integer_to_list(L) ++ "," || L <- Tablero]),
                             broadcaster([Local | Espectadores], {Cond, Tablero, Juegoid}, 1),
                             Psid !
                               {ok,
                                lists:concat(["OK ",
                                              CMDID,
                                              " tablero ",
                                              Juegoid,
                                              " ",
                                              Cond,
                                              " ",
                                              Jugada,
                                              " ",
                                              TableroN])}
                       end;
                   {_, nadie, _, _} ->
                       Psid !
                         {error,
                          lists:concat(["ERROR ", CMDID, " noOpponent ", Juegoid, " ", Jugada])};
                   empty ->
                       Psid !
                         {error,
                          lists:concat(["ERROR ", CMDID, " noExist ", Juegoid, " ", Jugada])};
                   _ ->
                       Psid !
                         {error, lists:concat(["ERROR ", CMDID, " unknown ", Juegoid, " ", Jugada])}
                 end;
             {error, Reason} ->
                 Psid ! {error, lists:concat(["ERROR ", CMDID, " ", Reason])}
           end
    end;
pcomando({pla, [CMDID, Juegoid, Pla], _, Psid}) ->
    Psid ! {error, lists:concat(["ERROR ", CMDID, " invalid ", Juegoid, " ", Pla])};
pcomando({pla, _, _, Psid}) ->
    Psid ! {error, lists:concat(["ERROR ", pla, " badarg"])};
pcomando({obs, [CMDID, Juegoid], User, Psid}) ->
    case obtieneNodo(Juegoid) of
      {ok, Nodo} ->
          {juegos, Nodo} ! {obs, self(), {User, Juegoid}},
          receive
            error ->
                Psid ! {error, lists:concat(["ERROR ", CMDID, " noExist ", Juegoid])};
            ok ->
                Psid ! {ok, lists:concat(["OK ", CMDID, " obs ", Juegoid])}
          end;
      {error, Reason} ->
          Psid ! {error, lists:concat(["ERROR ", CMDID, " ", Reason])}
    end;
pcomando({obs, _, _, Psid}) ->
    Psid ! {error, lists:concat(["ERROR ", obs, " badarg"])};
pcomando({lea, [CMDID, Juegoid], User, Psid}) ->
    case obtieneNodo(Juegoid) of
      {ok, Nodo} ->
          {juegos, Nodo} ! {noObs, self(), {User, Juegoid}},
          receive
            error ->
                Psid ! {error, lists:concat(["ERROR ", CMDID, " noExist ", Juegoid])};
            ok ->
                Psid ! {ok, lists:concat(["OK ", CMDID, " lea ", Juegoid])}
          end;
      {error, Reason} ->
          Psid ! {error, lists:concat(["ERROR ", CMDID, " ", Reason])}
    end;
pcomando({lea, _, _, Psid}) ->
    Psid ! {error, lists:concat(["ERROR ", lea, " badarg"])};
pcomando({bye, User}) ->
    {ok, NodoPc} =
        obtieneNodo(User), %% No provoca badmatch porque User siempre es creado correctamente
    {usuarios, NodoPc} ! {obtener, User, self()},
    receive
      {_, Juegos} ->
          eliminarJugador(Juegos, User);
      error ->
          ok
    end,
    {usuarios, NodoPc} ! {bye, User}.

%%Auxiliares  de lsg
%%Dado un buzón de mensajes específicos, lo limpia
pedirListaJuegos(0, M) ->
    M;
pedirListaJuegos(N, M) ->
    receive
      {listaPersonal, Mapa} ->
          pedirListaJuegos(N - 1, [Mapa | M]);
      empty ->
          pedirListaJuegos(N - 1, M)
    end.

%% Recibe una lista de "strings"
%% Agrega coma al final de cada uno excepto del último
comaAlfinal([]) ->
    [];
comaAlfinal([X]) ->
    [X];
comaAlfinal([X | Xs]) ->
    [X ++ "," | comaAlfinal(Xs)].

%% Dada una lista de mapas, los formatea como strings
parseoDeJuegos(Lista) ->
    ListaDeListas = [maps:to_list(X) || X <- Lista],
    Unidos = lists:concat(ListaDeListas),
    Stringueado = [lists:concat([A, "/", B, "/", C]) || {A, {B, C, _, _}} <- Unidos],
    lists:concat(comaAlfinal(Stringueado)).

%% Recibe una lista de juegos y un jugador que participa en esos juegos
%% Comunica con el 'juegos' que almacena cada juego para decirle que el jugador se desconectó
eliminarJugador([], _) ->
    ok;
eliminarJugador([X | Xs], User) ->
    {ok, NodoPc} = obtieneNodo(X),
    {juegos, NodoPc} ! {borrar, self(), {X, User}},
    receive
      {ok, Subs} ->
          broadcaster(Subs, {X}, 1),
          eliminarJugador(Xs, User);
      {ok, exist, Subs, Player} ->
          receive
            {Cond, Tablero} ->
                broadcaster([Player | Subs], {Cond, Tablero, X}, 1),
                eliminarJugador(Xs, User)
          end;
      error ->
          eliminarJugador(Xs, User)
    end.

%% Envía a todos los procesos de la lista un mensaje
%% [X|Xs] es una lista de jugadores
broadcaster([], _, _) ->
    ok;
broadcaster([X | Xs], {Juegoid}, N) ->
    [_, NodoPcS] = string:lexemes(X, "#"),
    NodoPc = list_to_atom(NodoPcS),
    {usuarios, NodoPc} ! {obtener, X, self()},
    receive
      {Psid, _} ->
          Cmdid = lists:concat([N, "%", node()]),
          Psid ! {update, lists:concat(["UPD ", Cmdid, " abandon ", Juegoid])};
      error ->
          ok
    end,
    broadcaster(Xs, {Juegoid}, N + 1);
broadcaster([X | Xs], {Cond, Tablero, Juegoid}, N) ->
    [_, NodoPcS] = string:lexemes(X, "#"),
    NodoPc = list_to_atom(NodoPcS),
    {usuarios, NodoPc} ! {obtener, X, self()},
    receive
      {Psid, _} ->
          Cmdid = lists:concat([N, "%", node()]),
          TableroN = lists:concat([integer_to_list(L) ++ "," || L <- Tablero]),
          Psid !
            {update, lists:concat(["UPD ", Cmdid, " tablero ", Juegoid, " ", Cond, " ", TableroN])};
      error ->
          ok
    end,
    broadcaster(Xs,
                {Cond, Tablero, Juegoid},
                N + 1).%% ------------------ FIN ZONA PCOMANDO ----------------------------%%

%% ------------------ ZONA MAPAS -----------------------------------%%
%MapaDeNombres es un mapa que tiene como clave el nombre de usuario y como valor una tupla {psocket,listaDeJuegos[]}
%Un User es nombre#nodo@pc
usuarios(MapaDeUsuarios) ->
    receive
      {Cartero, nuevo, User, Psid} ->
          case maps:find(User, MapaDeUsuarios) of
            error ->
                Mapa = maps:put(User, {Psid, []}, MapaDeUsuarios),
                Cartero ! ok,
                usuarios(Mapa);
            _ ->
                Cartero ! error,
                usuarios(MapaDeUsuarios)
          end;
      {acc, User, Juegoid, Cartero} ->
          case maps:find(User, MapaDeUsuarios) of
            {ok, {Psid, JuegosActuales}} ->
                Mapa = maps:put(User, {Psid, [Juegoid | JuegosActuales]}, MapaDeUsuarios),
                Cartero ! ok,
                usuarios(Mapa);
            error ->
                Cartero ! error,
                usuarios(MapaDeUsuarios)
          end;
      {obtener, User, Cartero} ->
          case maps:find(User, MapaDeUsuarios) of
            {ok, Tupla} ->
                Cartero ! Tupla,
                usuarios(MapaDeUsuarios);
            error ->
                Cartero ! error,
                usuarios(MapaDeUsuarios)
          end;
      {bye, User} ->
          Mapa = maps:remove(User, MapaDeUsuarios),
          usuarios(Mapa);
      {borrarJuego, User, Juegoid} ->
          case maps:find(User, MapaDeUsuarios) of
            {ok, {Psid, JuegosActuales}} ->
                Mapa = maps:put(User, {Psid, JuegosActuales -- [Juegoid]}, MapaDeUsuarios),
                usuarios(Mapa);
            error ->
                usuarios(MapaDeUsuarios)
          end;
      _ ->
          usuarios(MapaDeUsuarios)
    end.

%% MapaDeJuegos es un mapa que tiene como clave Id#nodo@pc y como valor una tupla de {local,visitante,espectadores[],procesoDeJuego}
%% ID: N#Nodo@PC, Local, Visitante, Suscritos, ProcesoDeJuego

%% Versión para nodos trabajadores
juegos(nodo, _) ->
    receive
      {_, Cartero} ->
          Cartero ! empty;
      {_, Cartero, _} ->
          io:format("Esto es un trabajador~n"),
          Cartero ! empty
    end,
    juegos(nodo, 0);
%% Versión para servidores
juegos(MapaDeJuegos, N) ->
    receive
      {nuevo, Cartero, {User}} ->
          Id = lists:concat([N, "#", atom_to_list(node())]),
          Mapa = maps:put(Id, {User, nadie, [], sinjuego}, MapaDeJuegos),
          Cartero ! {ok, Id},
          juegos(Mapa, N + 1);
      {listaPersonal, Cmdid} ->
          Cmdid ! {listaPersonal, MapaDeJuegos},
          juegos(MapaDeJuegos, N);
      {acc, Cartero, {User, Juegoid}} ->
          case maps:find(Juegoid, MapaDeJuegos) of
            {ok, {Local, nadie, Espectadores, sinjuego}} ->
                Mapa = maps:put(Juegoid,
                                {Local,
                                 User,
                                 Espectadores,
                                 spawn(?MODULE, tateti, [?Newtab, 0, 1, Juegoid])},
                                MapaDeJuegos), %% Cuando alguien acepta amrcamos el primer turno
                Cartero ! {ok, Local},
                juegos(Mapa, N);
            {ok, {_, _, _, _}} ->
                Cartero ! {error, ocupado},
                juegos(MapaDeJuegos, N);
            error ->
                Cartero ! {error, noExiste},
                juegos(MapaDeJuegos, N)
          end;
      {obtener, Cartero, {Juegoid}} ->
          case maps:find(Juegoid, MapaDeJuegos) of
            {ok, Juego} ->
                Cartero ! Juego,
                juegos(MapaDeJuegos, N);
            error ->
                Cartero ! error,
                juegos(MapaDeJuegos, N)
          end;
      {obs, Cartero, {User, Juegoid}} ->
          case maps:find(Juegoid, MapaDeJuegos) of
            error ->
                Cartero ! error,
                juegos(MapaDeJuegos, N);
            {ok, {Local, Visitante, Espectadores, JuegoTateti}} ->
                Mapa = maps:put(Juegoid,
                                {Local, Visitante, [User | Espectadores], JuegoTateti},
                                MapaDeJuegos),
                Cartero ! ok,
                juegos(Mapa, N)
          end;
      {noObs, Cartero, {User, Juegoid}} ->
          case maps:find(Juegoid, MapaDeJuegos) of
            error ->
                Cartero ! error,
                juegos(MapaDeJuegos, N);
            {ok, {Local, Visitante, Espectadores, JuegoTateti}} ->
                Mapa = maps:put(Juegoid,
                                {Local, Visitante, Espectadores -- [User], JuegoTateti},
                                MapaDeJuegos),
                Cartero ! ok,
                juegos(Mapa, N)
          end;
      {borrar, Cartero, {Juegoid, User}} ->
          case maps:find(Juegoid, MapaDeJuegos) of
            error ->
                Cartero ! error,
                juegos(MapaDeJuegos, N);
            {ok, {User, nadie, Subs, sinjuego}} ->
                Cartero ! {ok, Subs},
                Mapa = maps:remove(Juegoid, MapaDeJuegos),
                juegos(Mapa, N);
            {ok, {User, Visit, Subs, JuegoTateti}} ->
                Cartero ! {ok, exist, Subs, Visit},
                JuegoTateti ! {Cartero, local, bye},
                Mapa = maps:remove(Juegoid, MapaDeJuegos),
                juegos(Mapa, N);
            {ok, {Local, User, Subs, JuegoTateti}} ->
                Cartero ! {ok, exist, Subs, Local},
                JuegoTateti ! {Cartero, away, bye},
                Mapa = maps:remove(Juegoid, MapaDeJuegos),
                juegos(Mapa, N)
          end;
      {borrarJuego, _, {Juegoid}} ->
          Mapa = maps:remove(Juegoid, MapaDeJuegos),
          juegos(Mapa, N);
      _ ->
          juegos(MapaDeJuegos, N)
    end.

%% ----------------- FIN ZONA MAPAS --------------------------------%%

%% ------------------ ZONA PSTAT -----------------------------------%%
%%Envía freceuntemente la run_queue del nodo a los 'pbalance' de cada nodo conectado
pstat() ->
    X = erlang:statistics(run_queue),
    [{pbalance, Node} ! {stat, node(), X} || Node <- [node() | nodes()]],
    timer:sleep(?Intervalo),
    pstat().

%% Mantiene un mapa de nodos y su run_queue, envía el de menor carga si se lo piden
pbalance(MapaNodos) ->
    receive
      {stat, Nodo, Val} ->
          NMap = maps:put(Nodo, Val, MapaNodos),
          pbalance(NMap);
      {best, PId} ->
          {Node, _} = lists:nth(1, lists:keysort(2, maps:to_list(MapaNodos))),
          PId ! {best, Node},
          pbalance(MapaNodos)
    end.


%% ------------------ FIN ZONA PSTAT -------------------------------%%
