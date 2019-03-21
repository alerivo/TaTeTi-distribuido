-module(psocket).
-include("usuario.hrl").
-import (string, [prefix/2]).
-import (lists, [nth/2]).
-export([psocket/2]).

n() ->
"
".

psocket(Usuario,Soy) when Usuario#usuario.psocket == undefined ->
  register(Soy,self()),
  Nombre = Usuario#usuario.nombre,
  usuarios ! {self(),consulta,Nombre},%Consultar disponibilidad de nombre de usuario
  Principal = nth(1,nodes()),
  receive
    {error} -> 
      {Soy,Principal} ! {reenviar_cliente, "El nombre "++Nombre++" ya existe."++n()++"Intente con uno diferente."++n()},
      {Soy,Principal} ! {reenviar_cliente, "Conexion terminada. Vuelva a intentarlo con otro nombre " ++ n()},
      {Soy,Principal} ! {cerrar};
    {ok}    ->  {Soy,Principal} ! {reenviar_cliente, "Se te asigno el nombre, puedes jugar.." ++ n()},
                psocket(Principal,Usuario#usuario{psocket = self()},Soy)
  end,
  ok.

psocket(Principal,Usuario,Soy) ->
  receive    
    {llego_mensaje,Msg} ->
      process_flag(trap_exit, true),
      Pid = spawn_link(pcomando,pcomando,[Usuario,Msg]),
      receive
        {'EXIT',Pid,_} ->
          psocket(Principal,Usuario,Soy)
      end;
    {reenviar,Msg} ->
      {Soy,Principal} ! {reenviar_cliente, Msg},
      psocket(Principal,Usuario,Soy);
    {actualizar,Campo,Data} ->
      case Campo of
        jugando -> 
          psocket(Principal,Usuario#usuario{jugando = Data},Soy);
        agregoObs ->
          NuevoObs = Usuario#usuario.obs ++ [Data],
          psocket(Principal,Usuario#usuario{obs = NuevoObs},Soy);
        quitoObs ->
          NuevoObs = Usuario#usuario.obs -- [Data],
          psocket(Principal,Usuario#usuario{obs = NuevoObs},Soy);
        ganadas ->
          GanadasMasUno = Usuario#usuario.ganadas + 1,
          psocket(Principal,Usuario#usuario{ganadas = GanadasMasUno},Soy);
        perdidas ->
          PerdidasMasUno = Usuario#usuario.perdidas + 1,
          psocket(Principal,Usuario#usuario{perdidas = PerdidasMasUno},Soy)
      end;
    {salir} -> {Soy,Principal} ! {reenviar_cliente, "Conexion terminada.Gracias jugar!"},
               {Soy,Principal} ! {cerrar}
  end,
  ok.
