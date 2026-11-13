
`timescale 1ns/1ps

module conversor_tamanho_tb;

    reg [3:0] dezena;
    reg [3:0] unidade;

    wire [3:0] limite;
    wire tamanho_valido;

    integer erros = 0;
    integer testes = 0;

    // --------------------------------------------------
    // Instancia do DUT
    // --------------------------------------------------

    conversor_tamanho DUT (
        .dezena(dezena),
        .unidade(unidade),
        .limite(limite),
        .tamanho_valido(tamanho_valido)
    );

    // --------------------------------------------------
    // Teste automatico de um numero decimal
    // --------------------------------------------------

    task testa_tamanho;
        input integer numero;

        reg [3:0] limite_esperado;
        reg valido_esperado;

        begin
            dezena = numero / 10;
            unidade = numero % 10;

            if (numero == 0) begin
                limite_esperado = 4'd0;
                valido_esperado = 1'b0;
            end
            else if (numero >= 16) begin
                limite_esperado = 4'd15;
                valido_esperado = 1'b1;
            end
            else begin
                limite_esperado = numero - 1;
                valido_esperado = 1'b1;
            end

            #10;

            testes = testes + 1;

            if ((limite === limite_esperado) &&
                (tamanho_valido === valido_esperado)) begin

                $display(
                    "[PASSOU] Entrada=%02d | Limite=%04b (%0d) | Valido=%b",
                    numero, limite, limite, tamanho_valido
                );

            end else begin

                $display(
                    "[FALHOU] Entrada=%02d | Limite=%04b | Esperado=%04b | Valido=%b | Esperado=%b",
                    numero, limite, limite_esperado,
                    tamanho_valido, valido_esperado
                );

                erros = erros + 1;
            end
        end
    endtask

    // --------------------------------------------------
    // Sequencia principal
    // --------------------------------------------------

    integer i;

    initial begin
        $display("========================================");
        $display(" TESTBENCH - CONVERSOR DE TAMANHO");
        $display("========================================");

        // Casos especiais
        testa_tamanho(0);
        testa_tamanho(1);
        testa_tamanho(4);
        testa_tamanho(8);
        testa_tamanho(12);
        testa_tamanho(15);
        testa_tamanho(16);
        testa_tamanho(17);
        testa_tamanho(25);
        testa_tamanho(99);

        // Teste exaustivo: 00 ate 99
        $display("\n--- TESTE EXAUSTIVO (00 A 99) ---");

        for (i = 0; i <= 99; i = i + 1) begin
            testa_tamanho(i);
        end

        $display("\n========================================");
        $display(" TOTAL DE TESTES: %0d", testes);
        $display(" TOTAL DE ERROS:  %0d", erros);

        if (erros == 0)
            $display(" RESULTADO FINAL: TODOS OS TESTES PASSARAM");
        else
            $display(" RESULTADO FINAL: TESTES FALHARAM");

        $display("========================================");

        $finish;
    end

endmodule
