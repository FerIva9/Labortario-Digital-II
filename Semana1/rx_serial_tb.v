/* ---------------------------------------------------------------------------
 *  Arquivo   : rx_serial_tb.v
 * ---------------------------------------------------------------------------
 *  Descricao : testbench basico para o circuito de recepcao serial assincrona
 *              usa task UART_WRITE_BYTE para envio de bits seriais
 *              pode ser usado para verificar diversas configuracoes seriais
 *
 *  modulo rx_serial_8N1 de autoria de Augusto Vaccarelli
 * ---------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      28/10/2024  4.0     Edson Midorikawa  versao em Verilog
 *      27/09/2026  1.0     Edson Midorikawa  revisao para 7E1
 * ---------------------------------------------------------------------------
 */
 
`timescale 1ns/1ns

module rx_serial_tb;

  // Declaração de sinais para conectar o componente a ser testado (DUT)
  reg         clock_in;
  reg         reset_in;
  wire        pronto_out;
  wire [6:0]  dados_ascii_out;
  wire        paridade_out;
  wire        paridade_par_out;

  // Sinais usados com UART_WRITE_BYTE
  reg         Sinal_Serial;
  reg [7:0]   serialData;

  // Configurações do clock
  parameter clockPeriod = 20; // clock 50MHz
  parameter bitPeriod   = 434*clockPeriod; // 115.200 bauds

  // Gerador de clock
  always #(clockPeriod/2) clock_in = ~clock_in;

  // UART_WRITE_BYTE()
  // Procedimento para geracao da sequencia de comunicacao serial
  // - com envio de 8 dados seriais + 2 stop bits
  // - adaptacao de codigo acessado de:
  //   https://nandland.com/uart-serial-port-module/
  // - pode ser usado para testar diversas configurações (7O1, 8E1,7N2, etc)
  task UART_WRITE_BYTE;
    input [7:0] Data_In;
    integer ii;
    begin

      // envia Start Bit
      Sinal_Serial = 1'b0;
      #bitPeriod;

      // envia 8 bits seriais
      for (ii=0; ii<8; ii=ii+1) begin
        Sinal_Serial = Data_In[ii];
        #bitPeriod;
      end

      // envia 2 Stop Bits
      Sinal_Serial = 1'b1;
      #(2*bitPeriod); 

    end
  endtask

  // Casos de teste: bit [7] e a paridade, bits [6:0] sao o dado ASCII.
  reg [7:0] casos_teste [0:7];

  integer caso;

  // Instanciação do DUT (Device Under Test)
  // => instancia modulo rx_serial_8N1 de autoria de Augusto Vaccarelli
  rx_serial_7E1 DUT (
    .clock       ( clock_in         ),
    .reset       ( reset_in         ), 
    .RX          ( Sinal_Serial     ),
    .pronto      ( pronto_out       ),
    .dados_ascii ( dados_ascii_out  ),
    .paridade    ( paridade_out     ),
    .paridade_par( paridade_par_out ),
    .db_clock    (                  ), // desconectados
    .db_tick     (                  ),
    .db_estado   (                  )    
  );                                

  // Geracao dos sinais de entrada (estimulo)
  initial begin
    // inicio da simulacao
    $display("Inicio da simulacao");

    // Valores iniciais e casos de teste
    clock_in = 1'b0;
    reset_in = 1'b0;
    Sinal_Serial = 1'b1;
    casos_teste[0] = 8'b00110101; // 35H, paridade correta
    casos_teste[1] = 8'b11010101; // 55H, paridade incorreta
    casos_teste[2] = 8'b11111101; // 7DH, paridade incorreta
    casos_teste[3] = 8'b10110101; // 35H, paridade incorreta
    casos_teste[4] = 8'b01000001; // 41H, paridade correta
    casos_teste[5] = 8'b11000001; // 41H, paridade incorreta
    casos_teste[6] = 8'b00000000; // 00H, paridade correta
    casos_teste[7] = 8'b10000000; // 00H, paridade incorreta

    // reset com 5 periodos de clock
    reset_in = 1'b1;
    #(5*clockPeriod);
    reset_in = 1'b0;
    #bitPeriod;

    // loop pelos casos de teste
    for (caso=0; caso<8; caso=caso+1) begin
      $display("Caso de teste %0d", caso+1);
      serialData = casos_teste[caso];

      // 1) aguarda 2 periodos de bit antes de enviar bits
      # (2*bitPeriod);

      // 2) envia bits seriais para circuito de recepcao 
      //    usando task UART_WRITE_BYTE()
      UART_WRITE_BYTE(serialData);
      #bitPeriod;

      // 3) intervalo entre casos de teste
      # (2*bitPeriod);
    end

    // final dos casos de teste da simulacao
    caso = 99;

    // fim da simulação
    $display("Fim da simulacao");
    $stop;
  end

endmodule
