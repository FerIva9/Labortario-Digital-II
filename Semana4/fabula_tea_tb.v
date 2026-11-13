`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// fabula_tea_tb.v - Testbench integrado, autoverificavel
// Uso: Icarus Verilog (-g2012) ou ModelSim/Questa (vlog -sv)
// NAO sintetizar este arquivo.
// -----------------------------------------------------------------------------
module fabula_tea_tb;

    reg clock = 1'b0;
    always #10 clock = ~clock; // 50 MHz

    reg reset = 1'b0;
    reg contar = 1'b0;
    reg recontar = 1'b0;
    reg relembrar = 1'b0;
    reg escolhe_tamanho = 1'b0;
    reg [1:0] escolhe_historia = 2'd2;
    reg entrada_serial = 1'b1;

    // Modelo de uma tecla fisica pressionada, com resistores pull-up
    // nas quatro colunas. Linhas nao selecionadas ficam em Z.
    reg pressionada = 1'b0;
    reg [1:0] linha_pressionada = 2'd0;
    reg [1:0] coluna_pressionada = 2'd0;
    tri1 [3:0] C;
    wire [3:0] L;

    assign C[0] = (pressionada && coluna_pressionada == 2'd0 &&
                    L[linha_pressionada] === 1'b0) ? 1'b0 : 1'bz;
    assign C[1] = (pressionada && coluna_pressionada == 2'd1 &&
                    L[linha_pressionada] === 1'b0) ? 1'b0 : 1'bz;
    assign C[2] = (pressionada && coluna_pressionada == 2'd2 &&
                    L[linha_pressionada] === 1'b0) ? 1'b0 : 1'bz;
    assign C[3] = (pressionada && coluna_pressionada == 2'd3 &&
                    L[linha_pressionada] === 1'b0) ? 1'b0 : 1'bz;

    wire pwm, saida_serial, acertou, errou, contando, recontando;
    wire relembrando, selecionando_tamanho;
    wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5;
    wire db_rx_serial, db_pronto_rx, db_jogada_feita, db_pwm;
    wire partida_serial, db_tx_serial, pronto_serial;

    fabula_tea dut (
        .clock(clock), .reset(reset),
        .contar(contar), .recontar(recontar), .relembrar(relembrar),
        .entrada_serial(entrada_serial),
        .escolhe_tamanho(escolhe_tamanho),
        .escolhe_historia(escolhe_historia),
        .C(C), .L(L),
        .pwm(pwm), .saida_serial(saida_serial),
        .acertou(acertou), .errou(errou), .contando(contando),
        .recontando(recontando), .relembrando(relembrando),
        .selecionando_tamanho(selecionando_tamanho),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2),
        .HEX3(HEX3), .HEX4(HEX4), .HEX5(HEX5),
        .db_rx_serial(db_rx_serial), .db_pronto_rx(db_pronto_rx),
        .db_jogada_feita(db_jogada_feita), .db_pwm(db_pwm),
        .partida_serial(partida_serial), .db_tx_serial(db_tx_serial),
        .pronto_serial(pronto_serial)
    );

    // Reduz somente o tempo de debounce e o timer do modo relembrar.
    // Nao altera os arquivos do projeto nem a velocidade das UARTs.
    defparam dut.FD.InterfaceTeclado.DEBOUNCE_DELAY = 100;
    defparam dut.FD.timerExibicao.M = 8;

    integer verificacoes = 0;
    integer pulsos_teclado = 0;
    integer rx_eventos = 0;
    integer tx_partidas = 0;
    integer tx_prontos = 0;

    // Monitor de eventos. Os contadores nao sao zerados durante os testes.
    always @(posedge clock) begin
        if (!reset) begin
            if (dut.FD.tecla_valida) pulsos_teclado = pulsos_teclado + 1;
            if (db_pronto_rx) rx_eventos = rx_eventos + 1;
            if (partida_serial) tx_partidas = tx_partidas + 1;
            if (pronto_serial) tx_prontos = tx_prontos + 1;
        end
    end

    function [6:0] hex7;
        input [3:0] valor;
        begin
            case (valor)
                4'h0: hex7 = 7'b1000000;
                4'h1: hex7 = 7'b1111001;
                4'h2: hex7 = 7'b0100100;
                4'h3: hex7 = 7'b0110000;
                4'h4: hex7 = 7'b0011001;
                4'h5: hex7 = 7'b0010010;
                4'h6: hex7 = 7'b0000010;
                4'h7: hex7 = 7'b1111000;
                4'h8: hex7 = 7'b0000000;
                4'h9: hex7 = 7'b0010000;
                4'ha: hex7 = 7'b0001000;
                4'hb: hex7 = 7'b0000011;
                4'hc: hex7 = 7'b1000110;
                4'hd: hex7 = 7'b0100001;
                4'he: hex7 = 7'b0000110;
                4'hf: hex7 = 7'b0001110;
            endcase
        end
    endfunction

    task verificar;
        input condicao;
        input [8*140-1:0] mensagem;
        begin
            verificacoes = verificacoes + 1;
            if (condicao !== 1'b1) begin
                $display("[FALHOU] %0s | tempo=%0t ns | estado=%0d | modo=%0d",
                         mensagem, $time, dut.db_estado, dut.FD.modoReg_w);
                $fatal(1, "Falha no testbench integrado");
            end
        end
    endtask

    // Verifica todos os seis displays e os sinais de depuracao.
    task verificar_displays;
        begin
            #1;
            verificar(HEX0 === hex7({2'b00, dut.db_historia}), "HEX0 - historia");
            verificar(HEX1 === hex7({1'b0, dut.db_personagem}), "HEX1 - personagem");
            verificar(HEX2 === hex7(dut.db_contagem), "HEX2 - contador");
            verificar(HEX3 === hex7(dut.situacao), "HEX3 - situacao");
            verificar(HEX4 === hex7(dut.db_estado[3:0]), "HEX4 - estado baixo");
            verificar(HEX5 === hex7({1'b0, dut.db_estado[6:4]}), "HEX5 - estado alto");
            verificar(db_rx_serial === entrada_serial &&
                      db_pwm === pwm && db_tx_serial === saida_serial,
                      "Espelhos de depuracao");
        end
    endtask

    task pulso_contar;
        begin
            @(negedge clock); contar = 1'b1;
            @(negedge clock); contar = 1'b0;
        end
    endtask

    task pulso_relembrar;
        begin
            @(negedge clock); relembrar = 1'b1;
            @(negedge clock); relembrar = 1'b0;
        end
    endtask

    task iniciar_selecao;
        begin
            @(negedge clock); escolhe_tamanho = 1'b1;
            @(negedge clock); escolhe_tamanho = 1'b0;
            wait(dut.db_estado == 7'd61); // espera_dezena
            @(negedge clock);
            verificar(selecionando_tamanho && HEX3 === hex7(4'd6),
                      "Entrada na selecao, status 6");
            $display("[INFO] Selecao iniciada em t=%0t ns", $time);
        end
    endtask

    // Mapeamento fisico das teclas do teclado matricial HX-543.
    // A=10, B=11, C=12, D=13; *=14, #=15.
    task pressionar_tecla;
        input integer codigo;
        integer antes;
        begin
            case (codigo)
                 1: begin linha_pressionada=0; coluna_pressionada=0; end
                 2: begin linha_pressionada=0; coluna_pressionada=1; end
                 3: begin linha_pressionada=0; coluna_pressionada=2; end
                10: begin linha_pressionada=0; coluna_pressionada=3; end
                 4: begin linha_pressionada=1; coluna_pressionada=0; end
                 5: begin linha_pressionada=1; coluna_pressionada=1; end
                 6: begin linha_pressionada=1; coluna_pressionada=2; end
                11: begin linha_pressionada=1; coluna_pressionada=3; end
                 7: begin linha_pressionada=2; coluna_pressionada=0; end
                 8: begin linha_pressionada=2; coluna_pressionada=1; end
                 9: begin linha_pressionada=2; coluna_pressionada=2; end
                12: begin linha_pressionada=2; coluna_pressionada=3; end
                14: begin linha_pressionada=3; coluna_pressionada=0; end
                 0: begin linha_pressionada=3; coluna_pressionada=1; end
                15: begin linha_pressionada=3; coluna_pressionada=2; end
                13: begin linha_pressionada=3; coluna_pressionada=3; end
                default: $fatal(1, "Codigo de tecla inexistente: %0d", codigo);
            endcase
            antes = pulsos_teclado;
            @(negedge clock); pressionada = 1'b1;
            repeat (250) @(negedge clock);
            verificar(pulsos_teclado == antes + 1,
                      "Uma tecla mantida deve gerar exatamente um evento");
            verificar(dut.FD.tecla === codigo,
                      "Decodificacao da tecla fisica");
            pressionada = 1'b0;
            repeat (150) @(negedge clock);
            $display("[TECLA] %0d reconhecida", codigo);
        end
    endtask

    task digitar_tamanho;
        input integer numero;
        begin
            pressionar_tecla(numero / 10);
            pressionar_tecla(numero % 10);
            repeat (4) @(negedge clock);
        end
    endtask

    task conferir_tamanho;
        input integer numero;
        reg [3:0] limite_esperado;
        begin
            if (numero >= 16) limite_esperado = 4'd15;
            else limite_esperado = numero - 1;
            verificar(dut.db_estado == 7'd0, "Retorno ao estado inicial");
            verificar(dut.FD.modoReg_w === limite_esperado,
                      "RegModo armazena o limite escolhido");
            verificar(dut.UC.tamanho_configurado === 1'b1,
                      "Flag tamanho_configurado retida");
            verificar(selecionando_tamanho === 1'b0,
                      "Saida de selecao desativada");
            verificar_displays();
            $display("[PASSOU] Tamanho %02d -> limite %0d", numero, limite_esperado);
        end
    endtask

    task enviar_cartao;
        input [6:0] ascii;
        integer b;
        begin
            wait(dut.UC.habilitaJogada === 1'b1);
            @(negedge clock); entrada_serial = 1'b0; #8680;
            for (b=0; b<7; b=b+1) begin
                entrada_serial = ascii[b]; #8680;
            end
            entrada_serial = ^ascii; #8680; // paridade par
            entrada_serial = 1'b1; #17360;
            $display("[UART RX] caractere ASCII 0x%02h enviado", ascii);
        end
    endtask

    integer partidas_antes;
    integer prontos_antes;
    integer rx_antes;

    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("fabula_tea_tb.vcd");
            $dumpvars(0, fabula_tea_tb);
        end

        $display("=====================================================");
        $display(" TESTBENCH INTEGRADO - FABULA TEA+ (TECLADO + JOGO)");
        $display("=====================================================");

        // Reset com borda definida (tambem inicializa debounce).
        #1; reset = 1'b1;
        repeat (5) @(negedge clock);
        reset = 1'b0;
        repeat (4) @(negedge clock);
        verificar(dut.db_estado == 0 && !dut.UC.tamanho_configurado,
                  "Estado inicial e flag apos reset");
        verificar(C === 4'b1111, "Pull-ups das colunas sem tecla");
        verificar_displays();

        // Nenhuma partida deve iniciar sem tamanho configurado.
        pulso_contar();
        repeat (4) @(negedge clock);
        verificar(dut.db_estado == 0 && !contando,
                  "Contar ignorado antes da primeira configuracao");
        $display("[PASSOU] Contar bloqueado apos reset");

        // 00 invalido: a UC deve limpar e retornar a espera_dezena.
        iniciar_selecao();
        digitar_tamanho(0);
        verificar(dut.db_estado == 7'd61, "00 reinicia a digitacao");
        verificar(!dut.UC.tamanho_configurado && dut.FD.modoReg_w == 0,
                  "00 nao confirma o tamanho");
        $display("[PASSOU] 00 rejeitado");

        // Digitos nao numericos sao ignorados.
        pressionar_tecla(10); // A
        verificar(dut.db_estado == 7'd61, "Tecla A ignorada");
        $display("[PASSOU] Tecla nao numerica ignorada");

        // Sem nova solicitacao: o sistema ja esta em espera_dezena.
        digitar_tamanho(1);
        conferir_tamanho(1);

        // Historia com 1 personagem: contagem + recontagem correta.
        pulso_contar();
        wait(contando && dut.UC.habilitaJogada);
        @(negedge clock);
        verificar(dut.db_estado == 7'd3 && dut.db_historia == 2,
                  "Iniciou contagem da historia 2");
        verificar_displays();
        rx_antes = rx_eventos;
        partidas_antes = tx_partidas;
        prontos_antes = tx_prontos;
        // O caractere '6' nao representa um dos seis personagens validos.
        enviar_cartao("6");
        repeat (4) @(negedge clock);
        verificar(rx_eventos == rx_antes + 1,
                  "RX recebeu caractere invalido");
        verificar(contando && dut.UC.habilitaJogada &&
                  tx_partidas == partidas_antes &&
                  tx_prontos == prontos_antes,
                  "Caractere invalido nao avanca jogo nem inicia TX");
        $display("[PASSOU] Caractere invalido ignorado");
        rx_antes = rx_eventos;
        enviar_cartao("3");
        wait(recontando && dut.UC.habilitaJogada);
        @(negedge clock);
        verificar(rx_eventos == rx_antes + 1, "RX reconheceu a jogada");
        verificar(tx_partidas == partidas_antes + 6 &&
                  tx_prontos == prontos_antes + 6,
                  "TX transmitiu 6 caracteres na contagem");
        verificar(dut.db_contagem == 0 && dut.FD.modoReg_w == 0,
                  "Historia de 1 personagem encerrou no indice zero");
        verificar_displays();
        $display("[PASSOU] Contagem de 1 personagem e quadro UART");

        enviar_cartao("3");
        wait(acertou);
        @(negedge clock);
        verificar_displays();
        verificar(dut.db_estado == 7'd39, "Fim_acertou apos recontagem correta");
        $display("[PASSOU] Recontagem correta -> fim_acertou");

        // Reconfiguracao a partir de fim_acertou.
        iniciar_selecao();
        digitar_tamanho(12);
        conferir_tamanho(12);
        iniciar_selecao();
        digitar_tamanho(99);
        conferir_tamanho(99);
        iniciar_selecao();
        digitar_tamanho(16);
        conferir_tamanho(16);
        iniciar_selecao();
        digitar_tamanho(2);
        conferir_tamanho(2);

        // Historia com 2 personagens; erro de recontagem.
        pulso_contar();
        wait(contando && dut.UC.habilitaJogada);
        enviar_cartao("3");
        wait(contando && dut.UC.habilitaJogada);
        enviar_cartao("4");
        wait(recontando && dut.UC.habilitaJogada);
        @(negedge clock);
        verificar(dut.db_contagem == 0, "Recontagem reinicia no endereco zero");
        $display("[PASSOU] Contagem de 2 personagens");

        enviar_cartao("5");
        wait(errou);
        @(negedge clock);
        verificar(dut.db_estado == 7'd40, "Fim_errou em jogada incorreta");
        verificar_displays();
        $display("[PASSOU] Recontagem incorreta -> fim_errou");

        // Relembrar: usa RAM e timer acelerado. Deve retornar a recontagem.
        pulso_relembrar();
        wait(relembrando);
        wait(recontando && dut.UC.habilitaJogada);
        @(negedge clock);
        verificar(dut.db_contagem == 0, "Relembrar retorna ao inicio da recontagem");
        verificar_displays();
        $display("[PASSOU] Relembrar percorreu memoria e retornou a recontagem");

        // Falha novamente e testa selecao partindo de fim_errou.
        enviar_cartao("5");
        wait(errou);
        @(negedge clock);
        iniciar_selecao();
        digitar_tamanho(4);
        conferir_tamanho(4);
        $display("[PASSOU] Selecao a partir de fim_errou");

        // Reset volta a bloquear o comando contar.
        @(negedge clock); reset = 1'b1;
        repeat (3) @(negedge clock);
        verificar(dut.db_estado == 0 && !dut.UC.tamanho_configurado,
                  "Reset limpa flag de configuracao");
        verificar(dut.FD.modoReg_w == 0, "Reset limpa RegModo");
        reset = 1'b0;
        pulso_contar();
        repeat (3) @(negedge clock);
        verificar(dut.db_estado == 0, "Contar novamente bloqueado apos reset");
        verificar_displays();

        $display("=====================================================");
        $display(" RESULTADO: TODOS OS TESTES PASSARAM");
        $display(" Verificacoes: %0d", verificacoes);
        $display(" Teclas reconhecidas: %0d", pulsos_teclado);
        $display(" RX: %0d | TX partidas: %0d | TX prontos: %0d",
                 rx_eventos, tx_partidas, tx_prontos);
        $display("=====================================================");
        $finish;
    end

    initial begin
        #30000000; // 30 ms, limite global de simulacao
        $fatal(1, "Timeout: algum estado/evento nao foi alcancado");
    end
endmodule
