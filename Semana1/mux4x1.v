/*------------------------------------------------------------------------
 * Arquivo   : mux4x1.v
 * Projeto   : Fábula TEA
 *------------------------------------------------------------------------
 * Descricao : multiplexador 4x1 com palavras de 4 bits
 *------------------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     14/03/2026  1.0     Fernando Ivanov  criacao
 *------------------------------------------------------------------------
 */

module mux4x1 (
    input       [3:0]   D0,
    input       [3:0]   D1,
    input       [3:0]   D2,
    input       [3:0]   D3,
    input       [1:0]   SEL,
    output reg  [3:0]   OUT
);

always @(*) begin
    case (SEL)
        2'b00:   OUT = D0;
        2'b01:   OUT = D1;
        2'b10:   OUT = D2;
        2'b11:   OUT = D3;
        default: OUT = 4'b1111;
    endcase
end

endmodule