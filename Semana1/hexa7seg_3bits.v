// Decodificador hexadecimal de 3 bits para display ativo em nivel baixo.
// enable=0 apaga o display; usado durante reset em HEX0 e HEX5.
module hexa7seg_3bits (
    input wire [2:0] hexa,
    input wire enable,
    output reg [6:0] display
);
    always @(*) begin
        if (!enable) begin
            display = 7'b1111111;
        end else begin
            case (hexa)
                3'd0: display = 7'b1000000;
                3'd1: display = 7'b1111001;
                3'd2: display = 7'b0100100;
                3'd3: display = 7'b0110000;
                3'd4: display = 7'b0011001;
                3'd5: display = 7'b0010010;
                3'd6: display = 7'b0000010;
                3'd7: display = 7'b1111000;
                default: display = 7'b1111111;
            endcase
        end
    end
endmodule
