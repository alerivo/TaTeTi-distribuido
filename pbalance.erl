-module(pbalance).
-export([pbalance/1]).
-import(lists,[foldl/3]).

first({X,_})->X.

pbalance([E|T]) ->
  receive
    {envio_carga,Nodo,Carga} ->%Actualizar estado de carga de Nodo
      pbalance([{Nodo,Carga}] ++ [{X,Y} || {X,Y} <- [E|T], X /= Nodo ]);
    {dame_servidor,Dispatcher} ->%Enviar Nodo con menos carga
      Dispatcher ! {toma,first(foldl(fun({N1,C1},{N2,C2})->if C1<C2 -> {N1,C1}; true -> {N2,C2} end end,E,[E|T]))},
      pbalance([E|T])
  end,
  ok.

  