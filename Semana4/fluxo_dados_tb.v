`timescale 1ns/1ps
// Teste do FD em Verilog-2005, com comandos que simulam a futura UC.
// Arquivo somente para simulacao; nao incluir na sintese da FPGA.
module fluxo_dados_tb;
    reg clock = 0;
    always #10 clock = ~clock;
    reg reset = 1, entrada_serial = 1;
    reg [1:0] escolhe_tamanho = 0, escolhe_historia = 2;
    reg registraModo = 0, registraHistoria = 0;
    reg zeraC = 1, contaC = 0, escreve = 0, zeraR = 1, registraR = 0;
    reg habilitaJogada = 0, registraExibicao = 0, seletorLedsBM = 0;
    reg contaExibicao = 0, zeraExibicao = 1, partida_serial = 0;
    reg [2:0] selCaracter = 0;
    wire fimHistoria, igual, jogada_feita, fimExibicao, pwm, saida_serial, pronto_serial;
    wire [5:0] db_memoria;
    wire [3:0] db_contagem;
    wire [1:0] db_tamanhohistoria;
    fluxo_dados dut (
        .clock(clock),
        .reset(reset),
        .entrada_serial(entrada_serial),
        .escolhe_tamanho(escolhe_tamanho),
        .escolhe_historia(escolhe_historia),
        .registraModo(registraModo),
        .registraHistoria(registraHistoria),
        .zeraC(zeraC),
        .contaC(contaC),
        .escreve(escreve),
        .zeraR(zeraR),
        .registraR(registraR),
        .habilitaJogada(habilitaJogada),
        .registraExibicao(registraExibicao),
        .seletorLedsBM(seletorLedsBM),
        .contaExibicao(contaExibicao),
        .zeraExibicao(zeraExibicao),
        .partida_serial(partida_serial),
        .selCaracter(selCaracter),
        .fimHistoria(fimHistoria),
        .igual(igual),
        .jogada_feita(jogada_feita),
        .fimExibicao(fimExibicao),
        .pwm(pwm),
        .saida_serial(saida_serial),
        .pronto_serial(pronto_serial),
        .db_memoria(db_memoria),
        .db_contagem(db_contagem),
        .db_tamanhohistoria(db_tamanhohistoria)
    );
    // Somente o tempo de exibicao e reduzido; UART e PWM usam tempos reais.
    defparam dut.timerExibicao.M = 8;
    integer eventos = 0;
    reg consomeJogada = 1;
    // UC minima: confirma a pendencia com um pulso de registraR.
    always @(posedge clock) begin
        if (reset) registraR <= 0;
        else registraR <= consomeJogada && jogada_feita && !registraR;
        if (!reset && !zeraR && dut.recebeJogada_w) eventos <= eventos + 1;
    end
    task check(input condition, input [511:0] message);
        if (condition !== 1'b1) begin
            $display("FAIL: %0s", message);
            $finish;
        end
    endtask
    task tick;
        @(negedge clock);
    endtask
    task envia(input [6:0] dado, input erro_paridade);
        integer b;
        begin
            tick; entrada_serial = 0; #8680;
            for (b=0; b<7; b=b+1) begin entrada_serial = dado[b]; #8680; end
            entrada_serial = (^dado) ^ erro_paridade; #8680;
            entrada_serial = 1; #17360;
        end
    endtask
    task apresenta;
        begin tick; registraExibicao=1; tick; registraExibicao=0; end
    endtask
    task avanca;
        begin tick; contaC=1; tick; contaC=0; tick; end
    endtask
    task grava;
        begin tick; escreve=1; tick; escreve=0; tick; end
    endtask
    task transmite(input [2:0] indice, input [6:0] esperado);
        reg [6:0] recebido;
        reg paridade;
        integer b;
        begin
            fork
                begin
                    tick; selCaracter=indice; partida_serial=1;
                    tick; partida_serial=0;
                end
                begin
                    @(negedge saida_serial);
                    #13020;
                    for (b=0; b<7; b=b+1) begin recebido[b]=saida_serial; #8680; end
                    paridade=saida_serial; #8680;
                    check(saida_serial === 1'b1, "TX: stop bit");
                    check(recebido === esperado, "TX: caractere incorreto");
                    check(paridade === (^esperado), "TX: paridade incorreta");
                end
            join
            wait(pronto_serial); tick; tick;
        end
    endtask
    integer k;
    time inicio, largura, periodo;
    initial begin
        #1; reset=0; #1; reset=1;
        repeat(4) tick;
        reset=0; zeraR=0; zeraC=0; registraModo=1; registraHistoria=1;
        tick; registraModo=0; registraHistoria=0; habilitaJogada=1;
        check(db_contagem === 0 && db_tamanhohistoria === 0, "Inicializacao do nucleo");
        // Seis personagens: recepcao, registro, escrita e apresentacao.
        for(k=0; k<6; k=k+1) begin
            envia(7'h30+k, 0);
            check(eventos == k+1, "RX: evento ausente ou repetido");
            check(dut.muxDecoder_w === (6'b1 << k), "RX: codigo da jogada");
            grava;
            check(db_memoria === (6'b1 << k) && igual, "RAM: escrita/comparacao");
            check(fimHistoria === (k==3), "Fim da sequencia de quatro");
            apresenta;
            check(dut.posicao_w === k[2:0], "Apresentacao da jogada atual");
            if(k<5) avanca;
        end
        envia("5", 0);
        check(eventos == 7, "RX: personagem repetido deve gerar nova jogada");
        envia("A", 0); envia("2", 1);
        habilitaJogada=0; envia("1", 0);
        check(eventos == 7 && dut.muxDecoder_w === 6'b100000, "Rejeicao de RX invalido/desabilitado");
        // A UC pode demorar: uma segunda recepcao nao sobrescreve a primeira.
        tick; consomeJogada=0; habilitaJogada=1;
        envia("2", 0);
        check(jogada_feita && dut.jogada_rx_w === 6'b000100, "Pendencia nao foi registrada");
        repeat(10) tick;
        check(jogada_feita, "Pendencia deve permanecer ativa sem registraR");
        envia("1", 0);
        check(eventos == 8 && jogada_feita && dut.jogada_rx_w === 6'b000100,
              "Segunda recepcao sobrescreveu jogada pendente");
        tick; consomeJogada=1; repeat(4) tick;
        check(!jogada_feita && dut.registrador_w === 6'b000100,
              "registraR deve consumir a primeira jogada e limpar pendencia");
        // Apos o consumo, outro cartao pode ser aceito; zeraR cancela a pendencia.
        consomeJogada=0; envia("3",0);
        check(eventos == 9 && jogada_feita, "Nao aceitou nova jogada apos consumo");
        tick; zeraR=1; tick;
        check(!jogada_feita && dut.jogada_rx_w === 0, "zeraR nao limpou pendencia");
        zeraR=0; consomeJogada=1; habilitaJogada=0;
        // Invalidos nao alteram a apresentacao.
        tick; zeraR=1; tick; zeraR=0; apresenta;
        check(dut.posicao_w === 3'd5, "Personagem invalido mudou apresentacao");
        // Relembrar: todos os personagens devem vir da memoria.
        tick; zeraC=1; seletorLedsBM=1; tick; zeraC=0; tick;
        for(k=0; k<6; k=k+1) begin
            check(dut.muxDecoder_w === (6'b1 << k), "RAM: leitura para relembrar");
            apresenta;
            check(dut.posicao_w === k[2:0], "Apresentacao da memoria");
            if(k<5) avanca;
        end
        // A captura da historia nao acompanha mudancas nas chaves.
        escolhe_historia=3;
        transmite(0,"H"); transmite(1,"2"); transmite(2,",");
        transmite(3,"P"); transmite(4,"5"); transmite(5,7'h0A);
        apresenta; transmite(4,"5"); // mesma posicao, nova transmissao
        // Timer: habilitacao, terminal e limpeza.
        tick; zeraExibicao=0; contaExibicao=1;
        repeat(7) tick;
        check(fimExibicao, "Timer: fim apos sete incrementos (M=8)");
        contaExibicao=0; repeat(3) tick;
        check(fimExibicao, "Timer: pausa");
        zeraExibicao=1; tick;
        check(!fimExibicao && dut.Q_wire_exibicao === 0, "Timer: limpeza");
        // Aguarda estabilizacao do PWM na ultima posicao, mede pulso e periodo.
        repeat(3) @(posedge pwm);
        inicio=$time;
        @(negedge pwm); largura=$time-inicio;
        @(posedge pwm); periodo=$time-inicio;
        check(largura == 2253580, "PWM: largura para posicao 5");
        check(periodo == 20000000, "PWM: periodo de 20 ms");
        $display("PASS: RX, repeticao, invalidos, RAM, comparacao, apresentacao, TX, timer e PWM");
        $finish;
    end
    initial begin
        #120000000;
        $display("FAIL: Timeout");
        $finish;
    end
endmodule
