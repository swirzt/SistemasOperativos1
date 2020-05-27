-module(procs).

-export([work/1, start/2]).
-export([startAnillo/3, working/1]).

-import(tiempo, [wait/1]).

work(inic) -> receive Pid -> work(Pid) end;

work(Pid) ->
  receive
    fin -> ok;
    {0, _} -> Pid ! fin;

    {N, Msj} ->
      io:format("Recibí ~p, quedan ~p ~n", [Msj, N - 1]),
      Pid ! {N - 1, Msj},
      work(Pid);

    {inic, N, Msj} ->
      io:format("Comienzo a mandar '~p' ~p veces ~n", [Msj, N]),
      Pid ! {N, Msj},
      work(Pid)
  end.


start(M, Msj) ->
  W0 = spawn(?MODULE, work, [inic]),
  W1 = spawn(?MODULE, work, [W0]),
  W0 ! W1,
  W0 ! {inic, M, Msj},
  ok.


% Si su argumento es inic espera que la funcion conectar le de un PID
working(inic) -> receive Pid -> working(Pid) end;

working(Pid) ->
  receive
    % Mensaje inicial con todos los datos
    {inic, Msj, M, N} ->
      io:format("Comienzo a mandar '~p' ~p veces ~n", [Msj, M]),
      Pid ! {Msj, M, N},
      working(Pid);

    % Termino de enciar mensajes, empiezo a matar procesos
    {_, 0, N} ->
      io:format("Terminando procesos ~n"),
      %Es N-2 porque hay que mandar N-1 fin totales
      Pid ! {fin, N - 2};

    %Y este ya es uno
    % Recibo el mensaje, lo reenvio con M-1
    {Msj, M, N} ->
      io:format("Recibí ~p, quedan ~p ~n", [Msj, M - 1]),
      Pid ! {Msj, M - 1, N},
      working(Pid);

    % Es el ultimo, no debe hacer nada y termina
    {fin, 0} ->
      io:format("Mori~n"),
      ok;

    % Mata a su compañero y termina
    {fin, N} ->
      Pid ! {fin, N - 1},
      io:format("Mori y mato~n")
  end.


% Crea N procesos que coomienzan en working con argumento inic
% devuelve, una lista con sus PID
initializar(0, Ps) -> Ps;

initializar(N, Ps) ->
  X = spawn(?MODULE, working, [inic]),
  initializar(N - 1, [X | Ps]).


% Crea la coneccion circular de los procesos entregando los PID en circulo
conectar(PUltimo, PActual, []) -> PActual ! PUltimo;

conectar(PUltimo, PActual, [P | Ps]) ->
  PActual ! P,
  conectar(PUltimo, P, Ps).


% cabeza y cola de lista
head([X | _]) -> X.

tail([_ | Xs]) -> Xs.

startAnillo(M, N, Msj) ->
  List = initializar(N, []),
  X = head(List),
  conectar(X, X, tail(List)),
  % Envia el mensaje de inicio al proceso X
  X ! {inic, Msj, M, N},
  ok.
