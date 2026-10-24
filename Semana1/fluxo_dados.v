//------------------------------------------------------------------
// Arquivo   : fluxo_dados.v
// Projeto   : Fluxo de dados do jogo Fábula TEA
//------------------------------------------------------------------
// Descricao : Fluxo de dados do circuito da Semana 1
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
//------------------------------------------------------------------
//


module fluxo_dados (
    // ENTRADAS:
    input [1:0] escolhe_tamanho,
    input registraModo, // sinal que permite o registro do modo de jogo
    input clock, // sinal de clock
    input zeraC, // sinal que zera contador de jogadas
    input contaC, // sinal que conta no contador de jogadas
    input escreve, // sinal que permite escrita na ram
    input zeraR,  // sinal que zera registrador de botões
    input registraR,  // sinal que permite o registro dos botões 
    input [5:0] botoes, // botoes com as jogadas feitas (VEM EXTERNO)
    input contaExibicao, // sinal que permite a contagem do contador do timer
    input zeraExibicao,  // sinal que zera o contador do timer
    input resetEdgeDetector, // sinal que zera o edge detector
    input seletorLedsBM, // seleciona qual a saída será exibida nos leds


    // SAÍDAS


    output fimHistoria, // sinal que indica o fim da historia
    output igual, // sinal que indica que botões é igual a dado de memória
    output jogada_feita, // sinal que indica que houve jogada
    output fimExibicao, // sinal que indica que houve fim dos 2 segundos
    output [5:0] leds_saida, // sinal que indica os leds de saída


    // SINAIS DE DEPURAÇÃO: (a fazer)

    output [3:0] db_contagem,
    output [5:0] db_memoria,
    output [1:0] db_tamanhohistoria

);


    // Fios de conexão 

    wire [3:0] modoMux_w;
    wire [1:0] modoReg_w;
    wire [3:0] contador_w;
    wire [5:0] registrador_w;
    wire [5:0] memoriaData_w;
    wire OrEdgeDetector_w;
    wire [5:0] muxDecoder_w;
    wire ALBoJ_w;
    wire AGBoJ_w;
    wire ALBoL_w;
    wire AGBoL_w;
    wire [10:0] Q_wire_exibicao;
    wire meio_wire_exibicao;
    wire fimC;
    wire [5:0] botoes_debounced;




    // COMPONENTES:
    
    genvar i;

    generate 
        for(i = 0; i < 6; i = i + 1) begin: gen_debounce
            debounce debouncei (
                .clk(clock),
                .button_in(botoes[i]),
                .button_out(botoes_debounced[i])
            );
        end
    endgenerate 

    edge_detector detector ( 
        .clock (clock),
        .reset (resetEdgeDetector),
        .sinal (OrEdgeDetector_w),
        .pulso (jogada_feita)
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
        .D0 (botoes_debounced),
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
        .D (botoes_debounced),
        .Q (registrador_w)
    );

    sync_ram_16x6_file #(.BINFILE("ram_init.txt")) MemJog (
        .clk  (clock),  
        .we   (escreve),  
        .data (registrador_w),
        .addr (contador_w),
        .q    (memoriaData_w)   
    );

    contador_m #(.M(1500), .N(11)) timerExibicao (
        .clock (clock),
        .zera_as (1'b0),
        .zera_s (zeraExibicao),
        .conta (contaExibicao),
        .Q (Q_wire_exibicao),
        .fim (fimExibicao),
        .meio (meio_wire_exibicao)
    );



    // ASSIGNS DE DEPURAÇÃO

    assign db_contagem = contador_w;
    assign db_memoria = memoriaData_w;
    assign db_tamanhohistoria = modoReg_w;

    
    // ASSIGNS ADICIONAIS PARA LÓGICA COMBINATÓRIA

    assign OrEdgeDetector_w = (botoes_debounced[0] || 
                               botoes_debounced[1] || 
                               botoes_debounced[2] || 
                               botoes_debounced[3] || 
                               botoes_debounced[4] || 
                               botoes_debounced[5]);


    // ASSIGNS PARA SINAIS DE SAÍDA

    assign leds_saida = muxDecoder_w;

endmodule
