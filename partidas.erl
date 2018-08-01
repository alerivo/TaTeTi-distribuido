-module(partidas).
-import(lists,[flatten/1,append/2,nth/2]).
-import(dict,[new/0,map/2,fold/3,store/3,is_key/2,fetch/2,update/3,erase/2]).
-import(io_lib,[format/2]).
-export([partidas/2]).
-include("usuario.hrl").


%Representamos una partida con una 3-upla, donde el primer elemento representa el pid del juego,
%el segundo elemento será un entero que representa el identificador unico de la partida,
%el tercer elemento será un entero que representa la cantidad de observadores.

%PIniciadas sera un diccionario de partidas ya iniciadas donde las claves son el Id de juego y el valor
%sera una partida.

%Sugerencia importante: Id tiene ser resultado de aplicarle alguna funcion al Pid

n() ->
"
".


aumentarObs(Pid,Dict)->
  Id = pidAId(Pid),
  AumentarObs = fun({X,Y,Z}) -> {X,Y,Z+1} end,
  update(Id,AumentarObs,Dict).



decrementarObs(Pid,Dict)->
  Id = pidAId(Pid),
  AumentarObs = fun({X,Y,Z}) -> {X,Y,Z-1} end,
  update(Id,AumentarObs,Dict).



pidAId(Pid) -> Id = pid_to_list(Pid),
               string:slice(Id,1,length(Id)-2).



infoPartidas(PIniciadas,PEnEspera)->
  M1 = "Partidas esperando un jugador:"++n(),
  M2 = "ID de partida      Cantidad de observadores"++n(),
  Lector = Lector = fun(_,{_,Id,Obs}) -> flatten(format("  ~p                ~p~n",[Id,Obs])) end,
  Concatenar = fun(_,X,Y) -> lists:append(X,Y) end,
  TextoEnEspera = fold(Concatenar,[],map(Lector,PEnEspera)),
  M3 = n()++n()++"Partidas iniciadas:"++n(),
  M4 = "ID de partida      Cantidad de observadores"++n(),
  TextoIniciadas = fold(Concatenar,[],map(Lector,PIniciadas)),
  M1++M2++TextoEnEspera++M3++M4++TextoIniciadas.


buscoId(Id,Dict)->
  case is_key(Id,Dict) of
    false -> noEsta;
    true -> fetch(Id,Dict)
  end.





partidas(PIniciadas,PEnEspera)->
  receive
      {cerro_espera, Pid} ->
        Id = pidAId(Pid),
        partidas(PIniciadas, erase(Id, PEnEspera));

      {cerro_ini, Pid} ->
        Id = pidAId(Pid),
        partidas(erase(Id, PIniciadas), PEnEspera);

      {llego_obs,CantJugadores,Pid} ->
        case CantJugadores of
          1 ->
            partidas(PIniciadas,aumentarObs(Pid,PEnEspera));%Aumentar numero de observadores en partidas en espera
          2 ->
            partidas(aumentarObs(Pid,PIniciadas),PEnEspera)%Aumentar numero de observadores en partidas iniciadas
        end;

      {se_fue_obs,CantJugadores,Pid} ->
        case CantJugadores of
          1 ->
            partidas(PIniciadas,decrementarObs(Pid,PEnEspera));%Decrementar observadores en partidas en espera
          2 ->
            partidas(decrementarObs(Pid,PIniciadas),PEnEspera)%Decrementar observadores en partidas iniciadas
        end;

      {solicito_info,Pid} ->
        Pid ! {info,infoPartidas(PIniciadas,PEnEspera)},%Enviar un msg con todas las partidas
        partidas(PIniciadas,PEnEspera);

      {solicito_crear,Usuario,Pid} ->
        PidPartida = spawn(tateti, tateti,[Usuario]),%Crear una partida
        Id = pidAId(PidPartida),
        Msg = format("Se creo satisfactoriamente la partida con Id: ~p",[Id]),
        Pid ! {ok, Msg,PidPartida},
        NuevaPartida = {PidPartida, Id, 0},
        partidas(PIniciadas,store(Id,NuevaPartida,PEnEspera));%Se agrega una partida en espera

      {solicito_acceder,Usuario, Id,Pid} ->
        case buscoId(Id, PEnEspera) of
          noEsta ->
            Pid ! {rta, "No existe partida en espera con ese identificador"++n()},
            partidas(PIniciadas,PEnEspera);
          {PidPartida, Id, _} ->
            PidPartida ! {quiero_unirme, Usuario},%Solicita unirse a una partida
            partidas(PIniciadas,PEnEspera)
        end;
 
     % {solicito_jugar,Usuario,Id,Fil,Col} ->

     
      {empieza_partida,Pid,PidUsuario} ->%tateti me avisa que va a comenzar una partida
        Id = pidAId(Pid),
        Partida = buscoId(Id,PEnEspera),%Busca la partida entre las partidas en espera
        PEnEspera2 = erase(Id,PEnEspera),%Saca la partida de espera
        PIniciadas2 = store(Id,Partida,PIniciadas),%Comienza la partida
        PidUsuario ! {reenviar,"Te uniste a la partida "++Id++n()},
        partidas(PIniciadas2,PEnEspera2);

      
      {solicito_observar,Usuario, Id,Pid} ->
        case buscoId(Id, PEnEspera) of
          noEsta ->
            case buscoId(Id, PIniciadas) of
              noEsta ->
                Pid ! {rta, "No existe partida con ese identificador"++n()},
                partidas(PIniciadas,PEnEspera);
              {PidPartida, _, _} ->
                PidPartida ! {observa, Usuario},
                partidas(PIniciadas,PEnEspera)
            end;
        
          {PidPartida, _, _} ->
            PidPartida ! {observa, Usuario},%Solicita observar una partida
            partidas(PIniciadas,PEnEspera)

        end;
        
      
      {solicito_no_observar,Usuario, Id,Pid} ->
        case buscoId(Id, PEnEspera) of
          noEsta ->
            case buscoId(Id, PIniciadas) of
              noEsta ->
                Pid ! {rta, "No existe partida con ese identificador"++n()},
                partidas(PIniciadas,PEnEspera);
              {PidPartida, _, _} ->
                PidPartida ! {no_observa, Usuario},
                partidas(PIniciadas,PEnEspera)
            end;
        
          {PidPartida, _, _} ->
            PidPartida ! {no_observa, Usuario},%Solicita dejar de observar una partida
            partidas(PIniciadas,PEnEspera)
        end;

      {salir,Usuario} ->
        Enviar = fun({Pid}) -> Pid ! {se_va, Usuario} end,
        map(Enviar,Usuario#usuario.obs),%Avisarle  a todas las partidas que el jugador este observando que se va
        Jugando = Usuario#usuario.jugando,
        if 
          Jugando /= undefined -> Jugando ! {se_va, Usuario};%Si el usuario esta jugando avisa que se va del juego
          true -> ok
        end
  end.