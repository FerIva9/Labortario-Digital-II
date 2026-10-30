//------------------------------------------------------------------
// Arquivo   : fluxo_dados.v
// Projeto   : Fluxo de dados do jogo Fábula TEA+
//------------------------------------------------------------------
// Descricao : RFID via UART, memoria de jogadas, servo e UART do monitor
//          
//------------------------------------------------------------------
// Revisoes  :
//     Data        Versao  Autor                 Descricao
//     29/01/2026  1.0     Thiago Martins      versao inicial
//     31/01/2026  1.1     Fernando Ivanov       revisão
//     31/01/2026  1.2     Guilherme Muller    correcao de erros
//     05/02/2026  1.3     Guilherme Muller    adaptado para Experimento 5
//     20/02/2026  1.4     Fernando Ivanov     adaptado para Experimento 6
//     14/03/2026  2.0     Fernando Ivanov     adaptado para Semana1
//     21/03/2026  2.1     Thiago Martins      adaptado para Semana2
//     24/10/2026  2.2     Fernando Ivanov     adaptado para LabDigII
//------------------------------------------------------------------
//


module fluxo_dados (
    // ENTRADAS:
    input [1:0] escolhe_tamanho,
    input registraModo, // sinal que permite o registro do modo de jogo
    input clock, // sinal de clock
    input reset, // reset geral das interfaces e dos novos registradores
    input entrada_serial, // UART da ESP8266: 115200 baud, 7E1 a 50 MHz
    input [1:0] escolhe_historia,
    input registraHistoria,
    input habilitaJogada,
    input registraExibicao,
    input [2:0] selCaracter,
    input partida_serial,
    input zeraC, // sinal que zera contador de jogadas
    input contaC, // sinal que conta no contador de jogadas
    input escreve, // sinal que permite escrita na ram
    input zeraR,  // limpa a jogada e o registrador de entrada
    input registraR,  // captura a jogada recebida em registradorBotoes
    input contaExibicao, // sinal que permite a contagem do contador do timer
    input zeraExibicao,  // sinal que zera o contador do timer
    input seletorLedsBM, // 0: jogada registrada; 1: personagem da RAM


    // SAÍDAS


    output fimHistoria, // sinal que indica o fim da historia
    output igual, // jogada registrada igual ao personagem da RAM
    output jogada_feita, // jogada pendente; permanece ativa ate registraR
    output fimExibicao, // sinal que indica que houve fim dos 2 segundos
    output pwm,
    output saida_serial,
    output pronto_serial, // fim de UM caractere, nao da mensagem inteira


    // SINAIS DE DEPURAÇÃO

    output [3:0] db_contagem,
    output [5:0] db_memoria,
    output [1:0] db_tamanhohistoria,
    output [1:0] db_historia, // historia registrada para HEX0
    output [2:0] db_personagem, // posicao apresentada para HEX1
    output db_pronto_rx // conclusao de um caractere recebido

);


    // Fios de conexão 

    wire [3:0] modoMux_w;
    wire [1:0] modoReg_w;
    wire [3:0] contador_w;
    wire [5:0] registrador_w;
    wire [5:0] memoriaData_w;
    wire [5:0] muxDecoder_w;
    wire ALBoJ_w;
    wire AGBoJ_w;
    wire ALBoL_w;
    wire AGBoL_w;
    wire [26:0] Q_wire_exibicao;
    wire meio_wire_exibicao;
    wire fimC;
    wire [6:0] dados_ascii_rx_w;
    wire pronto_rx_w, paridade_par_rx_w, caractere_valido_w;
    wire [5:0] jogada_decodificada_w, jogada_rx_w;
    wire zeraEntrada_w;
    wire recebeJogada_w, atualizaJogada_w;
    wire [2:0] posicao_decodificada_w, posicao_w;
    wire personagem_valido_w, carregaExibicao_w;
    wire [1:0] historia_w;
    wire [6:0] historia_ascii_w, personagem_ascii_w, dados_ascii_tx_w;




    // COMPONENTES:
    
    rx_serial_7E1 RX_SERIAL (
        .clock(clock), .reset(reset), .RX(entrada_serial),
        .pronto(pronto_rx_w), .dados_ascii(dados_ascii_rx_w),
        .paridade_par(paridade_par_rx_w), .paridade(),
        .db_clock(), .db_tick(), .db_estado()
    );

    decodificadorASCII decodificadorJogada (
        .ascii(dados_ascii_rx_w),
        .jogada(jogada_decodificada_w), .valido(caractere_valido_w)
    );

    // AND de cinco entradas do desenho: a realimentacao vem da SAIDA
    // REGISTRADA de RegJogadaFeita, impedindo sobrescrever uma jogada pendente.
    assign recebeJogada_w = pronto_rx_w & paridade_par_rx_w &
                           caractere_valido_w & habilitaJogada & ~jogada_feita;
    assign zeraEntrada_w = reset | zeraR;
    assign atualizaJogada_w = recebeJogada_w | registraR;

    registrador_6 RegEntrada (
        .clock(clock), .clear(zeraEntrada_w), .enable(recebeJogada_w),
        .D(jogada_decodificada_w), .Q(jogada_rx_w)
    );

    // Recepcao aceita grava 1. registraR copia RegEntrada para
    // registradorBotoes e grava 0 na pendencia, na mesma borda de clock.
    registrador_n #(.N(1)) RegJogadaFeita (
        .clock(clock), .clear(zeraEntrada_w), .enable(atualizaJogada_w),
        .D(recebeJogada_w), .Q(jogada_feita)
    );

    mux4x1 muxModo (
        .D0 (4'b0011),
        .D1 (4'b0111),
        .D2 (4'b1011),
        .D3 (4'b1111),
        .SEL (modoReg_w),
        .OUT (modoMux_w)
    );

    registrador_2 RegModo (
        .clock(clock),
        .clear(1'b0),
        .enable(registraModo),
        .D(escolhe_tamanho),
        .Q(modoReg_w)
    );

    mux2x1 muxLed (
        .D0 (registrador_w),
        .D1 (memoriaData_w),
        .SEL (seletorLedsBM),
        .OUT (muxDecoder_w)
    );

    comparador_6bits comparadorJogada ( 
        .ALBi (1'h0), 
        .AGBi (1'h0), 
        .AEBi (1'h1), 
        .A (memoriaData_w), 
        .B (registrador_w),
        .ALBo (ALBoJ_w), 
        .AGBo (AGBoJ_w), 
        .AEBo (igual)
    );

    comparador_85 comparadorHistoria ( 
        .ALBi (1'h0), 
        .AGBi (1'h0), 
        .AEBi (1'h1), 
        .A (modoMux_w), 
        .B (contador_w),
        .ALBo (ALBoL_w), 
        .AGBo (AGBoL_w), 
        .AEBo (fimHistoria)
    );

    contador_163 contadorJ (
        .clock (clock), 
        .clr (~zeraC), 
        .ld (1'h1), 
        .ent (1'h1), 
        .enp (contaC),
        .D (4'h0),
        .Q (contador_w),
        .rco (fimC)  
    );

    registrador_6 registradorBotoes (
        .clock (clock),
        .clear (zeraR),
        .enable (registraR),
        .D (jogada_rx_w),
        .Q (registrador_w)
    );

    sync_ram_16x6_file #(.BINFILE("ram_init.txt")) MemJog (
        .clk  (clock),  
        .we   (escreve),  
        .data (registrador_w),
        .addr (contador_w),
        .q    (memoriaData_w)   
    );

    // Dois segundos a 50 MHz. A UC zera o timer a cada apresentacao.
    contador_m #(.M(100_000_000), .N(27)) timerExibicao (
        .clock (clock),
        .zera_as (reset),
        .zera_s (zeraExibicao),
        .conta (contaExibicao),
        .Q (Q_wire_exibicao),
        .fim (fimExibicao),
        .meio (meio_wire_exibicao)
    );



    codificadorPersonagem codificadorExibicao (
        .personagem(muxDecoder_w), .posicao(posicao_decodificada_w),
        .valido(personagem_valido_w)
    );

    assign carregaExibicao_w = registraExibicao & personagem_valido_w;

    // Uma unica posicao registrada alimenta servo e mensagem serial.
    registrador_n #(.N(3)) RegExibicao (
        .clock(clock), .clear(reset), .enable(carregaExibicao_w),
        .D(posicao_decodificada_w), .Q(posicao_w)
    );

    controle_servo_6 SERVO (
        .clock(clock), .reset(reset), .posicao(posicao_w),
        .controle(pwm), .db_reset(), .db_posicao(), .db_controle()
    );

    registrador_2 RegHistoria (
        .clock(clock), .clear(reset), .enable(registraHistoria),
        .D(escolhe_historia), .Q(historia_w)
    );

    // Equivalentes a somar 7'h30 para as faixas personagem 0..5 e historia 0..3.
    assign personagem_ascii_w = {4'b0110, posicao_w};
    assign historia_ascii_w = {5'b01100, historia_w};

    // Mensagem: H<historia>,P<personagem> seguida de LF.
    // A UC percorre 0..5, pulsa partida_serial e aguarda pronto_serial
    // para cada caractere. Deve manter RegHistoria e RegExibicao estaveis
    // durante toda a mensagem, inclusive ao apresentar personagens iguais.
    mux_8x1_n #(.BITS(7)) muxCaracter (
        .D0(7'h48), .D1(historia_ascii_w), .D2(7'h2C),
        .D3(7'h50), .D4(personagem_ascii_w), .D5(7'h0A),
        .D6(7'h00), .D7(7'h00), .SEL(selCaracter),
        .MUX_OUT(dados_ascii_tx_w)
    );

    tx_serial_7E1 TX_SERIAL (
        .clock(clock), .reset(reset), .partida(partida_serial),
        .dados_ascii(dados_ascii_tx_w), .saida_serial(saida_serial),
        .pronto(pronto_serial), .db_partida(), .db_saida_serial(), .db_estado()
    );

    // A UC continua inicializando o nucleo por zeraC, zeraR e registraModo.
    // Respeitar um ciclo apos registraR antes de escrever/apresentar, e a
    // leitura sincronizada da RAM apos alterar seu endereco.
    // ASSIGNS DE DEPURAÇÃO

    assign db_contagem = contador_w;
    assign db_memoria = memoriaData_w;
    assign db_tamanhohistoria = modoReg_w;
    assign db_historia = historia_w;
    assign db_personagem = posicao_w;
    assign db_pronto_rx = pronto_rx_w;



endmodule
