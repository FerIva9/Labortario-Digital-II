`timescale 1ns/1ns

module controle_servo_8_tb;
    reg clock;
    reg reset;
    reg [2:0] posicao;
    wire controle;
    wire db_reset;
    wire [2:0] db_posicao;
    wire db_controle;
    integer caso;

    controle_servo_8 dut (
        .clock(clock),
        .reset(reset),
        .posicao(posicao),
        .controle(controle),
        .db_reset(db_reset),
        .db_posicao(db_posicao),
        .db_controle(db_controle)
    );

    // Clock de 50 MHz: periodo de 20 ns.
    always #10 clock = ~clock;

    initial begin
        clock = 0;
        reset = 1;
        posicao = 0;

        // Mantem o reset por 100 ns.
        #100;
        reset = 0;

        // Percorre as oito posicoes, mantendo cada uma por 60 ms.
        // A nova largura e aplicada na virada do periodo PWM (20 ms).
        // Observe os pulsos apos essa atualizacao.
        for (caso = 0; caso < 8; caso = caso + 1) begin
            posicao = caso;
            #60000000;
        end

        $stop;
    end
endmodule
