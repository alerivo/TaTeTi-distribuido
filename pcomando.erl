-module(pcomando).
-include("usuario.hrl").
-import(string,[slice/3,slice/2,to_integer/1,split/3]).
-import(lists,[map/2,filter/2,sublist/2]).
-export([pcomando/2]).

n() ->
"
".

verific(Msg) ->
  EsEspacio = slice(Msg,3,1) == " ",
  case EsEspacio of
    true ->
      Id = slice(Msg,4);
    false ->
      Id = error
  end,
  Id.

respError(Psocket)->
  Psocket ! {reenviar, "Comando incorrecto"++n()},
  ok.

pcomando(Usuario,Msg1)->
  Psocket = Usuario#usuario.psocket,
  Partida = Usuario#usuario.jugando,
  Msg = sublist(Msg1,length(Msg1)-2),
  case slice(Msg,0,3) of
    "LSG" ->
       partidas ! {solicito_info,self()},
       receive
          {info,Msg2} -> Psocket ! {reenviar,Msg2}
       end;

    "NEW" ->
      case Partida of
        undefined -> % Usuario no esta jugando ninguna partida
          partidas ! {solicito_crear,Usuario,self()},
          receive
            {ok,Msg2,PidNuevaPartida} ->
              Psocket ! {actualizar,jugando,PidNuevaPartida},
              Psocket ! {reenviar,Msg2}
         end;
        _ -> % Usuario ya esta jugando una partida
          Psocket ! {reenviar,"Ya estas jugando una partida"++n()}
      end;

    "ACC" ->
       case verific(Msg) of
         error -> respError(Psocket);
         Id ->  case Partida of
                  undefined ->  partidas ! {solicito_acceder,Usuario,Id,self()},
                                receive
                                   {error, Rta} -> Psocket ! {reenviar,Rta};
                                   {ok,PidPartida} -> Psocket ! {actualizar,jugando,PidPartida},
                                                      Psocket ! {reenviar,"Te uniste a la partida" ++ n()}
                                end
                end
       end;

    "PLA" ->
%Inicia verificacion de que el comando sea correcto
      case Partida of 
        undefined -> Psocket ! {reenviar,"Deberías estar jugando una partida" ++ n()};
        _ -> ok
      end,
      case slice(Msg,3,1) == " " of
        true  -> ok;
        false ->
          respError(Psocket),
          exit("Comando incorrecto")
      end,
      Temp = split(slice(Msg,4)," ",all),
      case length(Temp) of
        2 -> ok;
        _ ->
          respError(Psocket),
          exit("Comando incorrecto")
      end,
      Temp2 = map(fun(X)->string:to_integer(X) end,Temp),
      Temp3 = filter(fun({X,_})-> X == error end, Temp2),
      case length(Temp3)of
       0 -> ok;
       _ ->
        respError(Psocket),
        exit("Comando incorrecto")
      end,
      Temp4 = filter(fun({_,Y})-> Y == [] end, Temp2),
      case length(Temp4)of
       2 -> ok;
       _ ->
         respError(Psocket),
         exit("Comando incorrecto")
    end,       
%Fin de verificación
      [Fil,Col] = map(fun({X,_}) -> X end,Temp2),
      Partida ! {solicito_jugar,Usuario,Fil,Col};

    "OBS" ->
      case verific(Msg) of
        error -> respError(Psocket);
        Id ->
          partidas ! {solicito_observar,Usuario,Id}
      end;

    "LEA" ->
      case verific(Msg) of
        error -> respError(Psocket);
        Id ->
          partidas ! {solicito_no_observar,Usuario, Id,self()}
      end;

    "BYE" ->
      case length(Msg) of
        3 ->
          case Partida of
            undefined -> ok;
            PidPartidaJugando ->
              PidPartidaJugando ! {se_va_jugador,Usuario} %% Se va de la partida
          end,
          MeVoy = fun(PidPartidaObservada) -> PidPartidaObservada ! {se_va_observador,Usuario} end,
          map(MeVoy, Usuario#usuario.obs),%% Avisa que se va a todas las partidas que observaba
          usuarios ! {eliminar,Usuario#usuario.nombre}, %% Lo elimina de los usuarios
          Usuario#usuario.psocket ! {salir}; %% Cierra el socket
        _ -> respError(Psocket)
      end;

    _  ->  respError(Psocket)
  end,
  ok.
