
`timescale 1ns/1ps

module fabula_tea_tb;

    reg clock = 0;
    always #10 clock = ~clock; // 50 MHz

    reg reset = 0;
    reg contar = 0;
    reg recontar = 0;
    reg relembrar = 0;
    reg escolhe_tamanho = 0;
    reg [1:0] escolhe_historia = 0;
    reg [3:0] C = 4'b1111;
    reg entrada_serial = 1;

    wire [3:0] L;
    wire [6:0] display_dezena;
    wire [6:0] display_unidade;
    wire selecionando_tamanho;

    integer erros = 0;

    // Instancia do TOP completo
    fabula_tea dut (
        .clock(clock),
        .reset(reset),
        .contar(contar),
        .recontar(recontar),
        .relembrar(relembrar),
        .escolhe_tamanho(escolhe_tamanho),
        .escolhe_historia(escolhe_historia),
        .C(C),
        .L(L),
        .entrada_serial(entrada_serial),

        .display_dezena(display_dezena),
        .display_unidade(display_unidade),
        .selecionando_tamanho(selecionando_tamanho)
    );

    // Aguarda alguns ciclos
    task espera;
        input integer ciclos;
        integer k;
        begin
            for (k = 0; k < ciclos; k = k + 1)
                @(negedge clock);
            #1;
        end
    endtask

    // Inicia a selecao de tamanho pela UC
    task iniciar_selecao;
        begin
            @(negedge clock);
            force dut.escolhe_tamanho_db = 1'b1;

            espera(2);

            release dut.escolhe_tamanho_db;
            espera(4);

            if (selecionando_tamanho === 1'b1 &&
                display_dezena === 7'b1111111 &&
                display_unidade === 7'b1111111)
                $display("[PASSOU] Selecao iniciada: displays apagados");
            else begin
                $display("[FALHOU] Displays deveriam estar apagados");
                erros = erros + 1;
            end
        end
    endtask

    // Simula uma tecla numerica ja decodificada
    task digitar;
        input [3:0] numero;
        begin
            @(negedge clock);

            force dut.FD.tecla = numero;
            force dut.FD.tecla_valida = 1'b1;

            // Um ciclo para reconhecer a tecla
            // e outro para registrar o digito
            espera(2);

            release dut.FD.tecla_valida;
            release dut.FD.tecla;

            espera(2);
        end
    endtask

    // Confere tamanho e segmentos apresentados
    task verificar;
        input integer tamanho;
        input [6:0] dezena_esperada;
        input [6:0] unidade_esperada;
        begin
            espera(4);

            $display("Tamanho: %0d | Limite: %0d",
                     tamanho, dut.db_tamanhohistoria);

            $display("Dezena: %07b | Unidade: %07b",
                     display_dezena, display_unidade);

            if (dut.db_tamanhohistoria === tamanho-1 &&
                display_dezena === dezena_esperada &&
                display_unidade === unidade_esperada &&
                dut.habilita_displays === 1'b1) begin

                $display("[PASSOU] Historia de %0d personagens",
                         tamanho);
            end
            else begin
                $display("[FALHOU] Historia de %0d personagens",
                         tamanho);
                erros = erros + 1;
            end
        end
    endtask

    initial begin
        $display("========================================");
        $display(" TESTBENCH TOP - FABULA TEA+");
        $display("========================================");

        // Reset direto no sinal tratado:
        // nao espera os 20 ms do debounce
        $display("\nTESTE 1 - Reset");

        force dut.reset_db = 1'b1;
        espera(4);
        release dut.reset_db;
        espera(3);

        if (display_dezena === 7'b1111111 &&
            display_unidade === 7'b1111111)
            $display("[PASSOU] Displays apagados apos reset");
        else begin
            $display("[FALHOU] Reset dos displays");
            erros = erros + 1;
        end

        // --------------------------------------
        // Teste 2: tamanho 25
        // --------------------------------------
        $display("\nTESTE 2 - Historia de 25");

        iniciar_selecao();
        digitar(4'd2);
        digitar(4'd5);

        verificar(25, 7'b0010010, 7'b0100100);

        // --------------------------------------
        // Teste 3: tamanho 99
        // --------------------------------------
        $display("\nTESTE 3 - Historia de 99");

        iniciar_selecao();
        digitar(4'd9);
        digitar(4'd9);

        verificar(99, 7'b0000100, 7'b0000100);

        // --------------------------------------
        // Teste 4: tamanho invalido 00
        // --------------------------------------
        $display("\nTESTE 4 - Historia de 00 (invalida)");

        iniciar_selecao();
        digitar(4'd0);
        digitar(4'd0);

        espera(4);

        if (selecionando_tamanho === 1'b1 &&
            display_dezena === 7'b1111111 &&
            display_unidade === 7'b1111111 &&
            dut.db_tamanhohistoria === 7'd98)
            $display("[PASSOU] Tamanho 00 rejeitado");
        else begin
            $display("[FALHOU] Tamanho 00 nao foi rejeitado");
            erros = erros + 1;
        end

        // --------------------------------------
        // Teste 5: tamanho 01
        // A UC ja voltou a esperar a dezena
        // apos rejeitar 00.
        // --------------------------------------
        $display("\nTESTE 5 - Historia de 01");

        digitar(4'd0);
        digitar(4'd1);

        verificar(1, 7'b0000001, 7'b1001111);

        // --------------------------------------
        // Resultado
        // --------------------------------------
        $display("\n========================================");

        if (erros == 0)
            $display(" TODOS OS TESTES PASSARAM!");
        else
            $display(" %0d TESTE(S) FALHARAM!", erros);

        $display("========================================");

        $finish;
    end

    // Protecao contra simulacao travada
    initial begin
        #100000;
        $display("[ERRO] Timeout da simulacao");
        $finish;
    end

endmodule
