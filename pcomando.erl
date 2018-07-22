-module(pcomando).
-import(string,[slice/3,slice/2,to_integer/1,split/3]).
-import(lists,[map/2,filter/2]).
-export([pcomando/2]).
-include("usuario.hrl").



verific(Msg)-> EsEspacio = slice(Msg,3,4) == " ",
                     if
                      EsEspacio ->
                           {Id,_} = to_integer(slice(Msg,4))
                      end,
                      Id.

respError(Psocket)-> respError(Psocket).                    




pcomando(Usuario,Msg)->
  Psocket = Usuario#usuario.psocket,
  Nombre = Usuario#usuario.nombre,
  case slice(Msg,0,3) of
    "LSG" ->
       partidas ! {solicito_info,self()},
       receive
          {info,Msg2} -> Psocket ! {reenviar,Msg2,Usuario}
       end;

    "NEW" ->
       partidas ! {solicito_crear,{Nombre,Psocket},self()},
       receive
          {ok,Msg2,Usuario2} -> Psocket ! {reenviar,Msg2,Usuario2}
       end;

    "ACC" -> 
       case verific(Msg) of
              error -> respError(Psocket);
              Id    -> partidas ! {solicito_acceder,Usuario, Id,self()},
                       receive
                          {rta, Rta} -> Psocket ! {reenviar,Rta,Usuario}
                       end
       end;
     

    "PLA" -> 
   %Verificar comando
        case slice(Msg,3,4) == " " of
          true  -> ok;
          false -> respError(Psocket),
                  exit("Comando incorrecto")
        end,
        Temp = split(slice(Msg,4)," ",all),
        case length(Temp) of
          3 -> ok;
          _ -> respError(Psocket),
                  exit("Comando incorrecto")
        end,
        Temp2 = map(fun(X)->string:to_integer(X) end,Temp),
        Temp3 = filter(fun({X,_})-> X == error end, Temp2),
        case length(Temp3)of
         0 -> ok;
         _ -> respError(Psocket),
                  exit("Comando incorrecto")
        end,
        Temp4 = filter(fun({_,Y})-> Y == [] end, Temp2),
        case length(Temp4)of
         3 -> ok;
         _ -> respError(Psocket),
                  exit("Comando incorrecto")
         end,       
    %Fin de verificación
        [Id,Fil,Col] = map(fun({X,_})->X end,Temp2),
        partidas ! {solicito_jugar,{Nombre,Psocket},Id,Fil,Col},
        receive
          {ok,Msg3} -> Psocket ! {reenviar,Msg3}
        end;



    "OBS" ->
      case verific(Msg) of
              error -> respError(Psocket);
              Id    -> partidas ! {solicito_observar,Usuario, Id,self()},
                       receive
                          {rta, Rta,Usuario2} -> Psocket ! {reenviar,Rta,Usuario2}
                       end
      end;


    "LEA" ->
      case verific(Msg) of
              error -> respError(Psocket);
              Id    -> partidas ! {solicito_no_observar,Usuario, Id,self()},
                       receive
                          {rta, Rta,Usuario2} -> Psocket ! {reenviar,Rta,Usuario2}
                       end
      end;

    "BYE" ->
      case length(Msg) of
        3 -> 
          partidas ! {salir,Usuario},
          usuarios ! {eliminar,Nombre},
          Psocket ! {salir};
        _ -> respError(Psocket)
      end
  end,
  ok.