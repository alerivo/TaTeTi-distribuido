-module(dispatcher).
-include("usuario.hrl").
-import (string, [prefix/2]).
-import (lists, [sublist/2]).
-export([lanzar_dispatcher/0,esperar_cliente/2,atender/2]).

n() ->
"
".

envie_con() ->
"Envie \"CON nombre\", si el nombre esta
disponible se le asignara un servidor.
".

lanzar_dispatcher() ->
  {ok, SocketEscucha} = gen_tcp:listen(8000, [{active, true}]),%Escuchar en el puerto 8000
  esperar_cliente(SocketEscucha,1),
  ok.

esperar_cliente(SocketEscucha,N) ->
  {ok, NuevoCliente} = gen_tcp:accept(SocketEscucha),%Aceptar una conexion
  gen_tcp:send(NuevoCliente, "Conexion establecida."++n()++envie_con()),
  Soy = list_to_atom(integer_to_list(N)),
  Atender = spawn(?MODULE,atender,[NuevoCliente,Soy]),%Atender conexion
  gen_tcp:controlling_process(NuevoCliente,Atender),
  register(Soy,Atender), 
  esperar_cliente(SocketEscucha,N+1),
  ok.

atender(Cliente,Soy) ->
  receive
    {tcp,Cliente,Msg} ->
      case prefix(Msg, "CON ") of
        nomatch ->
          gen_tcp:send(Cliente, "Comando incorrecto."++n()++envie_con()),
          atender(Cliente,Soy);
        Nombre1  -> 
          Nombre = sublist(Nombre1,length(Nombre1)-2),  
          pbalance ! {dame_servidor,self()},%Pedir un servidor
          receive
            {toma, Nodo} ->
              io:format("El cliente ~p se conecta al nodo ~p~n",[Soy,Nodo]),
              Usuario = #usuario{nombre = Nombre},
              spawn(Nodo,psocket,psocket,[Usuario,Soy]),%Lanza psocket en el nodo menos cargado
              comunicacion(Cliente,Soy,Nodo)
          end
      end
    after 120000 ->
      gen_tcp:send(Cliente, "Tiempo de espera excedido. Conexion cerrada."++n()),
      gen_tcp:shutdown(Cliente, read)
  end,
  ok.



comunicacion(Cliente,Soy,Nodo) ->
  receive 
    {reenviar_cliente,Rta} -> 
      gen_tcp:send(Cliente,Rta),
      comunicacion(Cliente,Soy,Nodo);
    {cerrar} ->
      gen_tcp:shutdown(Cliente, read);
    {tcp,Cliente,Msg} -> 
      {Soy,Nodo} ! {llego_mensaje,Msg},
      comunicacion(Cliente,Soy,Nodo)
  end,
ok.
