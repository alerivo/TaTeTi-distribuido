-module(tateti).
-import (lists, [map/2,is_member/2,nth/2]).
-export([tateti/1]).

n() ->
"
".

notificarNoObs(Jugadores,Observador,Observadores)->
  enviar(Observador, "Dejaste de observar esta partida."++n()),
  enviarList(Observadores++Jugadores, nombre(Observador)++" dejo de observar esta partida."++n()),
  ok.

notificarObs(Jugadores,Observador,Observadores)->
  enviar(Observador, "Ahora observas esta partida."++n()),
  enviarList(Observadores++Jugadores, nombre(Observador)++" ahora observa esta partida."++n()),
  ok.


enviar({_, Psocket}, Msg)->
  Psocket ! {reenviar, Msg},
  ok.



enviarList(Jugadores, Msg)->
  Enviar = fun({_,Psocket})-> Psocket ! {reenviar, Msg} end,
  map(Enviar,Jugadores),
  ok.

tateti(Jugador1)->
  Tablero = {{0,0,0},{0,0,0},{0,0,0}},
  tateti(Tablero,[Jugador1],[],1),
  ok.

tateti(Tablero,Jugadores,Observadores,TurnoDe)->
  receive
    {se_une, Jugador2} ->
      case length(Jugadores) of
        2 ->
          enviar(Jugador2,"La partida ya esta completa"++n()),
          tateti(Tablero,Jugadores,Observadores,TurnoDe);
        1->
          case is_member(Jugador2,Jugadores) of
            true ->
              enviar(Jugador2,"Ya estas jugando esta partida"++n()),
              tateti(Tablero,Jugadores,Observadores,TurnoDe);

            false ->
              partidas ! {empezo,self()},
              enviarList(Jugadores++Observadores++[Jugador2],"Inicia la partida. Se unio "++
              Jugador2#usuario.nombre++n()++"Es el turno de "++(nth(1,Jugadores))#usuario.nombre++n()),
              tateti(Tablero,Jugadores++[Jugador2],Observadores,TurnoDe)
          end
      end;

    {observa, Observador} ->
      case is_member(Observador, Jugadores) of
        true ->
          enviar(Observador,"Estas jugando esta partida"++n()),
          tateti(Tablero,Jugadores,Observadores,TurnoDe);

        false -> 
          case is_member(Observador,Observadores) of
            true ->
              enviar(Observador, "Ya observas esta partida."++n()),
              tateti(Tablero,Jugadores,Observadores,TurnoDe);
            false ->
              Observador#usuario.obs++[self()],
              partidas ! {llego_obs,length(Jugadores),self()},
              notificarObs(Jugadores,Observador,Observadores),
              tateti(Tablero,Jugadores,Observadores++[Observador],TurnoDe)
          end
      end;

    {no_observa, Observador} ->
      case is_member(Observador,Observadores) of
        false ->
          enviar(Observador, "No observabas esta partida."++n()),
          tateti(Tablero,Jugadores,Observadores,TurnoDe);
        true ->
          Observador#usuario.obs--[self()],
          partidas ! {se_fue_obs,length(Jugadores),self()},
          notificarNoObs(Jugadores,Observador,Observadores),
          tateti(Tablero,Jugadores,Observadores--[Observador],TurnoDe)
      end;

    {se_va, Jugador} ->
      case is_member(Jugador,Jugadores) of
        true ->
          case length(Jugadores) of
            1 ->
              partidas ! {cerro_espera, self()},
              enviarList(Observadores++Jugadores, "Fin de la partida "++nombre(Jugador)++" se fue."++n()),
              exit("Termino partida");
            2 ->
              partidas ! {cerro_ini, self()},
              enviarList(Observadores++Jugadores, "Fin de la partida "++nombre(Jugador)++" se fue."++n()),
              exit("Termino partida")
          end;
        false -> 
          ok
      end,
      case is_member(Jugador,Observadores) of
        true ->
          partidas ! {se_fue_obs,length(Jugadores),self()},
          notificarNoObs(Jugadores,Jugador,Observadores);

        false ->
          tateti(Tablero,Jugadores,Observadores,TurnoDe)
      end
    end,
    ok.





