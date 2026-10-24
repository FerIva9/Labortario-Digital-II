`timescale 1ns/1ns

module tx_serial_7E1_tb;
    reg       clock_in;
    reg       reset_in;
    reg       partida_in;
    reg [6:0] dados_ascii_7_in;
    wire      saida_serial_out;
    wire      pronto_out;
    wire      db_partida_out;
    wire      db_saida_serial_out;
    wire [3:0] db_estado_out;

    reg [6:0] vetor_teste [0:3];
    integer caso;

    tx_serial_7E1 dut (
        .clock           (clock_in),
        .reset           (reset_in),
        .partida         (partida_in),
        .dados_ascii     (dados_ascii_7_in),
        .saida_serial    (saida_serial_out),
        .pronto          (pronto_out),
        .db_partida      (db_partida_out),
        .db_saida_serial (db_saida_serial_out),
        .db_estado       (db_estado_out)
    );

    // Clock de 50 MHz: periodo de 20 ns.
    always #10 clock_in = ~clock_in;

    initial begin
        clock_in = 0;
        reset_in = 0;
        partida_in = 0;
        dados_ascii_7_in = 0;
        caso = 0;

        // Dados e paridades esperadas: 35h -> 0, 55h -> 0,
        // 7Eh -> 0, 7Fh -> 1 (paridade par).
        vetor_teste[0] = 7'h35;
        vetor_teste[1] = 7'h55;
        vetor_teste[2] = 7'h7e;
        vetor_teste[3] = 7'h7f;

        // Reset inicial.
        @(negedge clock_in);
        reset_in = 1;
        #100;
        reset_in = 0;
        #1000;

        for (caso = 0; caso < 4; caso = caso + 1) begin
            @(negedge clock_in);
            dados_ascii_7_in = vetor_teste[caso];

            // Partida de um unico ciclo de clock (20 ns).
            @(negedge clock_in);
            partida_in = 1;
            @(negedge clock_in);
            partida_in = 0;

            // Tempo para observar o quadro completo, pronto e repouso.
            // Intervalo fixo: o teste avanca mesmo se pronto nao aparecer.
            #120000; // 120 us
        end

        $stop;
    end
endmodule
