// Controle de seis posicoes, com clock de 50 MHz e periodo de 20 ms.
// Angulos nominais: 15, 45, 75, 105, 135 e 165 graus.
// Pulsos estimados pela reta do controlador anterior:
// 20 graus = 35000 ciclos; 160 graus = 110000 ciclos.
// Os extremos 15 e 165 graus sao extrapolados. Calibrar no servo real.
// Parametros em ciclos de clock permitem ajustar cada posicao na bancada.
module controle_servo_6 #(
    parameter PULSO_15  = 32321,
    parameter PULSO_45  = 48393,
    parameter PULSO_75  = 64464,
    parameter PULSO_105 = 80536,
    parameter PULSO_135 = 96607,
    parameter PULSO_165 = 112679
)(
    input                clock,
    input                reset,
    input         [2:0]  posicao,
    output wire          controle,
    output wire          db_reset,
    output wire   [2:0]  db_posicao,
    output wire          db_controle
);

circuito_pwm #(  
    .conf_periodo(1000000), // 20 ms a 50 MHz
    .largura_000 (PULSO_15),   // posicao 0: aproximadamente 0,64642 ms
    .largura_001 (PULSO_45),   // posicao 1: aproximadamente 0,96786 ms
    .largura_010 (PULSO_75),   // posicao 2: aproximadamente 1,28928 ms
    .largura_011 (PULSO_105),  // posicao 3: aproximadamente 1,61072 ms
    .largura_100 (PULSO_135),  // posicao 4: aproximadamente 1,93214 ms
    .largura_101 (PULSO_165),  // posicao 5: aproximadamente 2,25358 ms
    .largura_110 (PULSO_15),   // codigo invalido: retorna a posicao 0
    .largura_111 (PULSO_15)    // codigo invalido: retorna a posicao 0
) pwm (
    .clock   (clock      ),
    .reset   (reset      ),
    .largura (posicao    ),
    .pwm     (controle   ),
    .db_pwm  (db_controle)
);

assign db_reset   = reset;
assign db_posicao = posicao;

endmodule
