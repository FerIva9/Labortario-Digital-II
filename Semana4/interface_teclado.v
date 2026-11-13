module interface_teclado #(
    parameter DEBOUNCE_DELAY = 1_000_000,
    parameter SCAN_LINE_CYCLES = 12_500
)(
    input wire clock,
    input wire reset,
    input wire [3:0] C,

    output reg [3:0] L,
    output reg [3:0] tecla,
    output reg tecla_valida
);

    // Clock esperado: 50 MHz
    // Cada linha: 250 us
    // Varredura completa: 1 ms
    // Debounce padrao: 20 ms

    localparam [4:0] SEM_TECLA = 5'd16;
    localparam [4:0] INVALIDA  = 5'd17;

    localparam integer CICLOS_VARREDURA =
        4 * SCAN_LINE_CYCLES;

    localparam integer AMOSTRAS_DEBOUNCE =
        (DEBOUNCE_DELAY + CICLOS_VARREDURA - 1)
        / CICLOS_VARREDURA;

    reg [31:0] contador_scan;
    reg [1:0] linha_atual;

    reg [3:0] C_sync0;
    reg [3:0] C_sync1;

    reg encontrou;
    reg invalida;
    reg [3:0] tecla_encontrada;

    reg [4:0] candidata;
    reg [4:0] estavel;
    reg [31:0] contador_debounce;
    reg armado;

    reg coluna_valida;
    reg [1:0] coluna_atual;

    reg encontrou_prox;
    reg invalida_prox;
    reg [3:0] tecla_prox;
    reg [4:0] leitura_completa;

    // Sincronizacao das colunas com o clock
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            C_sync0 <= 4'b1111;
            C_sync1 <= 4'b1111;
        end else begin
            C_sync0 <= C;
            C_sync1 <= C_sync0;
        end
    end

    // Varredura continua, usando open-drain
    always @(*) begin
        case (linha_atual)
            2'd0: L = 4'bZZZ0;
            2'd1: L = 4'bZZ0Z;
            2'd2: L = 4'bZ0ZZ;
            2'd3: L = 4'b0ZZZ;
            default: L = 4'bZZZZ;
        endcase
    end

    // Decodificacao das colunas
    always @(*) begin
        coluna_valida = 1'b1;
        coluna_atual = 2'd0;

        case (C_sync1)
            4'b1110: coluna_atual = 2'd0;
            4'b1101: coluna_atual = 2'd1;
            4'b1011: coluna_atual = 2'd2;
            4'b0111: coluna_atual = 2'd3;
            default: coluna_valida = 1'b0;
        endcase
    end

    // Mapeamento das teclas do teclado 4x4
    function [3:0] decodifica_tecla;
        input [1:0] linha;
        input [1:0] coluna;
        begin
            case ({linha, coluna})
                4'h0: decodifica_tecla = 4'd1;
                4'h1: decodifica_tecla = 4'd2;
                4'h2: decodifica_tecla = 4'd3;
                4'h3: decodifica_tecla = 4'd10;

                4'h4: decodifica_tecla = 4'd4;
                4'h5: decodifica_tecla = 4'd5;
                4'h6: decodifica_tecla = 4'd6;
                4'h7: decodifica_tecla = 4'd11;

                4'h8: decodifica_tecla = 4'd7;
                4'h9: decodifica_tecla = 4'd8;
                4'hA: decodifica_tecla = 4'd9;
                4'hB: decodifica_tecla = 4'd12;

                4'hC: decodifica_tecla = 4'd14;
                4'hD: decodifica_tecla = 4'd0;
                4'hE: decodifica_tecla = 4'd15;
                4'hF: decodifica_tecla = 4'd13;
            endcase
        end
    endfunction

    // Acumula as leituras das quatro linhas.
    // Mais de uma tecla torna a leitura invalida.
    always @(*) begin
        encontrou_prox = encontrou;
        invalida_prox = invalida;
        tecla_prox = tecla_encontrada;

        if (C_sync1 != 4'b1111) begin
            if (!coluna_valida) begin
                invalida_prox = 1'b1;
            end else if (encontrou) begin
                invalida_prox = 1'b1;
            end else begin
                encontrou_prox = 1'b1;
                tecla_prox =
                    decodifica_tecla(
                        linha_atual,
                        coluna_atual
                    );
            end
        end

        if (invalida_prox)
            leitura_completa = INVALIDA;
        else if (encontrou_prox)
            leitura_completa = {1'b0, tecla_prox};
        else
            leitura_completa = SEM_TECLA;
    end

    // Varredura e debounce
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            contador_scan <= 0;
            linha_atual <= 0;

            encontrou <= 0;
            invalida <= 0;
            tecla_encontrada <= 0;

            candidata <= SEM_TECLA;
            estavel <= SEM_TECLA;
            contador_debounce <= 0;
            armado <= 1'b1;

            tecla <= 0;
            tecla_valida <= 0;
        end else begin

            // Pulso de apenas um ciclo
            tecla_valida <= 1'b0;

            if (contador_scan == SCAN_LINE_CYCLES - 1) begin
                contador_scan <= 0;

                if (linha_atual == 2'd3) begin
                    // Terminou uma varredura completa
                    linha_atual <= 0;

                    encontrou <= 0;
                    invalida <= 0;
                    tecla_encontrada <= 0;

                    // Debounce por leituras completas
                    if (leitura_completa != candidata) begin
                        candidata <= leitura_completa;
                        contador_debounce <= 1;
                    end else if (
                        contador_debounce < AMOSTRAS_DEBOUNCE
                    ) begin
                        contador_debounce <=
                            contador_debounce + 1'b1;
                    end

                    // Aceita somente leitura estabilizada
                    if (
                        leitura_completa == candidata &&
                        contador_debounce >=
                            AMOSTRAS_DEBOUNCE - 1 &&
                        estavel != leitura_completa
                    ) begin
                        estavel <= leitura_completa;

                        if (leitura_completa == SEM_TECLA) begin
                            // Tecla solta: aceita novo evento
                            armado <= 1'b1;
                        end else if (
                            leitura_completa < SEM_TECLA &&
                            armado
                        ) begin
                            tecla <= leitura_completa[3:0];
                            tecla_valida <= 1'b1;
                            armado <= 1'b0;
                        end
                    end

                end else begin
                    // Proxima linha
                    linha_atual <= linha_atual + 1'b1;

                    encontrou <= encontrou_prox;
                    invalida <= invalida_prox;
                    tecla_encontrada <= tecla_prox;
                end

            end else begin
                contador_scan <= contador_scan + 1'b1;
            end
        end
    end

endmodule