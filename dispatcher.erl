-module(dispatcher).
-include("usuario.hrl").
-import (string, [prefix/2]).
-export([lanzar_dispatcher/0]).

n() ->
"
".

envie_con() ->
"Envie \"CON nombre\", si el nombre esta
disponible se le asignara un servidor.
".

lanzar_dispatcher() ->
  {ok, SocketEscucha} = gen_tcp:listen(8000, [{active, true}]),%Escuchar en el puerto 8000
  esperar_cliente(SocketEscucha),
  ok.

esperar_cliente(SocketEscucha) ->
  {ok, NuevoCliente} = gen_tcp:accept(SocketEscucha),%Aceptar una conexion
  spawn(?MODULE, esperar_cliente, [SocketEscucha]),
  gen_tcp:send(NuevoCliente, "Conexion establecida."++n()++envie_con()),
  atender(NuevoCliente),%Atender conexion
  ok.

atender(Cliente) ->
  receive
    {tcp,Cliente,Msg} ->
      case prefix(Msg, "CON ") of
        nomatch ->
          gen_tcp:send(Cliente, "Comando incorrecto."++n()++envie_con()),
          atender(Cliente);
        Nombre  ->
          usuarios ! {self(),consulta,Nombre},%Consultar disponibilidad de nombre de usuario
          receive
            {error} -> 
              gen_tcp:send(Cliente, "El nombre "++Nombre++" ya existe."++n()++"Intente con uno diferente."++n()),
              atender(Cliente);
            {ok}    -> 
              pbalance ! {dame_servidor,self()},%Pedir un servidor
              receive
                {toma, Nodo} ->
                  Usuario = #usuario{nombre = Nombre},
                  spawn(Nodo,psocket,psocket,[Cliente,Usuario])%Lanza psocket en el nodo menos cargado
              end
          end 
      end
    after 120000 -> gen_tcp:send(Cliente, "Tiempo de espera excedido. Conexion cerrada."++n()),
                    gen_tcp:shutdown(Cliente, read)
  end,
  ok.
