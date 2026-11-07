// Converte o personagem de seis bits (um unico bit ativo) em posicao 0 a 5.
// Combinacional: codigos invalidos produzem valido=0 e posicao=0.
// A carga do registrador de exibicao deve ser condicionada a valido.
module codificadorPersonagem (
    input  wire [5:0] personagem,
    output reg  [2:0] posicao,
    output reg        valido
);

    always @(*) begin
        valido = 1'b1;

        case (personagem)
            6'b000001: posicao = 3'd0; // 15 graus
            6'b000010: posicao = 3'd1; // 45 graus
            6'b000100: posicao = 3'd2; // 75 graus
            6'b001000: posicao = 3'd3; // 105 graus
            6'b010000: posicao = 3'd4; // 135 graus
            6'b100000: posicao = 3'd5; // 165 graus
            default: begin
                posicao = 3'd0;
                valido = 1'b0;
            end
        endcase
    end

endmodule
