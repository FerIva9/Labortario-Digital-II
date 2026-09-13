/* --------------------------------------------------------------------------
 *  Arquivo   : contador_cm_uc-PARCIAL.v
 * --------------------------------------------------------------------------
 *  Descricao : unidade de controle do componente contador_cm
 *
 *              incrementa contagem de cm a cada sinal de tick enquanto
 *              o pulso de entrada permanece ativo
 *
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 *      13/09/2026  1.1     Guilherme Muller  versao preenchida
 * --------------------------------------------------------------------------
 */

module contador_cm_uc (
    input wire clock,
    input wire reset,
    input wire pulso,
    input wire tick,
    output reg zera_tick,
    output reg conta_tick,
    output reg zera_bcd,
    output reg conta_bcd,
    output reg pronto
);

    reg [2:0] Eatual, Eprox;

    parameter inicial = 3'b000;
    parameter preparacao = 3'b001;
    parameter espera = 3'b010;
    parameter conta = 3'b011;
    parameter final_estado = 3'b100;

    always @(posedge clock or posedge reset) begin
        if (reset)
            Eatual <= inicial;
        else
            Eatual <= Eprox;
    end

    always @(*) begin
        case (Eatual)
            inicial:      Eprox = pulso ? preparacao : inicial;
            preparacao:   Eprox = espera;
            espera:       Eprox = tick ? conta : (pulso ? espera : final_estado);
            conta:        Eprox = espera;
            final_estado: Eprox = inicial;
            default:      Eprox = inicial;
        endcase
    end

    always @(*) begin
        zera_bcd = (Eatual == preparacao) ? 1'b1 : 1'b0;
        zera_tick = (Eatual == preparacao) ? 1'b1 : 1'b0;
        conta_bcd = (Eatual == conta) ? 1'b1 : 1'b0;
        conta_tick = (Eatual == conta) ? 1'b1 : 1'b0;
        pronto = (Eatual == final_estado) ? 1'b1 : 1'b0;
    end

endmodule
