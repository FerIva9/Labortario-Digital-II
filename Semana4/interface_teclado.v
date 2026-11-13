
module interface_teclado #(
    parameter DEBOUNCE_DELAY = 1_000_000
)(
    input wire clock,
    input wire reset,
    input wire [3:0] C,

    output reg [3:0] L,
    output reg [3:0] tecla,
    output reg tecla_valida
);

    // -------------------------------------------------------
    // Estados da interface
    // -------------------------------------------------------

    localparam [2:0]
        ESPERA_TECLA      = 3'd0,
        ESTABILIZA_LINHA  = 3'd1,
        LE_COLUNAS        = 3'd2,
        FINALIZA_LEITURA  = 3'd3,
        ESPERA_SOLTAR     = 3'd4;

    reg [2:0] Eatual;

    // -------------------------------------------------------
    // Registradores e sinais internos
    // -------------------------------------------------------

    reg [1:0] linha_atual;
    reg [1:0] espera_linha;

    reg [3:0] C_sync0;
    reg [3:0] C_sync1;

    wire alguma_tecla;
    wire tecla_estavel;

    reg encontrou_tecla;
    reg leitura_invalida;
    reg [3:0] tecla_encontrada;

    reg coluna_valida;
    reg [1:0] coluna_atual;

    // -------------------------------------------------------
    // Sincronizacao das entradas das colunas
    // -------------------------------------------------------

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            C_sync0 <= 4'b1111;
            C_sync1 <= 4'b1111;
        end else begin
            C_sync0 <= C;
            C_sync1 <= C_sync0;
        end
    end

    // -------------------------------------------------------
    // Detector de presenca de alguma tecla
    // -------------------------------------------------------

    assign alguma_tecla = ~(&C_sync1);

    debounce #(.DELAY(DEBOUNCE_DELAY)) DB_TECLADO (
        .clk(clock),
        .button_in(alguma_tecla),
        .button_out(tecla_estavel)
    );

    // -------------------------------------------------------
    // Controle das linhas da matriz
    // -------------------------------------------------------

    always @(*) begin
        L = 4'b0000;

        if (Eatual == ESTABILIZA_LINHA ||
            Eatual == LE_COLUNAS) begin

            case (linha_atual)
                2'd0: L = 4'bZZZ0;
                2'd1: L = 4'bZZ0Z;
                2'd2: L = 4'bZ0ZZ;
                2'd3: L = 4'b0ZZZ;
                default: L = 4'bZZZZ;
            endcase
        end
    end

    // -------------------------------------------------------
    // Decodificador das colunas
    // -------------------------------------------------------

    always @(*) begin
        coluna_valida = 1'b1;
        coluna_atual = 2'd0;

        case (C_sync1)
            4'b1110: coluna_atual = 2'd0;
            4'b1101: coluna_atual = 2'd1;
            4'b1011: coluna_atual = 2'd2;
            4'b0111: coluna_atual = 2'd3;

            default: begin
                coluna_valida = 1'b0;
                coluna_atual = 2'd0;
            end
        endcase
    end

    // -------------------------------------------------------
    // Decodificador da tecla
    // -------------------------------------------------------

    function [3:0] decodifica_tecla;
        input [1:0] linha;
        input [1:0] coluna;

        begin
            case ({linha, coluna})
                4'b0000: decodifica_tecla = 4'd1;
                4'b0001: decodifica_tecla = 4'd2;
                4'b0010: decodifica_tecla = 4'd3;
                4'b0011: decodifica_tecla = 4'd10; // A

                4'b0100: decodifica_tecla = 4'd4;
                4'b0101: decodifica_tecla = 4'd5;
                4'b0110: decodifica_tecla = 4'd6;
                4'b0111: decodifica_tecla = 4'd11; // B

                4'b1000: decodifica_tecla = 4'd7;
                4'b1001: decodifica_tecla = 4'd8;
                4'b1010: decodifica_tecla = 4'd9;
                4'b1011: decodifica_tecla = 4'd12; // C

                4'b1100: decodifica_tecla = 4'd14; // *
                4'b1101: decodifica_tecla = 4'd0;
                4'b1110: decodifica_tecla = 4'd15; // #
                4'b1111: decodifica_tecla = 4'd13; // D

                default: decodifica_tecla = 4'd0;
            endcase
        end
    endfunction

    // -------------------------------------------------------
    // Maquina de estados da interface
    // -------------------------------------------------------

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            Eatual <= ESPERA_TECLA;

            linha_atual <= 2'd0;
            espera_linha <= 2'd0;

            encontrou_tecla <= 1'b0;
            leitura_invalida <= 1'b0;
            tecla_encontrada <= 4'd0;

            tecla <= 4'd0;
            tecla_valida <= 1'b0;
        end else begin

            // Pulso de apenas um ciclo
            tecla_valida <= 1'b0;

            case (Eatual)

                ESPERA_TECLA: begin
                    if (tecla_estavel) begin
                        linha_atual <= 2'd0;
                        espera_linha <= 2'd0;

                        encontrou_tecla <= 1'b0;
                        leitura_invalida <= 1'b0;

                        Eatual <= ESTABILIZA_LINHA;
                    end
                end

                ESTABILIZA_LINHA: begin
                    // Aguarda a propagacao dos sinais
                    // e a sincronizacao das colunas.

                    if (espera_linha == 2'd2) begin
                        espera_linha <= 2'd0;
                        Eatual <= LE_COLUNAS;
                    end else begin
                        espera_linha <= espera_linha + 1'b1;
                    end
                end

                LE_COLUNAS: begin

                    if (coluna_valida) begin
                        if (encontrou_tecla) begin
                            // Mais de uma tecla encontrada
                            leitura_invalida <= 1'b1;
                        end else begin
                            encontrou_tecla <= 1'b1;

                            tecla_encontrada <=
                                decodifica_tecla(
                                    linha_atual,
                                    coluna_atual
                                );
                        end
                    end else if (C_sync1 != 4'b1111) begin
                        // Multiplas colunas ativas
                        leitura_invalida <= 1'b1;
                    end

                    if (linha_atual == 2'd3) begin
                        Eatual <= FINALIZA_LEITURA;
                    end else begin
                        linha_atual <= linha_atual + 1'b1;
                        espera_linha <= 2'd0;
                        Eatual <= ESTABILIZA_LINHA;
                    end
                end

                FINALIZA_LEITURA: begin
                    if (encontrou_tecla && !leitura_invalida) begin
                        tecla <= tecla_encontrada;
                        tecla_valida <= 1'b1;
                    end

                    Eatual <= ESPERA_SOLTAR;
                end

                ESPERA_SOLTAR: begin
                    if (!tecla_estavel) begin
                        Eatual <= ESPERA_TECLA;
                    end
                end

                default: begin
                    Eatual <= ESPERA_TECLA;
                end

            endcase
        end
    end

endmodule
