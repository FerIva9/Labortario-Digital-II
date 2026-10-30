//------------------------------------------------------------------
// Arquivo   : unidade_controle.v
// Projeto   : Unidade de controle do Fabula TEA+
//------------------------------------------------------------------
// Descricao : Maquina de Moore com 60 estados, conforme tabela aprovada
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
//     25/10/1016  3.1     Fernando Ivanov   ajuste para LabDigII
//------------------------------------------------------------------
//

module unidade_controle (
    input clock,
    input reset,
    input contar,
    input recontar,
    input relembrar,
    // Condicoes vindas do FD. jogada recebe jogada_feita (pendencia).
    input fimHistoria,
    input fimExibicao,
    input jogada,
    input igual,
    input pronto_serial,

    output reg acertou,
    output reg errou,
    output reg contando,
    output reg recontando,
    output reg relembrando,
    output reg contaC,
    output reg zeraC,
    output reg registraR,
    output reg zeraR,
    output reg registraModo,
    output reg escreve,
    output reg leds_BM,
    output reg contaExibicao,
    output reg zeraExibicao,
    output reg habilitaJogada,
    output reg registraExibicao,
    output reg registraHistoria,
    output reg partida_serial,
    output reg [2:0] selCaracter,
    output wire [5:0] db_estado
);

    localparam [5:0] inicial                                = 6'd0;
    localparam [5:0] inicializa                             = 6'd1;
    localparam [5:0] prepara_contagem                       = 6'd2;
    localparam [5:0] espera_jogada_contagem                 = 6'd3;
    localparam [5:0] registra_jogada_contagem               = 6'd4;
    localparam [5:0] grava_jogada                           = 6'd5;
    localparam [5:0] registra_exibicao_contagem             = 6'd6;
    localparam [5:0] transmite_H_contagem                   = 6'd7;
    localparam [5:0] espera_H_contagem                      = 6'd8;
    localparam [5:0] transmite_historia_contagem            = 6'd9;
    localparam [5:0] espera_historia_contagem               = 6'd10;
    localparam [5:0] transmite_virgula_contagem             = 6'd11;
    localparam [5:0] espera_virgula_contagem                = 6'd12;
    localparam [5:0] transmite_P_contagem                   = 6'd13;
    localparam [5:0] espera_P_contagem                      = 6'd14;
    localparam [5:0] transmite_personagem_contagem          = 6'd15;
    localparam [5:0] espera_personagem_contagem             = 6'd16;
    localparam [5:0] transmite_LF_contagem                  = 6'd17;
    localparam [5:0] espera_LF_contagem                     = 6'd18;
    localparam [5:0] verifica_fim_contagem                  = 6'd19;
    localparam [5:0] proxima_jogada_contagem                = 6'd20;
    localparam [5:0] prepara_recontagem                     = 6'd21;
    localparam [5:0] espera_jogada_recontagem               = 6'd22;
    localparam [5:0] registra_jogada_recontagem             = 6'd23;
    localparam [5:0] registra_exibicao_recontagem           = 6'd24;
    localparam [5:0] transmite_H_recontagem                 = 6'd25;
    localparam [5:0] espera_H_recontagem                    = 6'd26;
    localparam [5:0] transmite_historia_recontagem          = 6'd27;
    localparam [5:0] espera_historia_recontagem             = 6'd28;
    localparam [5:0] transmite_virgula_recontagem           = 6'd29;
    localparam [5:0] espera_virgula_recontagem              = 6'd30;
    localparam [5:0] transmite_P_recontagem                 = 6'd31;
    localparam [5:0] espera_P_recontagem                    = 6'd32;
    localparam [5:0] transmite_personagem_recontagem        = 6'd33;
    localparam [5:0] espera_personagem_recontagem           = 6'd34;
    localparam [5:0] transmite_LF_recontagem                = 6'd35;
    localparam [5:0] espera_LF_recontagem                   = 6'd36;
    localparam [5:0] compara_jogada                         = 6'd37;
    localparam [5:0] proxima_jogada_recontagem              = 6'd38;
    localparam [5:0] fim_acertou                            = 6'd39;
    localparam [5:0] fim_errou                              = 6'd40;
    localparam [5:0] prepara_relembrar                      = 6'd41;
    localparam [5:0] espera_memoria_relembrar               = 6'd42;
    localparam [5:0] registra_exibicao_relembrar            = 6'd43;
    localparam [5:0] transmite_H_relembrar                  = 6'd44;
    localparam [5:0] espera_H_relembrar                     = 6'd45;
    localparam [5:0] transmite_historia_relembrar           = 6'd46;
    localparam [5:0] espera_historia_relembrar              = 6'd47;
    localparam [5:0] transmite_virgula_relembrar            = 6'd48;
    localparam [5:0] espera_virgula_relembrar               = 6'd49;
    localparam [5:0] transmite_P_relembrar                  = 6'd50;
    localparam [5:0] espera_P_relembrar                     = 6'd51;
    localparam [5:0] transmite_personagem_relembrar         = 6'd52;
    localparam [5:0] espera_personagem_relembrar            = 6'd53;
    localparam [5:0] transmite_LF_relembrar                 = 6'd54;
    localparam [5:0] espera_LF_relembrar                    = 6'd55;
    localparam [5:0] mostra_jogada                          = 6'd56;
    localparam [5:0] zera_timer                             = 6'd57;
    localparam [5:0] verifica_fim_relembrar                 = 6'd58;
    localparam [5:0] aumenta_limite_relembrar               = 6'd59;

    reg [5:0] Eatual, Eprox;

    // Memoria de estado.
    always @(posedge clock or posedge reset) begin
        if (reset)
            Eatual <= inicial;
        else
            Eatual <= Eprox;
    end

    // Transicoes. Cada caractere tem partida (um ciclo) e espera separados.
    always @(*) begin
        Eprox = inicial;
        case (Eatual)
            inicial:
                Eprox = (contar) ? inicializa : (inicial);
            inicializa:
                Eprox = prepara_contagem;
            prepara_contagem:
                Eprox = espera_jogada_contagem;
            espera_jogada_contagem:
                Eprox = (jogada) ? registra_jogada_contagem : (espera_jogada_contagem);
            registra_jogada_contagem:
                Eprox = grava_jogada;
            grava_jogada:
                Eprox = registra_exibicao_contagem;
            registra_exibicao_contagem:
                Eprox = transmite_H_contagem;
            transmite_H_contagem:
                Eprox = espera_H_contagem;
            espera_H_contagem:
                Eprox = (pronto_serial) ? transmite_historia_contagem : (espera_H_contagem);
            transmite_historia_contagem:
                Eprox = espera_historia_contagem;
            espera_historia_contagem:
                Eprox = (pronto_serial) ? transmite_virgula_contagem : (espera_historia_contagem);
            transmite_virgula_contagem:
                Eprox = espera_virgula_contagem;
            espera_virgula_contagem:
                Eprox = (pronto_serial) ? transmite_P_contagem : (espera_virgula_contagem);
            transmite_P_contagem:
                Eprox = espera_P_contagem;
            espera_P_contagem:
                Eprox = (pronto_serial) ? transmite_personagem_contagem : (espera_P_contagem);
            transmite_personagem_contagem:
                Eprox = espera_personagem_contagem;
            espera_personagem_contagem:
                Eprox = (pronto_serial) ? transmite_LF_contagem : (espera_personagem_contagem);
            transmite_LF_contagem:
                Eprox = espera_LF_contagem;
            espera_LF_contagem:
                Eprox = (pronto_serial) ? verifica_fim_contagem : (espera_LF_contagem);
            verifica_fim_contagem:
                Eprox = (fimHistoria) ? prepara_recontagem : (proxima_jogada_contagem);
            proxima_jogada_contagem:
                Eprox = espera_jogada_contagem;
            prepara_recontagem:
                Eprox = espera_jogada_recontagem;
            espera_jogada_recontagem:
                Eprox = (jogada) ? registra_jogada_recontagem : (espera_jogada_recontagem);
            registra_jogada_recontagem:
                Eprox = registra_exibicao_recontagem;
            registra_exibicao_recontagem:
                Eprox = transmite_H_recontagem;
            transmite_H_recontagem:
                Eprox = espera_H_recontagem;
            espera_H_recontagem:
                Eprox = (pronto_serial) ? transmite_historia_recontagem : (espera_H_recontagem);
            transmite_historia_recontagem:
                Eprox = espera_historia_recontagem;
            espera_historia_recontagem:
                Eprox = (pronto_serial) ? transmite_virgula_recontagem : (espera_historia_recontagem);
            transmite_virgula_recontagem:
                Eprox = espera_virgula_recontagem;
            espera_virgula_recontagem:
                Eprox = (pronto_serial) ? transmite_P_recontagem : (espera_virgula_recontagem);
            transmite_P_recontagem:
                Eprox = espera_P_recontagem;
            espera_P_recontagem:
                Eprox = (pronto_serial) ? transmite_personagem_recontagem : (espera_P_recontagem);
            transmite_personagem_recontagem:
                Eprox = espera_personagem_recontagem;
            espera_personagem_recontagem:
                Eprox = (pronto_serial) ? transmite_LF_recontagem : (espera_personagem_recontagem);
            transmite_LF_recontagem:
                Eprox = espera_LF_recontagem;
            espera_LF_recontagem:
                Eprox = (pronto_serial) ? compara_jogada : (espera_LF_recontagem);
            compara_jogada:
                Eprox = (!igual) ? fim_errou : ((fimHistoria) ? fim_acertou : (proxima_jogada_recontagem));
            proxima_jogada_recontagem:
                Eprox = espera_jogada_recontagem;
            fim_acertou:
                Eprox = (contar) ? inicializa : (fim_acertou);
            fim_errou:
                Eprox = (recontar) ? inicializa : ((relembrar) ? prepara_relembrar : (fim_errou));
            prepara_relembrar:
                Eprox = espera_memoria_relembrar;
            espera_memoria_relembrar:
                Eprox = registra_exibicao_relembrar;
            registra_exibicao_relembrar:
                Eprox = transmite_H_relembrar;
            transmite_H_relembrar:
                Eprox = espera_H_relembrar;
            espera_H_relembrar:
                Eprox = (pronto_serial) ? transmite_historia_relembrar : (espera_H_relembrar);
            transmite_historia_relembrar:
                Eprox = espera_historia_relembrar;
            espera_historia_relembrar:
                Eprox = (pronto_serial) ? transmite_virgula_relembrar : (espera_historia_relembrar);
            transmite_virgula_relembrar:
                Eprox = espera_virgula_relembrar;
            espera_virgula_relembrar:
                Eprox = (pronto_serial) ? transmite_P_relembrar : (espera_virgula_relembrar);
            transmite_P_relembrar:
                Eprox = espera_P_relembrar;
            espera_P_relembrar:
                Eprox = (pronto_serial) ? transmite_personagem_relembrar : (espera_P_relembrar);
            transmite_personagem_relembrar:
                Eprox = espera_personagem_relembrar;
            espera_personagem_relembrar:
                Eprox = (pronto_serial) ? transmite_LF_relembrar : (espera_personagem_relembrar);
            transmite_LF_relembrar:
                Eprox = espera_LF_relembrar;
            espera_LF_relembrar:
                Eprox = (pronto_serial) ? mostra_jogada : (espera_LF_relembrar);
            mostra_jogada:
                Eprox = (fimExibicao) ? zera_timer : (mostra_jogada);
            zera_timer:
                Eprox = verifica_fim_relembrar;
            verifica_fim_relembrar:
                Eprox = (fimHistoria) ? prepara_recontagem : (aumenta_limite_relembrar);
            aumenta_limite_relembrar:
                Eprox = espera_memoria_relembrar;
            default: Eprox = inicial;
        endcase
    end

    // Saidas de Moore: nenhuma entrada externa participa desta logica.
    // Valores padrao tambem definem o comportamento de estados invalidos.
    // contaExibicao so e habilitada em mostra_jogada (relembrar).
    always @(*) begin
        acertou = 1'b0;
        errou = 1'b0;
        contando = 1'b0;
        recontando = 1'b0;
        relembrando = 1'b0;
        contaC = 1'b0;
        zeraC = 1'b0;
        registraR = 1'b0;
        zeraR = 1'b0;
        registraModo = 1'b0;
        escreve = 1'b0;
        leds_BM = 1'b0;
        contaExibicao = 1'b0;
        zeraExibicao = 1'b0;
        habilitaJogada = 1'b0;
        registraExibicao = 1'b0;
        registraHistoria = 1'b0;
        partida_serial = 1'b0;
        selCaracter = 3'b000;

        case (Eatual)
            inicial: begin
                zeraC = 1'b1;
                zeraR = 1'b1;
                zeraExibicao = 1'b1;
            end
            inicializa: begin
                zeraC = 1'b1;
                zeraR = 1'b1;
                registraModo = 1'b1;
                zeraExibicao = 1'b1;
                registraHistoria = 1'b1;
            end
            prepara_contagem: begin
                contando = 1'b1;
                zeraC = 1'b1;
            end
            espera_jogada_contagem: begin
                contando = 1'b1;
                habilitaJogada = 1'b1;
            end
            registra_jogada_contagem: begin
                contando = 1'b1;
                registraR = 1'b1;
            end
            grava_jogada: begin
                contando = 1'b1;
                escreve = 1'b1;
            end
            registra_exibicao_contagem: begin
                contando = 1'b1;
                registraExibicao = 1'b1;
            end
            transmite_H_contagem: begin
                contando = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b000;
            end
            espera_H_contagem: begin
                contando = 1'b1;
                selCaracter = 3'b000;
            end
            transmite_historia_contagem: begin
                contando = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b001;
            end
            espera_historia_contagem: begin
                contando = 1'b1;
                selCaracter = 3'b001;
            end
            transmite_virgula_contagem: begin
                contando = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b010;
            end
            espera_virgula_contagem: begin
                contando = 1'b1;
                selCaracter = 3'b010;
            end
            transmite_P_contagem: begin
                contando = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b011;
            end
            espera_P_contagem: begin
                contando = 1'b1;
                selCaracter = 3'b011;
            end
            transmite_personagem_contagem: begin
                contando = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b100;
            end
            espera_personagem_contagem: begin
                contando = 1'b1;
                selCaracter = 3'b100;
            end
            transmite_LF_contagem: begin
                contando = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b101;
            end
            espera_LF_contagem: begin
                contando = 1'b1;
                selCaracter = 3'b101;
            end
            verifica_fim_contagem: begin
                contando = 1'b1;
            end
            proxima_jogada_contagem: begin
                contando = 1'b1;
                contaC = 1'b1;
            end
            prepara_recontagem: begin
                recontando = 1'b1;
                zeraC = 1'b1;
                zeraR = 1'b1;
            end
            espera_jogada_recontagem: begin
                recontando = 1'b1;
                habilitaJogada = 1'b1;
            end
            registra_jogada_recontagem: begin
                recontando = 1'b1;
                registraR = 1'b1;
            end
            registra_exibicao_recontagem: begin
                recontando = 1'b1;
                registraExibicao = 1'b1;
            end
            transmite_H_recontagem: begin
                recontando = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b000;
            end
            espera_H_recontagem: begin
                recontando = 1'b1;
                selCaracter = 3'b000;
            end
            transmite_historia_recontagem: begin
                recontando = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b001;
            end
            espera_historia_recontagem: begin
                recontando = 1'b1;
                selCaracter = 3'b001;
            end
            transmite_virgula_recontagem: begin
                recontando = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b010;
            end
            espera_virgula_recontagem: begin
                recontando = 1'b1;
                selCaracter = 3'b010;
            end
            transmite_P_recontagem: begin
                recontando = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b011;
            end
            espera_P_recontagem: begin
                recontando = 1'b1;
                selCaracter = 3'b011;
            end
            transmite_personagem_recontagem: begin
                recontando = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b100;
            end
            espera_personagem_recontagem: begin
                recontando = 1'b1;
                selCaracter = 3'b100;
            end
            transmite_LF_recontagem: begin
                recontando = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b101;
            end
            espera_LF_recontagem: begin
                recontando = 1'b1;
                selCaracter = 3'b101;
            end
            compara_jogada: begin
                recontando = 1'b1;
            end
            proxima_jogada_recontagem: begin
                recontando = 1'b1;
                contaC = 1'b1;
            end
            fim_acertou: begin
                acertou = 1'b1;
            end
            fim_errou: begin
                errou = 1'b1;
            end
            prepara_relembrar: begin
                relembrando = 1'b1;
                zeraC = 1'b1;
                zeraR = 1'b1;
                leds_BM = 1'b1;
                zeraExibicao = 1'b1;
            end
            espera_memoria_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
            end
            registra_exibicao_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                zeraExibicao = 1'b1;
                registraExibicao = 1'b1;
            end
            transmite_H_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b000;
            end
            espera_H_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                selCaracter = 3'b000;
            end
            transmite_historia_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b001;
            end
            espera_historia_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                selCaracter = 3'b001;
            end
            transmite_virgula_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b010;
            end
            espera_virgula_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                selCaracter = 3'b010;
            end
            transmite_P_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b011;
            end
            espera_P_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                selCaracter = 3'b011;
            end
            transmite_personagem_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b100;
            end
            espera_personagem_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                selCaracter = 3'b100;
            end
            transmite_LF_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                partida_serial = 1'b1;
                selCaracter = 3'b101;
            end
            espera_LF_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                selCaracter = 3'b101;
            end
            mostra_jogada: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                contaExibicao = 1'b1;
            end
            zera_timer: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
                zeraExibicao = 1'b1;
            end
            verifica_fim_relembrar: begin
                relembrando = 1'b1;
                leds_BM = 1'b1;
            end
            aumenta_limite_relembrar: begin
                relembrando = 1'b1;
                contaC = 1'b1;
                leds_BM = 1'b1;
                zeraExibicao = 1'b1;
            end
            default: begin end
        endcase
    end

    assign db_estado = Eatual;
endmodule
