module conversor_tamanho (
    input wire [3:0] dezena,
    input wire [3:0] unidade,

    output reg [6:0] limite,
    output wire tamanho_valido
);

    wire [6:0] tamanho_decimal;

    assign tamanho_decimal = dezena * 7'd10 + unidade;

    assign tamanho_valido =
        (dezena <= 4'd9) &&
        (unidade <= 4'd9) &&
        (tamanho_decimal >= 7'd1) &&
        (tamanho_decimal <= 7'd99);

    always @(*) begin
        if (tamanho_valido)
            limite = tamanho_decimal - 7'd1;
        else
            limite = 7'd0;
    end

endmodule