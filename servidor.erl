-module(servidor).
-export([init/1]).


init(Principal) ->
    if Principal -> 
	       spawn(dispatcher, lanzar_dispatcher,[]),
	       register(pbalance,spawn(pbalance, pbalance, [[]]));
       true -> net_adm:ping(principal@Ale), % Actualizar con el nombre del nodo principal
               register(pstat,spawn(pstat, pstat,[])),
               register(usuarios,spawn(usuarios, usuarios,[ordsets:new()])),
               register(partidas,spawn(partidas, partidas,[dict:new(),dict:new()]))
    end,
    ok.


