//------------------------------------------------------------------
// Arquivo   : registrador_2.v
// Projeto   : Fábula TEA
//------------------------------------------------------------------
// Descricao : Registrador de 2 bits
//             
//------------------------------------------------------------------
// Revisoes  :
//     Data        Versao  Autor             Descricao
//     14/03/2026  1.0     Fernando Ivanov   versao inicial
//------------------------------------------------------------------
//

module registrador_2 (
    input        clock,
    input        clear,
    input        enable,
    input  [1:0] D,
    output [1:0] Q
);

    reg [1:0] IQ;

    always @(posedge clock or posedge clear) begin
        if (clear)
            IQ <= 0;
        else if (enable)
            IQ <= D;
    end

    assign Q = IQ;

endmodule