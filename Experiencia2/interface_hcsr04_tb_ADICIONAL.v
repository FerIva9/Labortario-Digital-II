`timescale 1ns/1ns
 
module interface_hcsr04_tb_ADICIONAL;
 
    // Declaracao de sinais
    reg         clock_in = 0;
    reg         reset_in = 0;
    reg         medir_in = 0;
    reg         echo_in = 0;
    wire        trigger_out;
    wire [11:0] medida_out;
    wire        pronto_out;
    wire [3:0]  db_estado_out;
 
    // Componente a ser testado (Device Under Test -- DUT)
    interface_hcsr04 dut (
        .clock    (clock_in     ),
        .reset    (reset_in     ),
        .medir    (medir_in     ),
        .echo     (echo_in      ),
        .trigger  (trigger_out  ),
        .medida   (medida_out   ),
        .pronto   (pronto_out   ),
        .db_estado(db_estado_out)
    );
 
    // Configuracoes do clock
    parameter clockPeriod = 20; // clock de 50 MHz
 
    // Gerador de clock
    always #(clockPeriod/2) clock_in = ~clock_in;
 
    // Array de casos de teste
    reg [31:0] casos_teste [0:2];
 
    integer caso;
 
    // Largura do pulso echo
    reg [31:0] larguraPulso;
 
    // Geracao dos sinais de entrada
    initial begin
        $display("Inicio das simulacoes ADICIONAIS");
 
        /*
         * Casos de teste:
         *
         * 0) Aproximadamente 2 cm   -> distancia minima
         * 1) Aproximadamente 400 cm -> distancia maxima
         * 2) Aproximadamente 100,50 cm -> limite de arredondamento
         *
         * Os valores representam a duracao do pulso echo em us.
         */
 
        casos_teste[0] = 118;     // aproximadamente 2 cm
        casos_teste[1] = 23529;   // aproximadamente 400 cm
        casos_teste[2] = 5911;    // aproximadamente 100,50 cm
 
        // Valores iniciais
        medir_in = 0;
        echo_in  = 0;
 
        // Reset
        caso = 0;
        #(2*clockPeriod);
 
        reset_in = 1;
        #(2_000); // 2 us
        reset_in = 0;
 
        @(negedge clock_in);
 
        // Espera inicial
        #(100_000); // 100 us
 
        // Loop pelos casos de teste
        for (caso = 1; caso < 4; caso = caso + 1) begin
 
            // 1) Determina a largura do pulso echo
            $display("----------------------------------------");
            $display("Caso de teste adicional %0d", caso);
            $display("Largura do echo: %0dus", casos_teste[caso-1]);
 
            larguraPulso = casos_teste[caso-1] * 1000;
 
            // 2) Envia pulso medir
            @(negedge clock_in);
 
            medir_in = 1;
            #(5*clockPeriod);
            medir_in = 0;
 
            // 3) Espera pelo trigger e pelo inicio da resposta
            #(400_000); // 400 us
 
            // 4) Emula o sensor HC-SR04
            //    O echo permanece em nivel alto durante
            //    o tempo correspondente a distancia simulada.
            echo_in = 1;
            #(larguraPulso);
            echo_in = 0;
 
            // 5) Espera o termino da medicao
            wait (pronto_out == 1'b1);
 
            $display("Medida obtida: %0d cm", medida_out);
            $display("Fim do caso adicional %0d", caso);
 
            // 6) Espera entre os casos
            #(100_000); // 100 us
        end
 
        // Fim da simulacao
        $display("----------------------------------------");
        $display("Fim das simulacoes ADICIONAIS");
 
        caso = 99;
        $stop;
    end
 
endmodule