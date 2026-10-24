//------------------------------------------------------------------
// Arquivo   : circuito_semana1.v
// Projeto   : Circuito da semana 1 de desenvolvimento do projeto
//------------------------------------------------------------------
// Descricao : Circuito de integração para a semana 1
//          
//------------------------------------------------------------------
// Revisoes  :
//     Data        Versao  Autor               Descricao
//     29/01/2026  1.0     Thiago Martins     versao inicial
//     31/01/2026  1.1     Fernando Ivanov    ajuste dos leds
//     07/02/2026  1.2     Guilherme Muller   adaptacao para experiencia 5
//     20/02/2026  1.3     Fernando Ivanov    adaptacao para experiencia 6
//     14/03/2026  2.0     Fernando Ivanov    adaptação para a semana 1
//     21/03/2026  2.1     Thiago Martins     Adaptação para a semana 2
//     03/04/2026  3.1     Fernando Ivanov    Adaptação para a semana 4 (inicial)
//------------------------------------------------------------------
//

module circuito_semana4 (
    input clock,
    input reset,
    input contar,  
    input recontar,
    input relembrar,
    input [5:0] botoes,  
    input [1:0] escolhe_tamanho,

    output acertou,
    output errou,   
    output contando,
    output recontando,
    output relembrando,

    output [6:0] db_contagem,
    output [6:0] db_estado,
    output [5:0] db_memoria,
    output [1:0] db_tamanhohistoria,

    output led_vermelho,
    output led_verde,
    output led_amarelo,
    output led_azul,
    output led_ciano,
    output led_roxo

 );

    // Fios para ligação

    wire fimHistoria_w, fimExibicao_w;
    wire igual_w, jogada_feita_w;
    wire contaC_w, zeraC_w, registraR_w, zeraR_w;
    wire registraModo_w, escreve_w, leds_BM_w;
    wire contaExibicao_w, zeraExibicao_w;
    wire resetEdgeDetector_w;
    wire [5:0] leds_saida_w;

    wire [4:0] db_estado_w;
    wire [3:0] db_contagem_w;
    wire [5:0] db_memoria_w;
    wire [1:0] db_tamanhohistoria_w;


    unidade_controle UC (
        // Entradas do fluxo de dados
        .fimHistoria (fimHistoria_w),
        .fimExibicao (fimExibicao_w),
        .jogada (jogada_feita_w),
        .igual (igual_w),

        // Entradas externas
        .clock (clock),
        .reset (reset),
        .contar (contar),
        .recontar (recontar),
        .relembrar (relembrar),

        // Saídas externas
        .acertou (acertou),
        .errou (errou),
        .contando (contando),
        .relembrando (relembrando),
        .recontando (recontando),

        // Saídas para o fluxo de dados
        .contaC (contaC_w),
        .zeraC (zeraC_w),
        .registraR (registraR_w),
        .zeraR (zeraR_w),
        .registraModo (registraModo_w),
        .escreve (escreve_w),
        .leds_BM (leds_BM_w),
        .contaExibicao (contaExibicao_w),
        .zeraExibicao (zeraExibicao_w),
        .resetEdgeDetector (resetEdgeDetector_w),

        // Debug
        .db_estado (db_estado_w)
    );

    fluxo_dados FD (
        // Entradas
        .escolhe_tamanho (escolhe_tamanho),
        .registraModo (registraModo_w),
        .clock (clock),
        .zeraC (zeraC_w),
        .contaC (contaC_w),
        .escreve (escreve_w),
        .zeraR (zeraR_w),
        .registraR (registraR_w),
        .botoes (botoes),
        .contaExibicao (contaExibicao_w),
        .zeraExibicao (zeraExibicao_w),
        .resetEdgeDetector (resetEdgeDetector_w),
        .seletorLedsBM (leds_BM_w),

        // Saídas
        .fimHistoria (fimHistoria_w),
        .igual (igual_w),
        .jogada_feita (jogada_feita_w),
        .fimExibicao (fimExibicao_w),
        .leds_saida (leds_saida_w),

        // Debug
        .db_contagem (db_contagem_w),
        .db_memoria (db_memoria_w),
        .db_tamanhohistoria(db_tamanhohistoria_w)
    );

    estado7seg HEX3 (
        .estado (db_estado_w),
        .display(db_estado)
    );

    hexa7seg HEX0 (
        .hexa   (db_contagem_w),
        .display(db_contagem)
    );

    assign db_memoria = db_memoria_w;
    assign db_tamanhohistoria = db_tamanhohistoria_w;

    assign led_vermelho = leds_saida_w[0];
    assign led_amarelo = leds_saida_w[1];
    assign led_azul = leds_saida_w[2];
    assign led_ciano = leds_saida_w[3];
    assign led_verde = leds_saida_w[4];
    assign led_roxo = leds_saida_w[5];


endmodule
