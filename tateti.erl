-module(tateti).
-include("usuario.hrl").
-import(io_lib,[format/2]).
-import (lists, [map/2,any/2,nth/2,filter/2]).
-export([tateti/1]).

n() ->
"
".

is_member(Elemento, Lista) ->
  any(fun(Elto) -> Elto == Elemento end, Lista).

notificarNoObs(Jugadores,Observador,Observadores)->
  enviar(Observador, "Dejaste de observar esta partida."++n()),
  enviarList(Observadores++Jugadores--[Observador], Observador#usuario.nombre++" dejo de observar esta partida."++n()),
  ok.

notificarObs(Jugadores,Observador,Observadores)->
  enviar(Observador, "Ahora observas esta partida."++n()),
  enviarList(Observadores++Jugadores, Observador#usuario.nombre++" ahora observa esta partida."++n()),
  ok.

enviar(Usuario, Msg) ->
  Usuario#usuario.psocket ! {reenviar, Msg},
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
              Observador#usuario.psocket ! {actualizar,agregoObs,self()},
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
          Observador#usuario.psocket ! {actualizar,quitoObs,self()},
          partidas ! {se_fue_obs,length(Jugadores),self()},
          notificarNoObs(Jugadores,Observador,Observadores),
          tateti(Tablero,Jugadores,Observadores--[Observador],TurnoDe)
      end;

    {se_va_jugador,Jugador} ->
      case is_member(Jugador,Jugadores) of
        true ->
          NombreJugador = Jugador#usuario.nombre,
          Msg = format("Te fuiste de la partida. Llevas ~p ganadas y ~p perdidas.",[Jugador#usuario.ganadas,Jugador#usuario.perdidas+1]),
          Jugador#usuario.psocket ! {reenviar, Msg++n()},
          Jugador#usuario.psocket ! {actualizar,perdidas,0},
          QuitarObs = fun(Observador) -> Observador#usuario.psocket ! {actualizar,quitoObs,self()} end,
          map(QuitarObs,Observadores),
          enviarList(Observadores, "Fin de la partida: "++NombreJugador++" se fue."++n()),
          case length(Jugadores) of
            1 ->
              partidas ! {cerro_espera, self()};
            2 ->
              Temp = fun(Usuario) -> Usuario /= Jugador end,
              [ElOtroJugador] = filter(Temp, Jugadores),
              Msg2 = format("~p se fue. Ganaste la partida! Llevas ~p ganadas y ~p perdidas.",[NombreJugador,ElOtroJugador#usuario.ganadas+1,ElOtroJugador#usuario.perdidas]),
              ElOtroJugador#usuario.psocket ! {reenviar,Msg2++n()},
              ElOtroJugador#usuario.psocket ! {actualizar,ganadas,0},
              partidas ! {cerro_ini, self()}
          end;
        false -> 
          ok
      end;
      
    {se_va_observador,Observador} ->
      case is_member(Observador,Observadores) of
        true ->
          Observador#usuario.psocket ! {actualizar,quitoObs,self()},
          partidas ! {se_fue_obs,length(Jugadores),self()},
          notificarNoObs(Jugadores,Observador,Observadores);

        false ->
          tateti(Tablero,Jugadores,Observadores,TurnoDe)
      end

    end,
    ok.
