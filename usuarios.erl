-module(usuarios).
-import (ordsets, [new/0,add_element/2,del_element/2,is_element/2]).
-export([usuarios/1]).

% Llevaremos registro global de los usuarios conectados al servidor de juegos
% en un ordset.

usuarios(CTO) ->
  receive 
    {Pid,consulta,Nombre} ->
      case is_element(Nombre, CTO) of
        true ->
          Pid ! {error},
          usuarios(CTO);
        false ->
          CTO2 = add_element(Nombre, CTO),
          Pid ! {ok},
          usuarios(CTO2)
      end;
      
    {eliminar,Nombre} ->
      usuarios(del_element(Nombre, CTO));      
    
    {cuantos_usuarios} ->
      pstat ! {cant_usuarios,ordsets:size(CTO)},
      usuarios(CTO)
  end,
  ok.
