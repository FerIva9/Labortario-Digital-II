module controle_servo(
    input        clock,
    input        reset,
    input  [1:0] posicao,
    output wire   controle,
    output wire db_controle
);

circuito_pwm #(  
    .conf_periodo(1000000  ),  // T=20ms
    .largura_00  (0      ),  // pulso=0
    .largura_01  (50000   ),  // pulso de 1ms
    .largura_10  (75000                             ),  // pulso de 1.5ms
    .largura_11  (100000   )   // pulso de 2ms
) pwm (
    .clock   (clock      ),
    .reset   (reset      ),
    .largura (posicao    ),
    .pwm     (controle   ),
    .db_pwm  (db_controle)
);

endmodule