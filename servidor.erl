-module(servidor).
-export([init/1]).


init(Principal) ->
    register(pb,spawn(?MODULE, pbalance, [[]])),
