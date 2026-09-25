/*
 * rom_angulos_8x24_tb.v
 *
 * testbench em Verilog
 */
 
`timescale 1ns / 1ns

module rom_angulos_8x24_tb;

  reg [2:0] endereco;
  wire [23:0] saida;
  integer i;
  integer erros;

  // instanciacao do modulo ROM 
  rom_angulos_8x24 dut (
    .endereco(endereco),
    .saida   (saida   )
  );

  initial begin
    // ajusta endereco para valor inicial da varredura
    endereco = 3'b000;
    erros = 0;

    // varredura percorre todos os enderecos da ROM
    for (i = 0; i < 8; i = i + 1) begin
      #10; // atraso para visualizacao da saida

      // mostra endereco e valores de saida esperado e da ROM
      $display("Endereco: %0d, Saida esperada: %h, Saida da ROM: %h", 
               i, dut.tabela_angulos[i], saida); 

      // verifica se saida da ROM é igual ao valor esperado
      if (saida !== dut.tabela_angulos[i]) begin
        erros = erros + 1;
        $display("Erro no endereco %0d: Esperado=%h, Saida=%h", 
                    i, dut.tabela_angulos[i], saida);
      end

      // Incrementa endereco da varredura
      endereco = endereco + 1;
    end

    $display("Fim dos testes! Total de erros: %0d", erros);
    $stop;
  end

endmodule