module controle_servo_8(
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
    .largura_000 (35000),   // 0,700 ms — 20°
    .largura_001 (45700),   // 0,914 ms — 40°
    .largura_010 (56450),   // 1,129 ms — 60°
    .largura_011 (67150),   // 1,343 ms — 80°
    .largura_100 (77850),   // 1,557 ms — 100°
    .largura_101 (88550),   // 1,771 ms — 120°
    .largura_110 (99300),   // 1,986 ms — 140°
    .largura_111 (110000)   // 2,200 ms — 160°
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