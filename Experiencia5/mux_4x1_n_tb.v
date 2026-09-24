/*
 *  Arquivo   : mux_4x1_n_tb.sv
 * ----------------------------------------------------------------
 *  Descricao : testbench do modulo multiplexador 4x1  
 * 
 *  > descricao em SystemVerilog 
 *  > implementa verificacao com vetor de teste
 * 
 * ----------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      16/09/2024  3.0     Edson Midorikawa  versao em Verilog
 * ----------------------------------------------------------------
 */
 
`timescale 1ns / 1ns

module mux_4x1_n_tb;

    parameter BITS = 4;
    // Largura total: D3(4) + D2(4) + D1(4) + D0(4) + SEL(2) + ESP(4) = 22 bits
    localparam TEST_WIDTH = (BITS * 5) + 2;

    reg [BITS-1:0] D3_IN, D2_IN, D1_IN, D0_IN;
    reg [1:0]      SEL_IN;
    wire [BITS-1:0] MUX_OUT;

    mux_4x1_n #(BITS) dut (
        .D3     (D3_IN  ),
        .D2     (D2_IN  ),
        .D1     (D1_IN  ),
        .D0     (D0_IN  ),
        .SEL    (SEL_IN ),
        .MUX_OUT(MUX_OUT)
    );

    reg [TEST_WIDTH-1:0] vetor_teste [0:9];
    integer caso;

    initial begin
        //                D3,    D2,    D1,    D0,    SEL,   ESPERADO
        vetor_teste[0] = {4'h0, 4'h0, 4'h0, 4'h0, 2'b00, 4'h0};
        vetor_teste[1] = {4'hF, 4'hF, 4'hF, 4'hF, 2'b11, 4'hF};
        vetor_teste[2] = {4'h3, 4'h2, 4'h1, 4'h0, 2'b00, 4'h0};
        vetor_teste[3] = {4'h3, 4'h2, 4'h1, 4'h0, 2'b01, 4'h1};
        vetor_teste[4] = {4'h3, 4'h2, 4'h1, 4'h0, 2'b10, 4'h2};
        vetor_teste[5] = {4'h3, 4'h2, 4'h1, 4'h0, 2'b11, 4'h3};
        vetor_teste[6] = {4'h3, 4'h3, 4'h3, 4'h3, 2'b10, 4'h3};
        vetor_teste[7] = {4'hE, 4'h2, 4'hC, 4'h5, 2'b00, 4'h5};
        vetor_teste[8] = {4'h5, 4'hB, 4'h5, 4'hB, 2'b11, 4'h5};
        vetor_teste[9] = {4'h1, 4'h2, 4'h3, 4'h4, 2'b00, 4'h4};

        $display("inicio da simulacao");

        for (caso = 0; caso < 10; caso = caso + 1) begin
            {D3_IN, D2_IN, D1_IN, D0_IN, SEL_IN} = vetor_teste[caso][TEST_WIDTH-1 : BITS];

            #20;

            if (MUX_OUT !== vetor_teste[caso][BITS-1:0])
                $display("caso %0d: TESTE FALHOU! SEL=%b, D0=%h, D1=%h, D2=%h, D3=%h, MUX_OUT=%h (esperado=%h)",
                         caso, SEL_IN, D0_IN, D1_IN, D2_IN, D3_IN, MUX_OUT, vetor_teste[caso][BITS-1:0]);
            else
                $display("caso %0d: TESTE OK! SEL=%b, D0=%h, D1=%h, D2=%h, D3=%h, MUX_OUT=%h (esperado=%h)",
                         caso, SEL_IN, D0_IN, D1_IN, D2_IN, D3_IN, MUX_OUT, vetor_teste[caso][BITS-1:0]);
        end

        $display("fim da simulacao");
        $stop;
    end

endmodule