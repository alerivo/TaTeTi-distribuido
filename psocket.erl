-module(psocket).
-import (string, [prefix/2]).
-export([psocket/2]).
-include("usuario.hrl").

psocket(Cliente,Usuario) when Usuario#usuario.psocket == undefined ->
  psocket(Cliente, Usuario#usuario{psocket = self()});


psocket(Cliente,Usuario)->
  receive
    {tcp,Cliente,Msg} ->
      process_flag(trap_exit, true),
      Pid = spawn_link(pcomando,pcomando,[Usuario,Msg]),
      receive
        {'EXIT',Pid,_} -> psocket(Cliente,Usuario)
      end;
    {reenviar, Msg,Usuario2} ->
      gen_tcp:send(Cliente, Msg),
      psocket(Cliente,Usuario2);
    {salir} -> gen_tcp:send(Cliente, "Conexion terminada.Gracias por jugar!
      "),
               gen_tcp:shutdown(Cliente, read)
  end,
  ok.