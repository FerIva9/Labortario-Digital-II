`timescale 1ns/1ns

module mux_8x1_n_tb;
    parameter BITS = 7;
    reg [BITS-1:0] entradas [0:7];
    reg [2:0] sel;
    wire [BITS-1:0] saida;
    integer canal, valor, j;
    integer testes, erros, erros_antes;

    mux_8x1_n #(.BITS(BITS)) dut (
        .D0(entradas[0]),
        .D1(entradas[1]),
        .D2(entradas[2]),
        .D3(entradas[3]),
        .D4(entradas[4]),
        .D5(entradas[5]),
        .D6(entradas[6]),
        .D7(entradas[7]),
        .SEL(sel),
        .MUX_OUT(saida)
    );

    task verifica;
        input [BITS-1:0] esperado;
        begin
            #1;
            testes = testes + 1;
            if (saida !== esperado) begin
                erros = erros + 1;
                $display("ERRO: SEL=%b, esperado=%h, obtido=%h",
                         sel, esperado, saida);
            end
        end
    endtask

    initial begin
        testes = 0;
        erros = 0;
        sel = 0;
        for (j = 0; j < 8; j = j + 1)
            entradas[j] = 0;

        for (canal = 0; canal < 8; canal = canal + 1) begin
            sel = canal;
            erros_antes = erros;
            for (valor = 0; valor < (2**BITS); valor = valor + 1) begin
                for (j = 0; j < 8; j = j + 1)
                    entradas[j] = valor + j + 1;
                entradas[canal] = valor;
                verifica(valor);

                // Muda somente as entradas nao selecionadas.
                for (j = 0; j < 8; j = j + 1)
                    if (j != canal)
                        entradas[j] = ~entradas[j];
                verifica(valor);
            end

            // O mux tambem deve propagar X/Z da entrada selecionada.
            entradas[canal] = {BITS{1'bx}};
            verifica({BITS{1'bx}});
            entradas[canal] = {BITS{1'bz}};
            verifica({BITS{1'bz}});

            if (erros == erros_antes)
                $display("PASSOU: SEL=%b seleciona D%0d e ignora as demais entradas.", sel, canal);
        end

        // Confere o comportamento definido para selecao desconhecida.
        sel = 3'bx01;
        verifica({BITS{1'bx}});
        sel = 3'bz10;
        verifica({BITS{1'bx}});

        $display("Resultado: BITS=%0d, verificacoes=%0d, erros=%0d", BITS, testes, erros);
        if (erros == 0)
            $display("SUCESSO: todos os testes passaram.");
        else
            $display("FALHA: multiplexador apresentou erros.");

        // Extensao do Icarus: codigo de saida nao zero em caso de falha.
        `ifdef __ICARUS__
            $finish_and_return(erros != 0);
        `else
            $finish;
        `endif
    end
endmodule
