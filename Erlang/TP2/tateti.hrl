-include("strings.hrl").
-define(Newtab,[0,0,0,0,0,0,0,0,0]).

%% Como un jugador se representa con 1 y el otro con -1, luego una jugada ganadora obtiene:
%% 3 en una fila, columna o diagonal, si ganó el jugador local (w1)
%% -3 en una fila, columna o diagonal, si ganó el jugador visitante (w2)
%% De lo contrario devuelve que no ocurrió nada (nada)
checkGanador([A1,A2,A3,B1,B2,B3,C1,C2,C3]) ->
    %% filas
    F1 = A1 + A2 +A3, F2 = B1 + B2 + B3, F3 = C1 + C2 + C3,
    %% columnas
    Col1 = A1 + B1 + C1, Col2 = A2 + B2 + C2, Col3 = A3 + B3 + C3,
    %% diagonales
    Diag1 = A1 + B2 + C3, Diag2 = C1 + B2 + A3,
    %% Hardcoded because why not, termina siendo O(1) (o quizas es O(8) por el min y el max)
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

%%Recibe una lista que representa un tablero, una posición y un elemento, reemplaza la posición de la lista con el elemento
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
%% Pueden jugar local o away, 1 es local y -1 es away. 
%% Recibe un mensaje con la jugada a realizar
%% Si la jugada indica que un jugador realizó una jugada errónea o abandonó, actua acorde
%% Si la jugada es valida, actualiza el tablero y avisa del nuevo estado
tateti(Tablero, Plays,Turno,Juegoid) ->
    receive
        {Cartero,local,bye} -> {Jugada,Jugador} = {abandon,w2};
        {Cartero,away, bye} -> {Jugada,Jugador} = {abandon,w1};
        {Cartero, Cond, Pos} -> {Jugada,Jugador} = {Pos, Cond}
    end,
    if 
        (Jugada == 0)  and (Jugador == local)-> Cartero ! {w2,Tablero},funcionMataJuego(Juegoid);
        (Jugada == 0)  and (Jugador == away)-> Cartero ! {w1,Tablero},funcionMataJuego(Juegoid);
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

%% Recibe el nombre de un juego, obtiene el nodo donde está almacenado
%% Pide a el proceso 'juegos' de ese nodo por la información de sus jugadores
%% Elimina ese juego de la lista de juegos activos de estos jugadores en el proceso 'juagadores'
%% Luego borra el juego en el proceso 'juegos'
funcionMataJuego(Juegoid) ->
    case obtieneNodo(Juegoid) of
        {ok,NodoJuego} ->
            {juegos, NodoJuego} ! {obtener, self(),{Juegoid}},
            receive
                {Local, Visitante, _, _} ->{ok,Nodo1} = obtieneNodo(Local),
                                        {usuarios,Nodo1} ! {borrarJuego,Local,Juegoid},
                                            case Visitante of
                                                nadie -> ok;
                                                _ -> {ok,Nodo2} = obtieneNodo(Visitante),
                                                    {usuarios,Nodo2} ! {borrarJuego,Visitante, Juegoid}
                                            end;
                error -> ok
            end,
            {juegos, NodoJuego} ! {borrarJuego, self(), {Juegoid}};
        {error,_} -> ok %% No debería entrar a esta zona porque siempre se llama con un JuegoId correcto
    end.