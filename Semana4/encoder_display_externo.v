 module encoder_display_externo (
    input wire [3:0] digito,
    input wire enable,
    output reg [6:0] segmentos
);

    // Segmentos: {a, b, c, d, e, f, g}
    // 0 = aceso
    // 1 = apagado

    always @(*) begin
        if (!enable) begin
            segmentos = 7'b1111111;
        end
        else begin
            case (digito)
                4'd0: segmentos = 7'b0000001;
                4'd1: segmentos = 7'b1001111;
                4'd2: segmentos = 7'b0010010;
                4'd3: segmentos = 7'b0000110;
                4'd4: segmentos = 7'b1001100;
                4'd5: segmentos = 7'b0100100;
                4'd6: segmentos = 7'b0100000;
                4'd7: segmentos = 7'b0001111;
                4'd8: segmentos = 7'b0000000;
                4'd9: segmentos = 7'b0000100;
                default: segmentos = 7'b1111111;
            endcase
        end
    end

endmodule
