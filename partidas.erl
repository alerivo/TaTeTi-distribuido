-module(partidas).
-import(lists,[flatten/1,map/2,member/2,nth/2]).
-import(io_lib,[format/2]).
-export([partidas/3]).
-include("usuario.hrl").


%Representamos una partida con una 3-upla, donde el primer elemento representa el pid del juego,
%el segundo elemento será un entero que representa el identificador unico de la partida,
%el tercer elemento será un entero que representa la cantidad de observadores.

n() ->
"
".

sacar(Pid,Lista)->
  [{Pid2,Id,Obs} || {Pid2,Id,Obs} <- Lista, Pid2 /= Pid ].

aumentarObs(Pid,Lista)->
  [{Pid3,Id3,Obs3}] =[{Pid2,Id,Obs} || {Pid2,Id,Obs} <- Lista, Pid2 == Pid ],
  (Lista--[{Pid3,Id3,Obs3}])++[{Pid3,Id3,Obs3+1}].

decrementarObs(Pid,Lista)->
  [{Pid3,Id3,Obs3}] =[{Pid2,Id,Obs} || {Pid2,Id,Obs} <- Lista, Pid2 == Pid ],
  (Lista--[{Pid3,Id3,Obs3}])++[{Pid3,Id3,Obs3-1}].



infoPartidas(PIniciadas,PEnEspera)->
  M1 = "Partidas esperando un jugador:"++n(),
  M2 = "ID de partida      Cantidad de observadores"++n(),
  Lector = fun({_,Id,Obs}) -> format("  ~p                ~p~n",[Id,Obs]) end,
  TextoEnEspera = flatten(map(Lector,PEnEspera)),
  M3 = n()++n()++"Partidas iniciadas:"++n(),
  M4 = "ID de partida      Cantidad de observadores"++n(),
  TextoIniciadas = flatten(map(Lector,PIniciadas)),
  M1++M2++TextoEnEspera++M3++M4++TextoIniciadas.

buscoId(Id,Lista)->
  Busqueda = [{Pid,Id2,Obs} || {Pid,Id2,Obs} <- Lista, Id2 == Id ],
  case length(Busqueda) of
    0 -> noEsta;
    _ -> nth(1, Busqueda)
  end.


buscoPid(Pid,Lista)->
  [{Pid2,Id,Obs} || {Pid2,Id,Obs} <- Lista, Pid2 == Pid ].


partidas(PIniciadas,PEnEspera,CantPartidas)->
  receive
      {cerro_espera, Pid} ->
        partidas(PIniciadas, sacar(Pid, PEnEspera), CantPartidas);

      {cerro_ini, Pid} ->
        partidas(sacar(Pid, PIniciadas), PEnEspera, CantPartidas);

      {llego_obs,CantJugadores,Pid} ->
        case CantJugadores of
          1 ->
            partidas(PIniciadas,aumentarObs(Pid,PEnEspera),CantPartidas);%Aumentar numero de observadores en partidas en espera
          2 ->
            partidas(aumentarObs(Pid,PIniciadas),PEnEspera,CantPartidas)%Aumentar numero de observadores en partidas iniciadas
        end;

      {se_fue_obs,CantJugadores,Pid} ->
        case CantJugadores of
          1 ->
            partidas(PIniciadas,decrementarObs(Pid,PEnEspera),CantPartidas);%Decrementar observadores en partidas en espera
          2 ->
            partidas(decrementarObs(Pid,PIniciadas),PEnEspera,CantPartidas)%Decrementar observadores en partidas iniciadas
        end;

      {solicito_info,Pid} ->
        Pid ! {info,infoPartidas(PIniciadas,PEnEspera)},%Enviar un msg con todas las partidas
        partidas(PIniciadas,PEnEspera,CantPartidas);

      {solicito_crear,Usuario,Pid} ->
        PidPartida = spawn(tateti, tateti,[Usuario]),%Crear una partida
        Msg = format("Se creo satisfactoriamente la partida con Id: ~p",[CantPartidas]),
        Pid ! {ok, Msg},
        NuevaPartida = {PidPartida, CantPartidas, 0},
        partidas(PIniciadas,PEnEspera++[NuevaPartida],CantPartidas+1);

      {solicito_acceder,Usuario, Id,Pid} ->
        case buscoId(Id, PEnEspera) of
          noEsta ->
            Pid ! {rta, "No existe partida en espera con ese identificador"++n()},
            partidas(PIniciadas,PEnEspera,CantPartidas);
          {PidPartida, Id, Obs} ->
            Part = {PidPartida, Id, Obs},
            PidPartida ! {se_une, Usuario},%Intenta unirse a una partida
            Pid ! {rta, "Te uniste"++n()},
            partidas(PIniciadas++[Part],PEnEspera--[Part],CantPartidas)%Esto esta mal
        end;
 
     % {solicito_jugar,Usuario,Id,Fil,Col} ->


      {empezo,Pid} ->
        Partida = buscoPid(Pid,PEnEspera),
        partidas(PIniciadas++Partida,PEnEspera--Partida,CantPartidas);



      {solicito_observar,Usuario, Id,Pid} ->
        case buscoId(Id, PEnEspera++PIniciadas) of
          noEsta ->
            Pid ! {rta, "No existe partida con ese identificador"++n()},
            partidas(PIniciadas,PEnEspera,CantPartidas);

          {PidPartida, Id, _} ->
            PidPartida ! {observa, Usuario},%Solicita observar una partida, falta aumentar el numero de observadores
            partidas(PIniciadas,PEnEspera,CantPartidas)
        end;
        
      {solicito_no_observar,Usuario, Id,Pid} ->
        case buscoId(Id, PEnEspera++PIniciadas) of
          noEsta ->
            Pid ! {rta, "No existe partida con ese identificador"++n()},
            partidas(PIniciadas,PEnEspera,CantPartidas);

          {PidPartida, Id, _} ->
            PidPartida ! {no_observa, Usuario},%Dejar de observar una partida
            partidas(PIniciadas,PEnEspera,CantPartidas)%Falta decrementar el numero de observadores
        end;

      {salir,Usuario} ->
        Enviar = fun({Pid,_,_}) -> Pid ! {se_va, Usuario} end,
        map(Enviar,Usuario#usuario.obs),%Avisarle  a todas las partidas que el jugador esta observando que se va
        if 
          Usuario#usuario.jugando /= undefined -> Pid ! {se_va, Usuario};
          true -> ok
        end
  end,
  ok.