-module(tateti).
-include("usuario.hrl").
-import(io_lib,[format/2]).
-import (lists, [nth/2,filter/2, is_member/2]).
-import(dict,[new/0,map/2,fold/3,store/3,is_key/2,fetch/2,update/3,erase/2]).
-export([tateti/1]).


%Representaremos a los observadores con un diccionario cuya clave sea el nombre de usuario y el valor 
%sea su pid.


n() ->
"
".



notificarNoObs(Jugadores,Observador,Observadores)->
  enviar(Observador, "Dejaste de observar esta partida."++n()),
  Msg = Observador#usuario.nombre++" dejo de observar esta partida."++n(),
  enviarList(Jugadores,Msg),
  enviarDict(Observadores,Msg),
  ok.

notificarObs(Jugadores,Observador,Observadores)->
  enviar(fetch(Observador,Observadores), "Ahora observas esta partida."++n()),
  enviarList(Jugadores,Observador++" ahora observa esta partida."++n()),
  enviarDict(Observadores, Observador#usuario.nombre++" ahora observa esta partida."++n()),
  ok.

enviar(Usuario, Msg) ->
  Usuario#usuario.psocket ! {reenviar, Msg},
  ok.

enviarList(Jugadores, Msg)->
  Enviar = fun(Usuario)-> enviar(Usuario,Msg) end,
  lists:map(Enviar,Jugadores),
  ok.

enviarDict(Observadores,Msg)->
  Enviar = fun(_,Psocket)-> Psocket ! {reenviar, Msg} end,
  map(Enviar,Observadores),
  ok.

tateti(Jugador1)->
  Tablero = {{0,0,0},{0,0,0},{0,0,0}},
  tateti(Tablero,[Jugador1],new(),1),
  ok.

tateti(Tablero,Jugadores,Observadores,TurnoDe)->
  receive
    {se_une, Jugador2} ->
      case is_member(Jugador2,Jugadores) of
        true ->
          enviar(Jugador2,"Ya estas jugando esta partida"++n()),
          tateti(Tablero,Jugadores,Observadores,TurnoDe);

        false ->
          partidas ! {empieza_partida,self()},
          Msg = "Inicia la partida. Se unio "++Jugador2#usuario.nombre++n()++"Es el turno de "++(nth(1,Jugadores))#usuario.nombre++n(),
          enviarList(Jugadores,Msg),
          enviarDict(Observadores,Msg),
          tateti(Tablero,Jugadores++[Jugador2],erase(Jugador2#usuario.nombre,Observadores),TurnoDe)
      end;
    {observa, Observador} ->
      case is_member(Observador, Jugadores) of
        true ->
          enviar(Observador,"Estas jugando esta partida"++n()),
          tateti(Tablero,Jugadores,Observadores,TurnoDe);

        false -> 
          NombreObs = Observador#usuario.nombre,
          PidObs = Observador#usuario.psocket,
          case is_key(Observador,Observadores) of
            true ->
              enviar(Observador, "Ya observas esta partida."++n()),
              tateti(Tablero,Jugadores,Observadores,TurnoDe);
            false ->
              PidObs ! {actualizar,agregoObs,self()},
              partidas ! {llego_obs,length(Jugadores),self()},
              Observadores2 = store(NombreObs,PidObs,Observadores),
              notificarObs(Jugadores,Observador,Observadores),
              tateti(Tablero,Jugadores,Observadores2,TurnoDe)
          end
      end;

    {no_observa, Observador} ->
      NombreObs = Observador#usuario.nombre,
      case is_key(NombreObs,Observadores) of
        false ->
          enviar(Observador, "No observabas esta partida."++n()),
          tateti(Tablero,Jugadores,Observadores,TurnoDe);
        true ->
          PidObs = fetch(Observador,Observadores),
          PidObs ! {actualizar,quitoObs,self()},
          partidas ! {se_fue_obs,length(Jugadores),self()},
          Observadores2 = erase(NombreObs,Observadores),
          notificarNoObs(Jugadores,Observador,Observadores),
          tateti(Tablero,Jugadores,Observadores2,TurnoDe)
      end;
    {se_va_jugador,Jugador} ->
      case is_member(Jugador,Jugadores) of
        true ->
          NombreJugador = Jugador#usuario.nombre,
          Msg = format("Te fuiste de la partida. Llevas ~p ganadas y ~p perdidas.",[Jugador#usuario.ganadas,Jugador#usuario.perdidas+1]),
          Jugador#usuario.psocket ! {reenviar, Msg++n()},
          Jugador#usuario.psocket ! {actualizar,perdidas,0},
          QuitarObs = fun(_,Pid) -> Pid ! {actualizar,quitoObs,self()} end,
          map(QuitarObs,Observadores),
          enviarDict(Observadores, "Fin de la partida: "++NombreJugador++" se fue."++n()),
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
      case is_key(Observador,Observadores) of
        true ->
          fetch(Observador,Observadores) ! {actualizar,quitoObs,self()},
          partidas ! {se_fue_obs,length(Jugadores),self()},
          Observadores2 = erase(Observador,Observadores),
          notificarNoObs(Jugadores,Observador,Observadores),
          tateti(Tablero,Jugadores,Observadores2,TurnoDe);

        false ->
          tateti(Tablero,Jugadores,Observadores,TurnoDe)
      end

    end,
    ok.
