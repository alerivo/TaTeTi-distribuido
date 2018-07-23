%%-----------------------------------------------------------
%% Tipo de dato: usuario
%% donde:
%%    nombre: un string que representa el nombre del usuario
%%    psocket: PID del proceso que corre el psocket asociado al usuario
%%    jugando: si esta jugando el valor es el PID de la partida, sino es undefined
%%    obs:  una lista de PIDs de las partidas que esta observando
%%    ganadas: un entero que representa la cantidad de partidas ganadas
%%    perdidas: un entero que representa la cantidad de partidas perdidas
%%------------------------------------------------------------
-record(usuario, {nombre = "", psocket , jugando , obs = [], ganadas = 0, perdidas = 0}).
