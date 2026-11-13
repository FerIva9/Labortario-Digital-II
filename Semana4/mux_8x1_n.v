module mux_8x1_n #(
    parameter BITS = 4
) (
    input [BITS-1:0] D7,
    input [BITS-1:0] D6,
    input [BITS-1:0] D5,
    input [BITS-1:0] D4,
    input [BITS-1:0] D3,
    input [BITS-1:0] D2,
    input [BITS-1:0] D1,
    input [BITS-1:0] D0,
    input [2:0] SEL,
    output reg [BITS-1:0] MUX_OUT
);
    always @(*) begin
        case (SEL)
            3'b000: MUX_OUT = D0;
            3'b001: MUX_OUT = D1;
            3'b010: MUX_OUT = D2;
            3'b011: MUX_OUT = D3;
            3'b100: MUX_OUT = D4;
            3'b101: MUX_OUT = D5;
            3'b110: MUX_OUT = D6;
            3'b111: MUX_OUT = D7;
            // Selecao desconhecida na simulacao: evidencia o problema.
            default: MUX_OUT = {BITS{1'bx}};
        endcase
    end
endmodule
