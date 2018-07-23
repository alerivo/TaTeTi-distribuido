-module(psocket).
-include("usuario.hrl").
-import (string, [prefix/2]).
-export([psocket/2]).

psocket(Socket,Usuario) when Usuario#usuario.psocket == undefined ->
  psocket(Socket, Usuario#usuario{psocket = self()});

psocket(Socket,Usuario) ->
  receive
    {tcp,Socket,Msg} ->
      process_flag(trap_exit, true),
      Pid = spawn_link(pcomando,pcomando,[Usuario,Msg]),
      receive
        {'EXIT',Pid,_} -> psocket(Socket,Usuario)
      end;
    {reenviar,Msg} ->
      gen_tcp:send(Socket, Msg),
      psocket(Socket,Usuario);
    {actualizar,Campo,Data} ->
      case Campo of
        jugando ->
          psocket(Socket,Usuario#usuario{jugando = Data});
        agregoObs ->
          NuevoObs = Usuario#usuario.obs ++ [Data],
          psocket(Socket,Usuario#usuario{obs = NuevoObs});
        quitoObs ->
          NuevoObs = Usuario#usuario.obs -- [Data],
          psocket(Socket,Usuario#usuario{obs = NuevoObs});
        ganadas ->
          GanadasMasUno = Usuario#usuario.ganadas + 1,
          psocket(Socket,Usuario#usuario{ganadas = GanadasMasUno});
        perdidas ->
          PerdidasMasUno = Usuario#usuario.perdidas + 1,
          psocket(Socket,Usuario#usuario{perdidas = PerdidasMasUno})
      end;
    {salir} -> gen_tcp:send(Socket, "Conexion terminada.Gracias por jugar!
      "),
               gen_tcp:shutdown(Socket, read)
  end,
  ok.
