
`timescale 1ns/1ps

module encoder_display_externo_tb;

    reg [3:0] digito;
    reg enable;
    wire [6:0] segmentos;

    integer erros = 0;
    integer i;

    // Instancia do modulo
    encoder_display_externo DUT (
        .digito(digito),
        .enable(enable),
        .segmentos(segmentos)
    );

    // Funcao para obter o resultado esperado
    function [6:0] esperado;
        input [3:0] numero;
        begin
            case (numero)
                0: esperado = 7'b0000001;
                1: esperado = 7'b1001111;
                2: esperado = 7'b0010010;
                3: esperado = 7'b0000110;
                4: esperado = 7'b1001100;
                5: esperado = 7'b0100100;
                6: esperado = 7'b0100000;
                7: esperado = 7'b0001111;
                8: esperado = 7'b0000000;
                9: esperado = 7'b0000100;
                default: esperado = 7'b1111111;
            endcase
        end
    endfunction

    initial begin
        $display("========================================");
        $display(" TESTBENCH - ENCODER DISPLAY EXTERNO");
        $display("========================================");

        // Teste 1: digitos de 0 a 9
        $display("\nTESTE 1 - Digitos de 0 a 9");

        enable = 1;

        for (i = 0; i <= 9; i = i + 1) begin
            digito = i;
            #10;

            if (segmentos === esperado(digito))
                $display("[PASSOU] Digito %0d -> %07b",
                         digito, segmentos);
            else begin
                $display("[FALHOU] Digito %0d -> %07b",
                         digito, segmentos);
                erros = erros + 1;
            end
        end

        // Teste 2: display desabilitado
        $display("\nTESTE 2 - Enable = 0");

        enable = 0;
        digito = 8;
        #10;

        if (segmentos === 7'b1111111)
            $display("[PASSOU] Display apagado");
        else begin
            $display("[FALHOU] Display nao apagou");
            erros = erros + 1;
        end

        // Teste 3: digitos invalidos
        $display("\nTESTE 3 - Digitos invalidos");

        enable = 1;

        for (i = 10; i <= 15; i = i + 1) begin
            digito = i;
            #10;

            if (segmentos === 7'b1111111)
                $display("[PASSOU] Digito %0d ignorado", digito);
            else begin
                $display("[FALHOU] Digito %0d", digito);
                erros = erros + 1;
            end
        end

        $display("\n========================================");

        if (erros == 0)
            $display(" TODOS OS TESTES PASSARAM!");
        else
            $display(" %0d TESTE(S) FALHARAM!", erros);

        $display("========================================");

        $finish;
    end

endmodule
