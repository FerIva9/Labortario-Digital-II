/* -------------------------------------------------------------
 * Arquivo   : trena_digital_uc.v
 *--------------------------------------------------------------
 * Descricao : unidade de controle da trena digital 
 * 
 *--------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     19/09/2025  1.0     Fernando Ivanov   criacao
 *--------------------------------------------------------------
 */

module trena_digital_uc (
    input wire clock,
    input wire reset,

    // Entradas vindas do fluxo de dados
    input wire pulso_mensurar,
    input wire pronto_sensor,
    input wire pronto_serial,

    // Sinais de controle para o fluxo de dados
    output reg reset_fd,
    output reg medir,
    output reg [1:0] sel_ascii,
    output reg partida,

    // Sinal de término do sistema
    output reg pronto,

    // Depuração
    output reg [3:0] db_estado

);

    reg [3:0] Eatual, Eprox;

    // Estados
    parameter inicial            = 4'b0000; // 0
    parameter preparacao         = 4'b0001; // 1
    parameter inicia_medida      = 4'b0010; // 2
    parameter aguarda_medida     = 4'b0011; // 3
    parameter transmite_centena  = 4'b0100; // 4
    parameter espera_centena     = 4'b0101; // 5
    parameter transmite_dezena   = 4'b0110; // 6
    parameter espera_dezena      = 4'b0111; // 7
    parameter transmite_unidade  = 4'b1000; // 8
    parameter espera_unidade     = 4'b1001; // 9
    parameter transmite_hashtag  = 4'b1010; // 10
    parameter espera_hashtag     = 4'b1011; // 11
    parameter final_medida       = 4'b1100; // 12

    always @(posedge clock, posedge reset) begin
        if (reset)
            Eatual <= inicial;
        else
            Eatual <= Eprox;
    end

    always @(*) begin
        case (Eatual)
        
            inicial:
                Eprox = pulso_mensurar ?
                        preparacao :
                        inicial;

            preparacao:
                Eprox = inicia_medida;

            inicia_medida:
                Eprox = aguarda_medida;

            aguarda_medida:
                Eprox = pronto_sensor ?
                        transmite_centena :
                        aguarda_medida;

            transmite_centena:
                Eprox = espera_centena;

            espera_centena:
                Eprox = pronto_serial ?
                        transmite_dezena :
                        espera_centena;

            transmite_dezena:
                Eprox = espera_dezena;

            espera_dezena:
                Eprox = pronto_serial ?
                        transmite_unidade :
                        espera_dezena;

            transmite_unidade:
                Eprox = espera_unidade;

            espera_unidade:
                Eprox = pronto_serial ?
                        transmite_hashtag :
                        espera_unidade;

            transmite_hashtag:
                Eprox = espera_hashtag;

            espera_hashtag:
                Eprox = pronto_serial ?
                        final_medida :
                        espera_hashtag;

            final_medida:
                Eprox = inicial;

            default:
                Eprox = inicial;
        endcase
    end



    always @(*) begin

        // Valores padrão
        reset_fd  = 1'b0;
        medir     = 1'b0;
        sel_ascii = 2'b00;
        partida   = 1'b0;
        pronto    = 1'b0;

        case (Eatual)
            preparacao:
                reset_fd = 1'b1;

            inicia_medida:
                medir = 1'b1;

            transmite_centena: begin
                sel_ascii = 2'b00;
                partida   = 1'b1;
            end

            espera_centena: begin
                sel_ascii = 2'b00;
                partida   = 1'b0;
            end

            transmite_dezena: begin
                sel_ascii = 2'b01;
                partida   = 1'b1;
            end

            espera_dezena: begin
                sel_ascii = 2'b01;
                partida   = 1'b0;
            end

            transmite_unidade: begin
                sel_ascii = 2'b10;
                partida   = 1'b1;
            end

            espera_unidade: begin
                sel_ascii = 2'b10;
                partida   = 1'b0;
            end

            transmite_hashtag: begin
                sel_ascii = 2'b11;
                partida   = 1'b1;
            end

            espera_hashtag: begin
                sel_ascii = 2'b11;
                partida   = 1'b0;
            end

            final_medida:
                pronto = 1'b1;

            default: begin
                reset_fd  = 1'b0;
                medir     = 1'b0;
                sel_ascii = 2'b00;
                partida   = 1'b0;
                pronto    = 1'b0;
            end
        endcase
    end

    // Depuração

    always @(*) begin
        case (Eatual)

            inicial:
                db_estado = 4'b0000;

            preparacao:
                db_estado = 4'b0001;

            inicia_medida:
                db_estado = 4'b0010;

            aguarda_medida:
                db_estado = 4'b0011;

            transmite_centena:
                db_estado = 4'b0100;

            espera_centena:
                db_estado = 4'b0101;

            transmite_dezena:
                db_estado = 4'b0110;

            espera_dezena:
                db_estado = 4'b0111;

            transmite_unidade:
                db_estado = 4'b1000;

            espera_unidade:
                db_estado = 4'b1001;

            transmite_hashtag:
                db_estado = 4'b1010;

            espera_hashtag:
                db_estado = 4'b1011;

            final_medida:
                db_estado = 4'b1100;

            default:
                db_estado = 4'b1111;
        endcase
    end


endmodule