-module(tateti).
-include("usuario.hrl").
-import(io_lib,[format/2]).
-import (lists, [nth/2,filter/2, sublist/2,sublist/3,nthtail/2,foldr/3,foldl/3,head/1]).
-import(dict,[new/0,map/2,fold/3,store/3,is_key/2,fetch/2,update/3,erase/2]).
-import(string,[slice/3]).
-import(math,[fmod/2]).
-export([tateti/1]).


%Representaremos a los observadores con un diccionario cuya clave sea el nombre de usuario y el valor 
%sea su pid.


n() ->
"
".

nombre(R) -> R#usuario.nombre.

is_member(J,R) ->
	B2 = R == [],  
	if 
		B2 ->
			false;
		true -> 
			B = nombre(J) == nombre(nth(1,R)),
			if 
				B -> true;
				true -> is_member(J,sublist(R,2,length(R)))
			end
	end.

pos(Fil,Col) ->
  (Fil-1)*3+Col.

funString(L) -> foldr (fun(X,Y) -> X ++ Y end,"",L).


imprimirTablero(L,J1,J2) ->
  L2 = lists:map(fun(X) -> case X of
                      0 -> " ";
                      1 -> "X";
                      2 -> "O"
                      end end,L), 
  Str = J1 ++ " se representa con X" ++ n() ++
        J2 ++ " se representa con O" ++ n(),
  Temp = funString(L2),
  Fila1 = slice(Temp,0,3),
  Fila2 = slice(Temp,3,3),
  Fila3 = slice(Temp,6,3),
  Str ++ Fila1 ++ n() ++ Fila2 ++ n() ++ Fila3 ++ n().

modificarTablero (Pos,Tablero,TurnoDe) ->
  sublist(Tablero,Pos-1) ++ [TurnoDe] ++ nthtail(Pos,Tablero).

funSuma(L) -> foldl (fun(X,Y) -> X+Y end ,0,L).
esTreoSeis(L) -> S = funSuma(L),
                 (S == 3) or (S == 6).

verFilas(TablTemp) ->
  Fila1 = sublist(TablTemp,3),
  Temp = nthtail(3,TablTemp),
  Fila2 = sublist(Temp,3),
  Fila3 = nthtail(3,Fila2),
  esTreoSeis(Fila1) or esTreoSeis(Fila2) or esTreoSeis(Fila3).

verCol(TablTemp) ->
  Col1 = [nth(1,TablTemp),nth(4,TablTemp),nth(7,TablTemp)],
  Col2 = [nth(2,TablTemp),nth(5,TablTemp),nth(8,TablTemp)],
  Col3 = [nth(3,TablTemp),nth(6,TablTemp),nth(9,TablTemp)],
  esTreoSeis(Col1) or esTreoSeis(Col2) or esTreoSeis(Col3).

verDiag(TablTemp) ->
  Diag1 = [nth(1,TablTemp),nth(5,TablTemp),nth(9,TablTemp)],
  Diag2 = [nth(3,TablTemp),nth(5,TablTemp),nth(7,TablTemp)],
  esTreoSeis(Diag1) or esTreoSeis(Diag2).

ganoAlguien(Tablero, TurnoDe) ->
  TablTemp = lists:map(fun(X) -> if X /= TurnoDe -> 0; true -> X end end, Tablero),
  verFilas(TablTemp) or verCol(TablTemp) or verDiag(TablTemp).

esEmpate(Tablero) ->
  Sum = fun(X,Y) -> X+Y end, 
  foldl(Sum,0,Tablero) == 13. % Si la suma del tablero es 13 es porque esta completo

notificarNoObs(Jugadores,Observador,Observadores)->
  enviar(Observador, "Dejaste de observar esta partida."++n()),
  Msg = Observador#usuario.nombre++" dejo de observar esta partida."++n(),
  enviarList(Jugadores,Msg),
  enviarDict(Observadores,Msg),
  ok.

notificarObs(Jugadores,Observador,Observadores)->
  NombreObs = Observador#usuario.nombre,
  enviar(Observador, "Ahora observas esta partida."++n()),
  enviarList(Jugadores,NombreObs++" ahora observa esta partida."++n()),
  enviarDict(Observadores, NombreObs++" ahora observa esta partida."++n()),
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
  Tablero = [0,0,0,0,0,0,0,0,0],
  tateti(Tablero,[Jugador1],new(),1),
  ok.

tateti(Tablero,Jugadores,Observadores,TurnoDe)->
  receive
    {quiero_unirme, Jugador2} ->
      Msg = "Inicia la partida. Se unio "++Jugador2#usuario.nombre++n()++"Es el turno de "++(nth(1,Jugadores))#usuario.nombre++n(),
      Jugadores2 = Jugadores++[Jugador2],
      enviarList(Jugadores2,Msg),
      enviarDict(Observadores,Msg),
      partidas ! {ok},
      tateti(Tablero,Jugadores2,erase(Jugador2#usuario.nombre,Observadores),TurnoDe);

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

    {solicito_jugar,Usuario,Fil,Col} ->
      B =  Usuario#usuario.nombre == (nth(TurnoDe,Jugadores))#usuario.nombre,
      PsocketUsuario = Usuario#usuario.psocket,
      if B ->
        B2 = nth(pos(Fil,Col),Tablero) == 0,
        if B2  ->
          Tablero2 = modificarTablero(pos(Fil,Col),Tablero,TurnoDe),
          [Jugador2] = filter(fun(X) -> X#usuario.nombre /= Usuario#usuario.nombre end,Jugadores),
          PsocketJugador2 = Jugador2#usuario.psocket,
          B3 = ganoAlguien(Tablero2,TurnoDe),
          B4 = esEmpate(Tablero2),
          TableroString = imprimirTablero(Tablero2,Usuario#usuario.nombre,Jugador2#usuario.nombre),
          enviarDict(Observadores,TableroString),
          enviarList(Jugadores,TableroString),
          if 
            B3 ->
              enviarDict(Observadores,"El jugador " ++ Usuario#usuario.nombre ++ " gano la partida" ++n()),
              map(fun(_,ObsSocket) -> ObsSocket ! {actualizar,quitoObs,self()} end, Observadores),
              PsocketUsuario ! {reenviar, "Ganaste la partida, llevas "++ integer_to_list(Usuario#usuario.ganadas + 1) ++ " ganadas"++n()},
              PsocketUsuario ! {actualizar,ganadas,0},
              PsocketUsuario ! {actualizar,jugando,undefined},
              PsocketJugador2 ! {reenviar, "Perdiste la partida, llevas "++ integer_to_list(Jugador2#usuario.perdidas+1) ++" perdidas"++n()},
              PsocketJugador2 ! {actualizar,perdidas,0},
              PsocketJugador2 ! {actualizar,jugando,undefined},
              partidas ! {cerro_ini, self()},
              ok;
            B4 ->
              enviarDict(Observadores,"La partida termino en empate." ++n()),
              map(fun(_,ObsSocket) -> ObsSocket ! {actualizar,quitoObs,self()} end, Observadores),
              PsocketUsuario ! {reenviar, "Hubo empate! Llevas "++integer_to_list(Usuario#usuario.ganadas)++" ganadas y "++integer_to_list(Usuario#usuario.perdidas)++" perdidas."++n()},
              PsocketUsuario ! {actualizar,jugando,undefined},
              PsocketJugador2 ! {reenviar, "Hubo empate! Llevas "++integer_to_list(Jugador2#usuario.ganadas)++" ganadas y "++integer_to_list(Jugador2#usuario.perdidas)++" perdidas."++n()},
              PsocketJugador2 ! {actualizar,jugando,undefined},
              partidas ! {cerro_ini, self()},
              ok;
            true ->
              SigTurno = round((fmod(TurnoDe,2)) + 1),
              Sig = nth(SigTurno,Jugadores),
              Msg3 = "Es el turno de " ++ Sig#usuario.nombre ++ n(),
              enviarDict(Observadores,Msg3),
              enviarList(Jugadores,Msg3),
              tateti(Tablero2,Jugadores,Observadores,SigTurno)
          end;
        true ->
          PsocketUsuario ! {reenviar, "Casillero ocupado, elija otra posicion"++n()},
          tateti(Tablero,Jugadores,Observadores,TurnoDe)
        end;
      true ->
        PsocketUsuario ! {reenviar, "No es tu turno!"++n()},
        tateti(Tablero,Jugadores,Observadores,TurnoDe)
      end;

    {no_observa, Observador} ->
      NombreObs = Observador#usuario.nombre,
      case is_key(NombreObs,Observadores) of
        false ->
          enviar(Observador, "No observabas esta partida."++n()),
          tateti(Tablero,Jugadores,Observadores,TurnoDe);
        true ->
          PidObs = fetch(Observador#usuario.nombre,Observadores),
          PidObs ! {actualizar,quitoObs,self()},
          partidas ! {se_fue_obs,length(Jugadores),self()},
          Observadores2 = erase(NombreObs,Observadores),
          notificarNoObs(Jugadores,Observador,Observadores),
          tateti(Tablero,Jugadores,Observadores2,TurnoDe)
      end;
    {se_va_jugador,Jugador} ->
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
          Temp = fun(Usuario) -> Usuario#usuario.nombre /= Jugador#usuario.nombre end,
          [ElOtroJugador] = filter(Temp, Jugadores),
          Msg2 = format("~p se fue. Ganaste la partida! Llevas ~p ganadas y ~p perdidas.",[NombreJugador,ElOtroJugador#usuario.ganadas+1,ElOtroJugador#usuario.perdidas]),
          ElOtroJugador#usuario.psocket ! {reenviar,Msg2++n()}, %% Avisar al otro jugador que gano
          ElOtroJugador#usuario.psocket ! {actualizar,ganadas,0}, %% Actualizar partidas ganadas al otro jugador
          ElOtroJugador#usuario.psocket ! {actualizar,jugando,undefined}, %% Setear jugando a undefined
          partidas ! {cerro_ini, self()} %% Cerrar partida
      end;

    {se_va_observador,Observador} ->
      NombreObs = Observador#usuario.nombre,
      case is_key(NombreObs,Observadores) of
        true ->
          fetch(NombreObs,Observadores) ! {actualizar,quitoObs,self()},
          partidas ! {se_fue_obs,length(Jugadores),self()},
          Observadores2 = erase(Observador,Observadores),
          notificarNoObs(Jugadores,Observador,Observadores),
          tateti(Tablero,Jugadores,Observadores2,TurnoDe);

        false ->
          tateti(Tablero,Jugadores,Observadores,TurnoDe)
      end

    end,
    ok.
