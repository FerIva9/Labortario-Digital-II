/*--------------------------------------------------------------
 * Arquivo   : estado7seg.v
 * Projeto   : Jogo do Desafio da Memoria
 * -------------------------------------------------------------
 * Descricao : decodificador estado para 
 *             display de 7 segmentos 
 * 
 * entrada: estado - codigo binario de 5 bits
 * saida: display - codigo de 7 bits para display de 7 segmentos
 * ----------------------------------------------------------------
 * dica de uso: mapeamento para displays da placa DE0-CV
 *              bit 6 mais significativo é o bit a esquerda
 *              p.ex. display(6) -> HEX0[6] ou HEX06
 * ----------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             	Descricao
 *     09/02/2021  1.0     Edson Midorikawa  	criacao
 *     30/01/2025  2.0     Edson Midorikawa  	revisao p/ Verilog
 * 	 11/02/2025  2.1 		Augusto Vaccarelli 	revisao
 * ----------------------------------------------------------------
 */

module estado7seg (estado, display);
    input      [4:0] estado;
    output reg [6:0] display;


always @(*) begin
    case (estado)
        5'b00000: display = 7'b1000000;  // 0
        5'b00001: display = 7'b1111001;  // 1
        5'b00010: display = 7'b0100100;  // 2
        5'b00011: display = 7'b0110000;  // 3
        5'b00100: display = 7'b0011001;  // 4
        5'b00101: display = 7'b0010010;  // 5
        5'b00110: display = 7'b0000010;  // 6
        5'b00111: display = 7'b1111000;  // 7
        5'b01000: display = 7'b0000000;  // 8
        5'b01001: display = 7'b0010000;  // 9
        5'b01010: display = 7'b0001000;  // A
        5'b01011: display = 7'b0000011;  // B
        5'b01100: display = 7'b1000110;  // C
        5'b01101: display = 7'b0100001;  // D
        5'b01110: display = 7'b0000110;  // E
        5'b01111: display = 7'b0001110;  // F
        5'b10000: display = 7'b1111110;  // 10
        5'b10001: display = 7'b1111101;  // 11
        5'b10010: display = 7'b1111011;  // 12
        5'b10011: display = 7'b1110111;  // 13
        5'b10100: display = 7'b1101111;  // 14
        5'b10101: display = 7'b1011111;  // 15
        5'b10110: display = 7'b0111111;  // 16
        5'b10111: display = 7'b1111100;  // 17
        5'b11000: display = 7'b1110011;  // 18
        5'b11001: display = 7'b1100111;  // 19
        5'b11010: display = 7'b1001111;  // 1A
        5'b11011: display = 7'b0011111;  // 1B
        5'b11100: display = 7'b1110001;  // 1C
        5'b11101: display = 7'b1100011;  // 1D
        5'b11110: display = 7'b1000111;  // 1E
        5'b11111: display = 7'b0001111;  // 1F
        default:  display = 7'b1111111;
    endcase
end

endmodule


