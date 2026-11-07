// Converte os caracteres ASCII '0' a '5' para a jogada de seis bits.
// Combinacional: valido indica o conteudo, nao uma nova recepcao serial.
module decodificadorASCII (
    input  wire [6:0] ascii,
    output reg  [5:0] jogada,
    output reg        valido
);

    always @(*) begin
        valido = 1'b1;

        case (ascii)
            7'h30: jogada = 6'b000001; // '0'
            7'h31: jogada = 6'b000010; // '1'
            7'h32: jogada = 6'b000100; // '2'
            7'h33: jogada = 6'b001000; // '3'
            7'h34: jogada = 6'b010000; // '4'
            7'h35: jogada = 6'b100000; // '5'
            default: begin
                jogada = 6'b000000;
                valido = 1'b0;
            end
        endcase
    end

endmodule
