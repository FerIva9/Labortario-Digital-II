
`timescale 1ns/1ps

module interface_teclado_tb;

    // --------------------------------------------------
    // Sinais do testbench
    // --------------------------------------------------

    reg clock = 0;
    reg reset = 1;

    wire [3:0] C;
    wire [3:0] L;
    wire [3:0] tecla;
    wire tecla_valida;

    // Matriz de 16 teclas:
    // indice = linha * 4 + coluna
    reg [15:0] pressionadas = 16'b0;

    integer erros = 0;
    integer total_eventos = 0;
    reg [3:0] ultima_tecla = 0;

    integer i;
    integer j;

    reg [3:0] colunas_simuladas;

    // --------------------------------------------------
    // Clock de 50 MHz
    // --------------------------------------------------

    always #10 clock = ~clock;

    // --------------------------------------------------
    // Simulacao eletrica do teclado matricial
    // --------------------------------------------------

    always @(*) begin
        colunas_simuladas = 4'b1111;

        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                if (pressionadas[i*4+j] &&
                    L[i] === 1'b0) begin
                    colunas_simuladas[j] = 1'b0;
                end
            end
        end
    end

    assign C = colunas_simuladas;

    // --------------------------------------------------
    // Instancia do DUT
    // --------------------------------------------------

    interface_teclado #(
        .DEBOUNCE_DELAY(100)
    ) DUT (
        .clock(clock),
        .reset(reset),
        .C(C),
        .L(L),
        .tecla(tecla),
        .tecla_valida(tecla_valida)
    );

    // --------------------------------------------------
    // Monitor dos eventos
    // --------------------------------------------------

    always @(posedge clock) begin
        if (!reset && tecla_valida) begin
            total_eventos = total_eventos + 1;
            ultima_tecla = tecla;

            $display(
                "[EVENTO] Tempo=%0t | Tecla=%0d | L=%b | C=%b",
                $time, tecla, L, C
            );
        end
    end

    // --------------------------------------------------
    // Aguarda N ciclos
    // --------------------------------------------------

    task aguarda_ciclos;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1)
                @(negedge clock);
        end
    endtask

    // --------------------------------------------------
    // Teste de uma tecla
    // --------------------------------------------------

    task testa_tecla;
        input integer linha;
        input integer coluna;
        input [3:0] esperado;

        integer eventos_antes;

        begin
            $display(
                "\n[TESTE] Pressionando linha=%0d coluna=%0d",
                linha+1, coluna+1
            );

            eventos_antes = total_eventos;

            pressionadas[linha*4+coluna] = 1'b1;

            // Tempo suficiente para debounce e varredura
            aguarda_ciclos(300);

            if ((total_eventos == eventos_antes + 1) &&
                (ultima_tecla == esperado)) begin
                $display(
                    "[PASSOU] Tecla %0d reconhecida uma vez",
                    esperado
                );
            end else begin
                $display(
                    "[FALHOU] Esperado=%0d | Lido=%0d | Eventos=%0d",
                    esperado, ultima_tecla,
                    total_eventos-eventos_antes
                );
                erros = erros + 1;
            end

            // Mantem a tecla pressionada
            aguarda_ciclos(300);

            if (total_eventos == eventos_antes + 1) begin
                $display("[PASSOU] Sem repeticao ao segurar");
            end else begin
                $display("[FALHOU] Tecla repetida ao segurar");
                erros = erros + 1;
            end

            // Solta todas as teclas
            pressionadas = 16'b0;
            aguarda_ciclos(300);
        end
    endtask

    // --------------------------------------------------
    // Teste de duas teclas simultaneas
    // --------------------------------------------------

    task testa_multiplas;
        integer eventos_antes;

        begin
            $display("\n[TESTE] Duas teclas simultaneas");

            eventos_antes = total_eventos;

            // Teclas 1 e 2
            pressionadas[0] = 1'b1;
            pressionadas[1] = 1'b1;

            aguarda_ciclos(300);

            if (total_eventos == eventos_antes) begin
                $display("[PASSOU] Multiplas teclas rejeitadas");
            end else begin
                $display("[FALHOU] Multiplas teclas aceitas");
                erros = erros + 1;
            end

            pressionadas = 16'b0;
            aguarda_ciclos(300);
        end
    endtask

    // --------------------------------------------------
    // Sequencia principal de testes
    // --------------------------------------------------

    initial begin
        $display("======================================");
        $display(" TESTBENCH - INTERFACE TECLADO 4x4");
        $display("======================================");

        aguarda_ciclos(5);
        reset = 0;
        aguarda_ciclos(10);

        // Teste das teclas numericas
        testa_tecla(0, 0, 4'd1);
        testa_tecla(0, 1, 4'd2);
        testa_tecla(0, 2, 4'd3);

        testa_tecla(1, 0, 4'd4);
        testa_tecla(1, 1, 4'd5);
        testa_tecla(1, 2, 4'd6);

        testa_tecla(2, 0, 4'd7);
        testa_tecla(2, 1, 4'd8);
        testa_tecla(2, 2, 4'd9);

        testa_tecla(3, 1, 4'd0);

        // Repeticao da mesma tecla apos soltura
        $display("\n[TESTE] Repeticao apos soltura");
        testa_tecla(1, 1, 4'd5);
        testa_tecla(1, 1, 4'd5);

        // Teclas especiais
        testa_tecla(0, 3, 4'd10); // A
        testa_tecla(1, 3, 4'd11); // B
        testa_tecla(2, 3, 4'd12); // C
        testa_tecla(3, 3, 4'd13); // D
        testa_tecla(3, 0, 4'd14); // *
        testa_tecla(3, 2, 4'd15); // #

        // Pressionamento simultaneo
        testa_multiplas();

        $display("\n======================================");

        if (erros == 0)
            $display("RESULTADO FINAL: TODOS OS TESTES PASSARAM");
        else
            $display("RESULTADO FINAL: %0d FALHAS", erros);

        $display("======================================");

        $finish;
    end

    // Protecao contra simulacao travada
    initial begin
        #1000000;
        $display("[ERRO] Timeout da simulacao!");
        $finish;
    end

endmodule
