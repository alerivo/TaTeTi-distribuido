-module(pstat).
-export([pstat/0]).

% El nodo raiz, el que recibira las nuevas conexiones, se llamara principal.
% Cada nodo que no es principal solo estara conectado (mediante ping) al principal.
% Mediremos la carga de un nodo calculando la suma de los elementos de la lista devuelta
% por erlang:statistics(active_tasks).

pstat() ->
    receive after 3000 -> ok end,
    [SOY] = io_lib:format("~p",[node()]),
    %%Suma = fun(X,Y)->X+Y end,
    %%Carga = lists:foldl(Suma,0,erlang:statistics(active_tasks)),
    usuarios ! {cuantos_usuarios},
    receive
     {cant_usuarios,Carga} -> 
          case string:prefix(SOY,"principal") of
                 nomatch ->
                        [NodoPrincipal] = nodes(),
                        {pbalance, NodoPrincipal} ! {envio_carga,node(),Carga}; 
                 true ->
                        pbalance ! {envio_carga,node(),Carga}
          end
    end,
    pstat(),
    ok.
