module conversor_tamanho (
    input  wire [3:0] dezena,
    input  wire [3:0] unidade,

    output reg  [3:0] limite,
    output wire tamanho_valido
);

    wire [6:0] tamanho_decimal;

    assign tamanho_decimal = dezena * 7'd10 + unidade;

    // Nao permitimos historia com zero personagens.
    assign tamanho_valido = (tamanho_decimal != 7'd0);

    always @(*) begin
        if (tamanho_decimal == 7'd0)
            limite = 4'd0;
        else if (tamanho_decimal >= 7'd16)
            limite = 4'd15;
        else
            limite = tamanho_decimal - 7'd1;
    end

endmodule
