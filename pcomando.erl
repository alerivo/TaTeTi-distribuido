-module(pcomando).
-include("usuario.hrl").
-import(string,[slice/3,slice/2,to_integer/1,split/3]).
-import(lists,[map/2,filter/2]).
-export([pcomando/2]).

n() ->
"
".

verific(Msg) ->
  EsEspacio = slice(Msg,3,4) == " ",
  case EsEspacio of
    true ->
      {Id,_} = to_integer(slice(Msg,4));
    false ->
      Id = error
  end,
  Id.

respError(Psocket)->
  Psocket ! {reenviar, "Comando incorrecto"++n()},
  ok.

pcomando(Usuario,Msg)->
  Psocket = Usuario#usuario.psocket,
  case slice(Msg,0,3) of
    "LSG" ->
       partidas ! {solicito_info,self()},
       receive
          {info,Msg2} -> Psocket ! {reenviar,Msg2}
       end;

    "NEW" ->
      case Usuario#usuario.jugando of
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
         Id ->
           partidas ! {solicito_acceder,Usuario,Id,self()},
           receive
             {rta, Rta} -> Psocket ! {reenviar,Rta}
           end
       end;

    "PLA" -> 
%Inicia verificacion de que el comando sea correcto
      case slice(Msg,3,4) == " " of
        true  -> ok;
        false ->
          respError(Psocket),
          exit("Comando incorrecto")
      end,
      Temp = split(slice(Msg,4)," ",all),
      case length(Temp) of
        3 -> ok;
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
       3 -> ok;
       _ ->
         respError(Psocket),
         exit("Comando incorrecto")
    end,       
%Fin de verificación
      [Id,Fil,Col] = map(fun({X,_}) -> X end,Temp2),
      partidas ! {solicito_jugar,Usuario,Id,Fil,Col},
      receive
        {ok,Msg3} -> Psocket ! {reenviar,Msg3}
      end;

    "OBS" ->
      case verific(Msg) of
        error -> respError(Psocket);
        Id ->
          partidas ! {solicito_observar,Usuario,Id,self()},
          receive
            {rta, Rta} -> Psocket ! {reenviar,Rta}
          end
      end;

    "LEA" ->
      case verific(Msg) of
        error -> respError(Psocket);
        Id ->
          partidas ! {solicito_no_observar,Usuario, Id,self()},
            receive
              {rta, Rta} -> Psocket ! {reenviar,Rta}
            end
      end;

    "BYE" ->
      case length(Msg) of
        3 ->
          case Usuario#usuario.jugando of
            undefined -> ok;
            PidPartidaJugando ->
              PidPartidaJugando ! {se_va_jugador,Usuario}
          end,
          MeVoy = fun(PidPartidaObservada) -> PidPartidaObservada ! {se_va_observador,Usuario} end,
          map(MeVoy, Usuario#usuario.obs),
          usuarios ! {eliminar,Usuario#usuario.nombre},
          Usuario#usuario.psocket ! {salir};
        _ -> respError(Psocket)
      end
  end,
  ok.
