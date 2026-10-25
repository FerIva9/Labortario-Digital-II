// Top do Fabula TEA+: UC, FD e seis displays da FPGA.
// Clock de 50 MHz; UART 115200 baud, 7E1.
module fabula_tea (
    input wire clock,
    input wire reset,
    input wire contar,
    input wire recontar,
    input wire relembrar,
    input wire entrada_serial,
    input wire [1:0] escolhe_tamanho,
    input wire [1:0] escolhe_historia,

    output wire pwm,
    output wire saida_serial,
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,

    output wire db_rx_serial,
    output wire db_pronto_rx,
    output wire db_jogada_feita,
    output wire db_pwm,
    output wire partida_serial,
    output wire db_tx_serial,
    output wire pronto_serial
);

    wire fimHistoria, fimExibicao, igual;
    wire contaC, zeraC, registraR, zeraR, registraModo, escreve;
    wire leds_BM, contaExibicao, zeraExibicao;
    wire habilitaJogada, registraExibicao, registraHistoria;
    wire acertou, errou, contando, recontando, relembrando;
    wire [2:0] selCaracter;
    wire [5:0] db_estado;
    wire [3:0] db_contagem;
    wire [2:0] db_personagem;
    wire [1:0] db_historia;
    wire [3:0] situacao;

    unidade_controle UC (
        .clock(clock), .reset(reset),
        .contar(contar), .recontar(recontar), .relembrar(relembrar),
        .fimHistoria(fimHistoria), .fimExibicao(fimExibicao),
        .jogada(db_jogada_feita), .igual(igual),
        .pronto_serial(pronto_serial),
        .acertou(acertou), .errou(errou),
        .contando(contando), .recontando(recontando),
        .relembrando(relembrando),
        .contaC(contaC), .zeraC(zeraC),
        .registraR(registraR), .zeraR(zeraR),
        .registraModo(registraModo), .escreve(escreve),
        .leds_BM(leds_BM),
        .contaExibicao(contaExibicao), .zeraExibicao(zeraExibicao),
        .habilitaJogada(habilitaJogada),
        .registraExibicao(registraExibicao),
        .registraHistoria(registraHistoria),
        .selCaracter(selCaracter), .partida_serial(partida_serial),
        .db_estado(db_estado)
    );

    fluxo_dados FD (
        .clock(clock), .reset(reset),
        .entrada_serial(entrada_serial),
        .escolhe_tamanho(escolhe_tamanho),
        .escolhe_historia(escolhe_historia),
        .fimHistoria(fimHistoria), .fimExibicao(fimExibicao),
        .jogada_feita(db_jogada_feita), .igual(igual),
        .pronto_serial(pronto_serial),
        .contaC(contaC), .zeraC(zeraC),
        .registraR(registraR), .zeraR(zeraR),
        .registraModo(registraModo), .escreve(escreve),
        .seletorLedsBM(leds_BM),
        .contaExibicao(contaExibicao), .zeraExibicao(zeraExibicao),
        .habilitaJogada(habilitaJogada),
        .registraExibicao(registraExibicao),
        .registraHistoria(registraHistoria),
        .selCaracter(selCaracter), .partida_serial(partida_serial),
        .pwm(pwm), .saida_serial(saida_serial),
        .db_contagem(db_contagem),
        .db_memoria(), .db_tamanhohistoria(),
        .db_historia(db_historia), .db_personagem(db_personagem),
        .db_pronto_rx(db_pronto_rx)
    );

    // HEX0 historia; HEX1 personagem; HEX2 endereco da RAM.
    // HEX3 situacao; HEX5:HEX4 codigo hexadecimal do estado (00 a 3B).
    assign situacao = acertou ? 4'd4 :
                      errou ? 4'd5 :
                      relembrando ? 4'd3 :
                      recontando ? 4'd2 :
                      contando ? 4'd1 : 4'd0;

    hexa7seg display_historia  (.hexa({2'b00, db_historia}),       .display(HEX0));
    hexa7seg display_personagem(.hexa({1'b0, db_personagem}),     .display(HEX1));
    hexa7seg display_contagem  (.hexa(db_contagem),               .display(HEX2));
    hexa7seg display_situacao  (.hexa(situacao),                  .display(HEX3));
    hexa7seg display_estado_lo (.hexa(db_estado[3:0]),           .display(HEX4));
    hexa7seg display_estado_hi (.hexa({2'b00, db_estado[5:4]}),   .display(HEX5));

    assign db_rx_serial = entrada_serial;
    assign db_pwm = pwm;
    assign db_tx_serial = saida_serial;

endmodule
