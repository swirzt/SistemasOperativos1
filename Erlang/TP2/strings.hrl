%%Recibe una cadena del tipo Algo#nodo@PC y devuelve {ok,nodo@PC} si la cadena es correcta y el nodo existe
%% De lo contrario devuelve {error, Razón} 
obtieneNodo(Dato) -> 
    case string:lexemes(Dato,"#") of
        [_,NodoPc] ->   Nodo = list_to_atom(NodoPc),
                        Eval = in(Nodo,[node()|nodes()]),
                        if
                            Eval -> {ok,Nodo};
                            true -> {error,"badNode"}
                        end;
        _ -> {error,"wrongFormat"}
    end.

%% Recibe un elemento y una lista, devuelve true si el elemento se encuentra en la lista
in(_,[]) -> false;
in(X,[Y|Ys]) ->
    if
        X == Y -> true;
        true   -> in(X,Ys)
    end.

%% Recibe 2 listas, si algún elemento de la primera se encuentra en la segunda, devuelve true
multiIn([],_) -> false;
multiIn([X|Xs],L) ->
    case in(X,L) of
        true -> true;
        _ -> multiIn(Xs,L)
    end.