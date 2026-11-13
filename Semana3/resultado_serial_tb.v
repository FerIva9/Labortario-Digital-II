`timescale 1ns/1ps
// Testa as mensagens na saida UART real. Executar na pasta Semana3:
// iverilog -g2012 -s resultado_serial_tb -o /tmp/resultado_serial_tb *.v
// vvp /tmp/resultado_serial_tb
module resultado_serial_tb;
    reg clock = 0;
    always #10 clock = ~clock;

    reg reset = 0, contar = 0, entrada_serial = 1;
    wire saida_serial, acertou, errou;
    fabula_tea dut (
        .clock(clock), .reset(reset), .contar(contar),
        .recontar(1'b0), .relembrar(1'b0),
        .entrada_serial(entrada_serial), .escolhe_tamanho(1'b0),
        .escolhe_historia(2'd2), .C(4'b1111),
        .saida_serial(saida_serial), .acertou(acertou), .errou(errou)
    );

    localparam integer BIT_NS = 8680;
    reg [6:0] esperados [0:63];
    integer total = 0, recebidos = 0, i;
    reg [6:0] dado;
    reg paridade;

    task adicionar_personagem;
        input [6:0] personagem;
        begin
            esperados[total] = "H"; total = total + 1;
            esperados[total] = "2"; total = total + 1;
            esperados[total] = ","; total = total + 1;
            esperados[total] = "P"; total = total + 1;
            esperados[total] = personagem; total = total + 1;
            esperados[total] = 7'h0a; total = total + 1;
        end
    endtask

    task adicionar_resultado;
        input [6:0] resultado;
        begin
            esperados[total] = "R"; total = total + 1;
            esperados[total] = resultado; total = total + 1;
            esperados[total] = 7'h0a; total = total + 1;
        end
    endtask

    // Amostra no centro de cada bit, independente dos sinais internos do TX.
    initial begin
        wait(reset == 1'b1);
        wait(reset == 1'b0);
        forever begin
            @(negedge saida_serial);
            #(BIT_NS/2);
            if (saida_serial !== 1'b0) $fatal(1, "Start bit invalido");
            for (i = 0; i < 7; i = i + 1) begin
                #BIT_NS; dado[i] = saida_serial;
            end
            #BIT_NS; paridade = saida_serial;
            if (paridade !== ^dado) $fatal(1, "Paridade invalida para %h", dado);
            #BIT_NS;
            if (saida_serial !== 1'b1) $fatal(1, "Stop bit invalido para %h", dado);
            if (recebidos >= total || dado !== esperados[recebidos])
                $fatal(1, "Caractere %0d: recebido %h, esperado %h", recebidos, dado, esperados[recebidos]);
            $display("[TX %0d] ASCII %02h", recebidos, dado);
            recebidos = recebidos + 1;
        end
    end

    task iniciar;
        begin
            @(negedge clock); contar = 1;
            @(negedge clock); contar = 0;
        end
    endtask

    task enviar_cartao;
        input [6:0] ascii;
        integer b;
        begin
            wait(dut.UC.habilitaJogada === 1'b1);
            @(negedge clock); entrada_serial = 0; #BIT_NS;
            for (b = 0; b < 7; b = b + 1) begin
                entrada_serial = ascii[b]; #BIT_NS;
            end
            entrada_serial = ^ascii; #BIT_NS;
            entrada_serial = 1; #(2*BIT_NS);
        end
    endtask

    initial begin
        // Duas jogadas corretas (intermediaria e final), nova partida e erro.
        adicionar_personagem("3"); adicionar_personagem("4");
        adicionar_personagem("3"); adicionar_resultado("1");
        adicionar_personagem("4"); adicionar_resultado("1");
        adicionar_personagem("3"); adicionar_personagem("4");
        adicionar_personagem("5"); adicionar_resultado("0");

        #1 reset = 1;
        repeat (5) @(negedge clock);
        reset = 0;
        // Configuracao de dois personagens; exercita UART, RAM e comparador reais.
        force dut.UC.tamanho_configurado = 1'b1;
        force dut.FD.modoReg_w = 4'd1;

        iniciar();
        enviar_cartao("3"); enviar_cartao("4");
        enviar_cartao("3"); enviar_cartao("4");
        wait(acertou);
        // Enquanto permanece em fim_acertou, nao deve retransmitir R1.
        #(15*BIT_NS);
        if (recebidos != 30) $fatal(1, "Acerto: recebidos %0d caracteres, esperados 30", recebidos);
        iniciar();
        enviar_cartao("3"); enviar_cartao("4");
        enviar_cartao("5");
        wait(errou);
        // Confere que os estados de fim nao retransmitem o resultado.
        #(15*BIT_NS);
        if (recebidos != total) $fatal(1, "Recebidos %0d de %0d caracteres", recebidos, total);
        $display("[PASSOU] Acertos intermediario e final, erro e %0d caracteres UART", recebidos);
        $finish;
    end

    initial begin
        #30000000;
        $fatal(1, "Timeout: resultado ou estado nao alcancado");
    end
endmodule
