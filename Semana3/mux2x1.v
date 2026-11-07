/*------------------------------------------------------------------------
 * Arquivo   : mux2x1.v
 * Projeto   : Fábula TEA
 *------------------------------------------------------------------------
 * Descricao : multiplexador 2x1 com palavras de 6 bits
 *------------------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     15/02/2024  1.0     Edson Midorikawa  criacao
 *     31/01/2025  1.1     Edson Midorikawa  revisao
 *     05/02/2026  1.2     Guilherme Muller  mudou para mux de 4 bits
 *     14/03/2026  1.3     Fernando Ivanov   mudou para mux de 6 bits
 *------------------------------------------------------------------------
 */

module mux2x1 (
    input       [5:0]   D0,
    input       [5:0]   D1,
    input               SEL,
    output reg  [5:0]   OUT
);

always @(*) begin
    case (SEL)
        1'b0:    OUT = D0;
        1'b1:    OUT = D1;
        default: OUT = 6'b111111;
    endcase
end

endmodule
