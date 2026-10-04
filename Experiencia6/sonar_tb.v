`timescale 1ns/1ns

module sonar_tb;
    reg clock_in;
    reg reset_in;
    reg ligar_in;
    reg echo_in;
    reg entrada_serial_in;

    wire trigger_out;
    wire pwm_out;
    wire saida_serial_out;
    wire fim_posicao_out;
    wire db_modo_out;
    wire [6:0] medida0_out;
    wire [6:0] medida1_out;
    wire [6:0] medida2_out;
    wire [6:0] db_posicao_out;
    wire [6:0] db_estado0_out;
    wire db_estado1_out;
    wire db_medir_out;
    wire db_pronto_serial_out;
    wire db_serial_out;
    wire db_trigger_out;
    wire db_echo_out;

    reg [31:0] casos_echo [0:11];
    reg [31:0] largura_echo_ns;
    reg [2:0] posicoes_esperadas [0:11];
    integer caso;
    integer bordas_pwm;

    localparam integer BIT_TIME_NS = 8680;

    sonar dut (
        .clock             (clock_in),
        .reset             (reset_in),
        .ligar             (ligar_in),
        .echo              (echo_in),
        .entrada_serial    (entrada_serial_in),
        .sel_mux           (2'b00),
        .trigger           (trigger_out),
        .pwm               (pwm_out),
        .saida_serial      (saida_serial_out),
        .fim_posicao       (fim_posicao_out),
        .medida0           (medida0_out),
        .medida1           (medida1_out),
        .medida2           (medida2_out),
        .db_posicao        (db_posicao_out),
        .db_estado0        (db_estado0_out),
        .display5          (),
        .db_estado1        (db_estado1_out),
        .db_estado2        (),
        .db_modo           (db_modo_out),
        .db_medir          (db_medir_out),
        .db_pronto_serial  (db_pronto_serial_out),
        .db_serial         (db_serial_out),
        .db_trigger        (db_trigger_out),
        .db_echo           (db_echo_out)
    );

    // Intervalo reduzido para 400 us apenas nesta simulacao.
    defparam dut.FD.TIMER_2SEG.M = 20_000;

    always #10 clock_in = ~clock_in;

    always @(posedge pwm_out)
        bordas_pwm = bordas_pwm + 1;

    task envia_caractere_7e1;
        input [6:0] caractere;
        integer bit_index;
        reg bit_paridade;
        begin
            bit_paridade = ^caractere;
            @(negedge clock_in);
            entrada_serial_in = 1'b0;
            #(BIT_TIME_NS);
            for (bit_index = 0; bit_index < 7; bit_index = bit_index + 1) begin
                entrada_serial_in = caractere[bit_index];
                #(BIT_TIME_NS);
            end
            entrada_serial_in = bit_paridade;
            #(BIT_TIME_NS);
            entrada_serial_in = 1'b1;
            #(BIT_TIME_NS);
        end
    endtask

    task verifica_modo;
        input modo_esperado;
        integer ciclos;
        begin
            ciclos = 0;
            while ((db_modo_out !== modo_esperado) && (ciclos < 100)) begin
                @(posedge clock_in);
                ciclos = ciclos + 1;
            end
            if (db_modo_out !== modo_esperado) begin
                $display("FALHA: modo esperado %0d, recebido %0d",
                         modo_esperado, db_modo_out);
                $fatal(1);
            end
        end
    endtask

    initial begin
        clock_in = 1'b0;
        reset_in = 1'b0;
        ligar_in = 1'b0;
        echo_in = 1'b0;
        entrada_serial_in = 1'b1;
        caso = 0;
        bordas_pwm = 0;

        $dumpfile("sonar_exp6_tb.vcd");
        $dumpvars(0, reset_in, ligar_in, echo_in, trigger_out, pwm_out,
              entrada_serial_in, fim_posicao_out, db_modo_out, db_medir_out,
              db_posicao_out, medida0_out, medida1_out, medida2_out);

        // Caso 0: varredura normal na posicao 000.
        // Casos 1 a 3: tres medicoes em atencao, sem avancar posicao.
        // Apos enviar 'v', os demais casos completam a varredura.
        casos_echo[0] = 5882;
        casos_echo[1] = 5899;
        casos_echo[2] = 4353;
        casos_echo[3] = 4399;
        casos_echo[4] = 5882;
        casos_echo[5] = 5899;
        casos_echo[6] = 4353;
        casos_echo[7] = 4399;
        casos_echo[8] = 4353;
        casos_echo[9] = 5882;
        casos_echo[10] = 5899;
        casos_echo[11] = 4353;

        posicoes_esperadas[0] = 3'd0;
        posicoes_esperadas[1] = 3'd1;
        posicoes_esperadas[2] = 3'd1;
        posicoes_esperadas[3] = 3'd1;
        posicoes_esperadas[4] = 3'd1;
        posicoes_esperadas[5] = 3'd2;
        posicoes_esperadas[6] = 3'd3;
        posicoes_esperadas[7] = 3'd4;
        posicoes_esperadas[8] = 3'd5;
        posicoes_esperadas[9] = 3'd6;
        posicoes_esperadas[10] = 3'd7;
        posicoes_esperadas[11] = 3'd0;

        // Reset inicial.
        @(negedge clock_in);
        reset_in = 1'b1;
        repeat (2) @(negedge clock_in);
        reset_in = 1'b0;

        // Aguarda 100 us antes de ligar e mais 100 us para iniciar os ciclos.
        #100_000;
        ligar_in = 1'b1;
        #100_000;

        for (caso = 0; caso < 12; caso = caso + 1) begin
            largura_echo_ns = casos_echo[caso] * 1000;

            wait (trigger_out == 1'b1);
            if (dut.FD.s_posicao !== posicoes_esperadas[caso]) begin
                $display("FALHA: caso %0d na posicao %0d; esperada %0d",
                         caso + 1, dut.FD.s_posicao, posicoes_esperadas[caso]);
                $fatal(1);
            end
            if (caso == 11)
                $display("Volta completa: nova medida na posicao 20 graus (000), echo %0d us",
                         casos_echo[caso]);
            else if (caso >= 1 && caso <= 3)
                $display("Caso %0d: modo atencao, medicao %0d de 3 na posicao 40 graus, echo de %0d us",
                         caso + 1, caso, casos_echo[caso]);
            else if (caso == 4)
                $display("Caso %0d: modo varredura retomado em 40 graus, echo de %0d us",
                         caso + 1, casos_echo[caso]);
            else
                $display("Caso %0d: posicao %0d, echo de %0d us",
                         caso + 1, 20 + 20 * posicoes_esperadas[caso],
                         casos_echo[caso]);

            #400_000; // 400 us entre trigger e echo.
            echo_in = 1'b1;
            #largura_echo_ns;
            echo_in = 1'b0;

            wait (fim_posicao_out == 1'b1);
            if (caso == 11)
                $display("Medida concluida em 20 graus: %0d%0d%0d cm",
                         dut.s_medida[11:8], dut.s_medida[7:4], dut.s_medida[3:0]);
            else
                $display("Fim do caso %0d", caso + 1);

            if (caso >= 1 && caso <= 3) begin
                if (dut.FD.s_posicao !== posicoes_esperadas[caso]) begin
                    $display("FALHA: medicao %0d no modo atencao avancou a posicao para %0d",
                             caso, dut.FD.s_posicao);
                    $fatal(1);
                end
            end else if (dut.FD.s_posicao !== (posicoes_esperadas[caso] + 3'd1)) begin
                $display("FALHA: posicao apos caso %0d: recebida %0d, esperada %0d",
                         caso + 1, dut.FD.s_posicao,
                         posicoes_esperadas[caso] + 3'd1);
                $fatal(1);
            end

            #100_000; // Intervalo entre casos de teste.

            if (caso == 0) begin
                envia_caractere_7e1(7'h61); // 'a'
                verifica_modo(1'b1);
                $display("PASSOU: caractere 'a' ativou o modo de atencao para 3 medicoes");
            end else if (caso == 3) begin
                envia_caractere_7e1(7'h76); // 'v'
                verifica_modo(1'b0);
                $display("PASSOU: apos 3 medicoes, caractere 'v' retomou o modo de varredura");
            end
        end

        // Desligar deve impedir o proximo ciclo de medicao.
        ligar_in = 1'b0;

        // Aguarda 100 us conforme o roteiro do testbench.
        repeat (5_000) begin
            @(posedge clock_in);
            #1;
            if (trigger_out !== 1'b0 || db_medir_out !== 1'b0) begin
                $display("FALHA: sonar iniciou outra medicao com LIGAR desativado");
                $fatal(1);
            end
        end

        // Observa mais um ciclo completo do temporizador reduzido para simulacao.
        repeat (20_000) begin
            @(posedge clock_in);
            #1;
            if (trigger_out !== 1'b0 || db_medir_out !== 1'b0) begin
                $display("FALHA: sonar iniciou outra medicao com LIGAR desativado");
                $fatal(1);
            end
        end

        if (bordas_pwm == 0) begin
            $display("FALHA: nenhuma borda PWM foi gerada para o servo");
            $fatal(1);
        end

        $display("PASSOU: %0d pulsos PWM observados; sonar parado com LIGAR=0", bordas_pwm);
        $finish;
    end

    initial begin
        #100_000_000;
        $display("FALHA: timeout; estado=%0d timer=%0d/%0d sensor=%0d medir=%b gera=%b zera=%b",
                 dut.UC.Eatual, dut.FD.TIMER_2SEG.Q,
                 dut.FD.TIMER_2SEG.M, dut.FD.db_estado_sensor,
                 dut.s_medir, dut.FD.SENSOR.s_gera, dut.FD.SENSOR.s_zera);
        $fatal(1);
    end
endmodule
