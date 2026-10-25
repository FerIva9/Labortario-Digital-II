`timescale 1ns/1ps
// Teste do top em Verilog-2005. Nao incluir na sintese da FPGA.
module fabula_tea_tb;
    reg clock = 0;
    always #10 clock = ~clock; // 50 MHz

    reg reset = 1, contar = 0, recontar = 0, relembrar = 0;
    reg entrada_serial = 1;
    reg [1:0] escolhe_tamanho = 0, escolhe_historia = 2;
    wire pwm, saida_serial;
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    wire db_rx_serial, db_pronto_rx, db_jogada_feita, db_pwm;
    wire partida_serial, db_tx_serial, pronto_serial;

    fabula_tea dut (
        .clock(clock), .reset(reset),
        .contar(contar), .recontar(recontar), .relembrar(relembrar),
        .entrada_serial(entrada_serial),
        .escolhe_tamanho(escolhe_tamanho),
        .escolhe_historia(escolhe_historia),
        .pwm(pwm), .saida_serial(saida_serial),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
        .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
        .db_rx_serial(db_rx_serial), .db_pronto_rx(db_pronto_rx),
        .db_jogada_feita(db_jogada_feita), .db_pwm(db_pwm),
        .partida_serial(partida_serial), .db_tx_serial(db_tx_serial),
        .pronto_serial(pronto_serial)
    );

    integer rx_eventos = 0, tx_partidas = 0, tx_prontos = 0;
    always @(posedge clock) begin
        if (!reset) begin
            if (db_pronto_rx) rx_eventos = rx_eventos + 1;
            if (partida_serial) tx_partidas = tx_partidas + 1;
            if (pronto_serial) tx_prontos = tx_prontos + 1;
            if (db_rx_serial !== entrada_serial || db_pwm !== pwm ||
                db_tx_serial !== saida_serial) begin
                $display("FAIL: sinais de depuracao nao acompanham os pinos");
                $finish;
            end
        end
    end

    function [6:0] hex7;
        input [3:0] valor;
        begin
            case (valor)
                4'd0: hex7 = 7'b1000000;
                4'd1: hex7 = 7'b1111001;
                4'd2: hex7 = 7'b0100100;
                4'd3: hex7 = 7'b0110000;
                4'd4: hex7 = 7'b0011001;
                4'd5: hex7 = 7'b0010010;
                4'd6: hex7 = 7'b0000010;
                default: hex7 = 7'b1111111;
            endcase
        end
    endfunction

    task verificar;
        input condicao;
        input [767:0] mensagem;
        begin
            if (condicao !== 1'b1) begin
                $display("FAIL: %0s", mensagem);
                $finish;
            end
        end
    endtask

    task enviar_cartao;
        input [6:0] ascii;
        integer b;
        begin
            wait(dut.UC.habilitaJogada);
            @(negedge clock); entrada_serial = 0; #8680;
            for (b=0; b<7; b=b+1) begin
                entrada_serial = ascii[b]; #8680;
            end
            entrada_serial = ^ascii; #8680;
            entrada_serial = 1; #17360;
        end
    endtask

    integer i;
    initial begin
        #1; reset = 0; #1; reset = 1;
        repeat (4) @(negedge clock);
        reset = 0;
        @(negedge clock);
        verificar(HEX0 == 7'b1000000 && HEX1 == 7'b1000000 &&
                  HEX2 == 7'b1000000 && HEX3 == 7'b1000000 &&
                  HEX4 == 7'b1000000 && HEX5 == 7'b1000000,
                  "displays devem mostrar zero apos reset");

        contar = 1;
        @(negedge clock); contar = 0;
        wait(dut.UC.habilitaJogada);
        @(negedge clock);
        verificar(HEX0 == 7'b0100100 && HEX3 == 7'b1111001 &&
                  HEX4 == 7'b0110000 && HEX5 == 7'b1000000,
                  "historia 2, contando, estado 03");

        for (i=0; i<4; i=i+1) begin
            enviar_cartao(7'h33+i); // personagens 3, 4, 5, 6 (ultimo invalido)
            if (i==3) begin
                verificar(rx_eventos == 4, "RX deve registrar tambem caractere invalido");
                verificar(tx_partidas == 18, "caractere invalido nao deve iniciar TX");
                enviar_cartao("3"); // quarto personagem valido
            end
            wait(tx_prontos == 6*(i+1));
            if (i<3) begin
                wait(dut.UC.habilitaJogada);
                @(negedge clock);
                verificar(HEX2 == hex7(i+1), "endereco avanca apos mensagem");
            end
        end
        wait(dut.UC.recontando && dut.UC.habilitaJogada);
        @(negedge clock);
        verificar(rx_eventos == 5 && tx_partidas == 24 && tx_prontos == 24,
                  "um quadro por personagem valido");
        verificar(HEX0 == 7'b0100100 && HEX1 == 7'b0110000 &&
                  HEX2 == 7'b1000000 && HEX3 == 7'b0100100 &&
                  HEX4 == 7'b0000010 && HEX5 == 7'b1111001,
                  "displays ao entrar em recontagem");
        $display("PASS: top, seis displays, RX valido/invalido, TX e sinais de depuracao");
        $finish;
    end
    initial begin
        #8000000;
        $display("FAIL: timeout do top");
        $finish;
    end
endmodule
