%% Archivo: usuario.hrl

%%-----------------------------------------------------------
%% Tipo de dato: usuario
%% donde:
%%    nombre: un string que representa el nombre de usuario
%%    psocket:   pid de psocket asociado al usuario
%%    jugando: si esta jugando el valor es el pid de la partida, sino es undefined
%%    obs:  una lista de pid de las partidas observadas
%%    ganadas: un entero que representa la cantidad de partidas ganadas
%%    perdidas: un entero que representa la cantidad de partidas perdidas
%%------------------------------------------------------------
-record(usuario, {nombre = "", psocket , jugando , obs = [], ganadas = 0, perdidas = 0}).