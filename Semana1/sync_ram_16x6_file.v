//------------------------------------------------------------------
// Arquivo   : sync_ram_16x6_file.v
// Projeto   : Fábula TEA
 
//------------------------------------------------------------------
// Descricao : RAM sincrona 16x6
//
//   - conteudo inicial armazenado em arquivo .txt
//   - descricao baseada em template 'single_port_ram_with_init.v' 
//     do Intel Quartus Prime
//             
//------------------------------------------------------------------
// Revisoes  :
//     Data        Versao  Autor             Descricao
//     02/02/2024  1.0     Edson Midorikawa  versao inicial
//     20/02/2026  1.1     Fernando Ivanov   revisão
//     14/03/2026  2.0     Fernando Ivanov   RAM 16x6
//------------------------------------------------------------------
//

module sync_ram_16x6_file #(
    parameter BINFILE = "ram_init.txt"
)
(
    input        clk,
    input        we,
    input  [5:0] data,
    input  [3:0] addr,
    output [5:0] q
);

    // Variavel RAM (armazena dados)
    reg [5:0] ram [15:0];

    // Registra endereco de acesso
    reg [3:0] addr_reg;

    // Inicializa a RAM a partir de arquivo
    initial 
    begin : INICIA_RAM
        $readmemb(BINFILE, ram);
    end 

    always @ (posedge clk)
    begin
        // Escrita
        if (we)
            ram[addr] <= data;

        addr_reg <= addr;
    end

    // Leitura sincronizada
    assign q = ram[addr_reg];

endmodule
