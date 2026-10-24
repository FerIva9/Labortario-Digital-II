//------------------------------------------------------------------
// Arquivo   : unidade_controle.v
// Projeto   : Unidade de controle da Semana 1
//------------------------------------------------------------------
// Descricao : Unidade de controle do circuito da Semana 1
//          
//------------------------------------------------------------------
// Revisoes  :
//     Data        Versao  Autor             Descricao
//     29/01/2026  1.0     Thiago Martins  versao inicial
//     31/01/2026  1.1     Guilherme Muller Correcao de erros
//     31/01/2026  1.2     Fernando Ivanov   ajuste nos estados
//     05/02/2026  1.3     Guilherme Muller  ajuste para exp5
//     20/02/2026  1.4     Fernando Ivanov   ajuste para exp6
//     14/03/2026  2.0     Fernando Ivanov   ajuste para Semana 1
//     21/03/2026  2.1     Thiago Martins    ajuste para Semana 2
//------------------------------------------------------------------
//

module unidade_controle (
    // ENTRADAS

    // Vindas do FD
    input fimHistoria,
    input fimExibicao,
    input jogada,
    input igual,

    // Vindas externamente
    input clock,
    input reset, // VEM BOTÃO
    input contar, // VEM BOTÃO
    input recontar, // VEM BOTÃO
    input relembrar, // VEM BOTÃO


    // SAÍDAS 


    // Que irão para fora
    output reg acertou,
    output reg errou,
    output reg contando,
    output reg relembrando,
    output reg recontando,


    // Que irão para o FD
    output reg contaC,
    output reg zeraC,
    output reg registraR,
    output reg zeraR,

    output reg registraModo,
    output reg escreve,
    output reg leds_BM,

    output reg contaExibicao,
    output reg zeraExibicao,

    output reg resetEdgeDetector,

    output reg [4:0] db_estado
);

    wire reset_debounced;
    wire contar_debounced;
    wire recontar_debounced;
    wire relembrar_debounced;

    debounce debounce_reset (
        .clk(clock),
        .button_in(reset),
        .button_out(reset_debounced)
    );

    debounce debounce_contar (
        .clk(clock),
        .button_in(contar),
        .button_out(contar_debounced)
    );

    debounce debounce_recontar (
        .clk(clock),
        .button_in(recontar),
        .button_out(recontar_debounced)
    );

    debounce debounce_relembrar (
        .clk(clock),
        .button_in(relembrar),
        .button_out(relembrar_debounced)
    );



    // Define estados
    parameter inicial                      = 5'b00000;  // 0
    parameter inicializa                   = 5'b00001;  // 1
    parameter prepara_contagem             = 5'b00010;  // 2
    parameter espera_jogada_contagem       = 5'b00011;  // 3
    parameter registra_jogada_contagem     = 5'b00100;  // 4
    parameter grava_jogada                 = 5'b00101;  // 5
    parameter verifica_fim_contagem        = 5'b00110;  // 6
    parameter proxima_jogada_contagem      = 5'b00111;  // 7
    parameter prepara_recontagem           = 5'b01000;  // 8
    parameter espera_jogada_recontagem     = 5'b01001;  // 9
    parameter fim_acertou                  = 5'b01010;  // A
    parameter registra_jogada_recontagem   = 5'b01011;  // B
    parameter compara_jogada               = 5'b01100;  // C
    parameter proxima_jogada_recontagem    = 5'b01101;  // D
    parameter fim_errou                    = 5'b01110;  // E
    parameter prepara_relembrar            = 5'b01111;  // F
    parameter mostra_jogada                = 5'b10000;  // 10
    parameter zera_timer                   = 5'b10001;  // 11
    parameter verifica_fim_relembrar       = 5'b10010;  // 12
    parameter mostra_apagado               = 5'b10011;  // 13
    parameter aumenta_limite_relembrar     = 5'b10100;  // 14

    // Variaveis de estado
    reg [4:0] Eatual, Eprox;

    // Memoria de estado
    always @(posedge clock or posedge reset_debounced) begin
        if (reset_debounced)
            Eatual <= inicial;
        else
            Eatual <= Eprox;
    end

    // Logica de proximo estado
    always @* begin
        case (Eatual)

            inicial:
                Eprox = (contar_debounced) ? inicializa : inicial;

            inicializa:
                Eprox = prepara_contagem;

            prepara_contagem:
                Eprox = espera_jogada_contagem;

            espera_jogada_contagem:
                Eprox = (jogada) ? registra_jogada_contagem : espera_jogada_contagem;

            registra_jogada_contagem:
                Eprox = grava_jogada;

            grava_jogada:
                Eprox = verifica_fim_contagem;

            verifica_fim_contagem:
                Eprox = (fimHistoria) ? prepara_recontagem : proxima_jogada_contagem;

            proxima_jogada_contagem:
                Eprox = espera_jogada_contagem;

            prepara_recontagem:
                Eprox = espera_jogada_recontagem;

            espera_jogada_recontagem:
                Eprox = (jogada) ? registra_jogada_recontagem : espera_jogada_recontagem;

            registra_jogada_recontagem:
                Eprox = compara_jogada;

            compara_jogada:
                Eprox = (igual) ? ((fimHistoria) ? fim_acertou : proxima_jogada_recontagem) : fim_errou;
            
            fim_acertou:
                Eprox = (contar_debounced) ? inicializa : fim_acertou;
            
            fim_errou:
                Eprox = (recontar_debounced) ? inicializa : ((relembrar_debounced) ? prepara_relembrar : fim_errou);

            proxima_jogada_recontagem:
                Eprox = espera_jogada_recontagem;

            prepara_relembrar:
                Eprox = mostra_jogada;

            mostra_jogada:
                Eprox = (fimExibicao) ? zera_timer : mostra_jogada;

            zera_timer:
                Eprox = verifica_fim_relembrar;

            verifica_fim_relembrar:
                Eprox = (fimHistoria) ? prepara_recontagem : mostra_apagado;

            mostra_apagado:
                Eprox = (fimExibicao) ? aumenta_limite_relembrar : mostra_apagado;

            aumenta_limite_relembrar:
                Eprox = mostra_jogada;

            default:
                Eprox = inicial;

        endcase
    end

    // Logica de saida (maquina Moore)
    always @* begin
        
        acertou = (Eatual == fim_acertou) ? 1'b1 : 1'b0;

        errou = (Eatual == fim_errou) ? 1'b1 : 1'b0;

        contando = (Eatual == prepara_contagem ||
                    Eatual == espera_jogada_contagem ||
                    Eatual == registra_jogada_contagem ||
                    Eatual == grava_jogada ||
                    Eatual == verifica_fim_contagem ||
                    Eatual == proxima_jogada_contagem ) ? 1'b1 : 1'b0;

        recontando = (Eatual == prepara_recontagem ||
                      Eatual == espera_jogada_recontagem ||
                      Eatual == registra_jogada_recontagem ||
                      Eatual == compara_jogada ||
                      Eatual == proxima_jogada_recontagem ) ? 1'b1 : 1'b0;

        relembrando = (Eatual == prepara_relembrar ||
                       Eatual == mostra_jogada ||
                       Eatual == zera_timer ||
                       Eatual == verifica_fim_relembrar ||
                       Eatual == mostra_apagado ||
                       Eatual == aumenta_limite_relembrar ) ? 1'b1 : 1'b0;

        contaC = (Eatual == proxima_jogada_contagem ||
                  Eatual == proxima_jogada_recontagem ||
                  Eatual == aumenta_limite_relembrar) ? 1'b1 : 1'b0;

        zeraC = (Eatual == inicial ||
                 Eatual == inicializa ||
                 Eatual == prepara_contagem ||
                 Eatual == prepara_recontagem ||
                 Eatual == prepara_relembrar ) ? 1'b1 : 1'b0;

        registraR = (Eatual == registra_jogada_contagem ||
                     Eatual == registra_jogada_recontagem) ? 1'b1 : 1'b0;
                    
        zeraR = (Eatual == inicial || 
                 Eatual == inicializa) ? 1'b1 : 1'b0;

        registraModo = (Eatual == inicial ||
                        Eatual == fim_acertou ) ? 1'b1 : 1'b0;
        
        escreve = (Eatual == grava_jogada) ? 1'b1 : 1'b0;

        leds_BM = (Eatual == prepara_relembrar ||
                   Eatual == mostra_jogada || 
                   Eatual == zera_timer ||
                   Eatual == verifica_fim_relembrar ||
                   Eatual == mostra_apagado ||
                   Eatual == aumenta_limite_relembrar) ? 1'b1 : 1'b0;
        

        contaExibicao = (Eatual == mostra_jogada ||
                         Eatual == mostra_apagado ) ? 1'b1 : 1'b0;

        zeraExibicao = (Eatual == inicial ||
                        Eatual == inicializa ||
                        Eatual == prepara_recontagem ||
                        Eatual == aumenta_limite_relembrar) ? 1'b1 : 1'b0;

        resetEdgeDetector = (Eatual == inicial ||
                             Eatual == inicializa) ? 1'b1 : 1'b0;


    end

    // Saida de depuracao (estado)
    always @* begin
        case (Eatual)
            inicial:                        db_estado = 5'b00000; // 0
            inicializa:                     db_estado = 5'b00001; // 1
            prepara_contagem:               db_estado = 5'b00010; // 2
            espera_jogada_contagem:         db_estado = 5'b00011; // 3
            registra_jogada_contagem:       db_estado = 5'b00100; // 4
            grava_jogada:                   db_estado = 5'b00101; // 5
            verifica_fim_contagem:          db_estado = 5'b00110; // 6
            proxima_jogada_contagem:        db_estado = 5'b00111; // 7
            prepara_recontagem:             db_estado = 5'b01000; // 8
            espera_jogada_recontagem:       db_estado = 5'b01001; // 9
            fim_acertou:                   db_estado = 5'b01010; // A
            registra_jogada_recontagem:     db_estado = 5'b01011; // B
            compara_jogada:                 db_estado = 5'b01100; // C
            proxima_jogada_recontagem:      db_estado = 5'b01101; // D
            fim_errou:                      db_estado = 5'b01110; // E
            prepara_relembrar:              db_estado = 5'b01111; // F
            mostra_jogada:                  db_estado = 5'b10000; // 10
            zera_timer:                     db_estado = 5'b10001; // 11
            verifica_fim_relembrar:         db_estado = 5'b10010; // 12
            mostra_apagado:                 db_estado = 5'b10011; // 13
            aumenta_limite_relembrar:       db_estado = 5'b10100; // 14
            default:                        db_estado = 5'b11111; // erro
        endcase
    end

endmodule
