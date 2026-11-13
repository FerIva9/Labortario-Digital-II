module comparador_7bits (
    input wire [6:0] A,
    input wire [6:0] B,
    input wire ALBi,
    input wire AGBi,
    input wire AEBi,

    output wire ALBo,
    output wire AGBo,
    output wire AEBo
);

    assign ALBo = (A < B) | ((A == B) & ALBi);
    assign AGBo = (A > B) | ((A == B) & AGBi);
    assign AEBo = (A == B) & AEBi;

endmodule