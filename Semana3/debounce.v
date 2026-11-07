//------------------------------------------------------------------
// Arquivo   : debounce.v
// Projeto   : Fábula TEA
//------------------------------------------------------------------
// Descricao : debounce de botão eletromecânico
//             
//------------------------------------------------------------------
// Revisoes  :
//     Data        Versao  Autor             Descricao
//     25/03/2026  1.0     Fernando Ivanov   versao inicial
//     07/11/2026  1.1     Fernando Ivanov   adaptado para LabDigII
//------------------------------------------------------------------
//

module debounce #(
    parameter DELAY = 20 // para clock de 1kHz
)(
    input  wire clk,
    input  wire button_in,
    output reg  button_out = 0
);

    reg sync0 = 0, sync1 = 0;

    localparam COUNTER_BITS = $clog2(DELAY);
    reg [COUNTER_BITS-1:0] counter = 0;

    always @(posedge clk) begin
        sync0 <= button_in;
        sync1 <= sync0;

        if (sync1 != button_out) begin
            if (counter == DELAY-1) begin
                button_out <= sync1;
                counter <= 0;
            end else begin
                counter <= counter + 1'b1;
            end
        end else begin
            counter <= 0;
        end
    end

endmodule