//------------------------------------------------------------------
// Arquivo   : registrador_6.v
// Projeto   : Fábula TEA
//------------------------------------------------------------------
// Descricao : Registrador de 6 bits
//             
//------------------------------------------------------------------
// Revisoes  :
//     Data        Versao  Autor             Descricao
//     14/03/2026  1.0     Fernando Ivanov   versao inicial
//------------------------------------------------------------------
//

module registrador_6 (
    input        clock,
    input        clear,
    input        enable,
    input  [5:0] D,
    output [5:0] Q
);

    reg [5:0] IQ;

    always @(posedge clock or posedge clear) begin
        if (clear)
            IQ <= 0;
        else if (enable)
            IQ <= D;
    end

    assign Q = IQ;

endmodule