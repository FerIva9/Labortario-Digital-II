module sync_ram_128x6_file #(
    parameter BINFILE = "ram_init.txt"
)(
    input wire clk,
    input wire we,
    input wire [5:0] data,
    input wire [6:0] addr,
    output wire [5:0] q
);

    reg [5:0] ram [0:127];

    reg [6:0] addr_reg;

    initial begin
        $readmemb(BINFILE, ram);
    end

    always @(posedge clk) begin
        if (we)
            ram[addr] <= data;

        addr_reg <= addr;
    end

    assign q = ram[addr_reg];

endmodule
