/*
 * sonar_tb_comandos.v
 *
 * Cenario: verifica caracteres invalidos e comandos repetidos.
 * Em localizacao, mede em 20 graus, recebe 'x' (ignorado) e 'v' (mantem
 * o modo), e mede em 40 graus. Recebe 'a' e mede em atencao a 60 graus.
 * Recebe outro 'a' e 'A' (maiusculo, ignorado), mantendo a atencao para
 * outra medida em 60 graus. Recebe 'v' e mede em localizacao a 60 graus.
 * Sao 5 ciclos completos. Ao final, desliga o circuito.
 */

`timescale 1ns/1ns

module sonar_tb_invalidos;
    reg clock = 0;
    reg reset = 0;
    reg ligar = 0;
    reg echo = 0;
    reg entrada_serial = 1; // UART em repouso = 1.
    wire trigger, pwm, saida_serial, fim_posicao, modo;

    // Sinais numericos para facilitar a leitura das formas de onda.
    wire [2:0] posicao = dut.FD.s_posicao;
    wire [11:0] distancia_bcd = dut.s_medida;
    wire [5:0] estado = dut.s_db_estado_uc;
    integer ciclo = 0;
    localparam integer BIT_NS = 8680; // 115200 baud, 7E1.

    sonar dut (
        .clock(clock), .reset(reset), .ligar(ligar), .echo(echo),
        .entrada_serial(entrada_serial), .sel_mux(2'b00),
        .trigger(trigger), .pwm(pwm), .saida_serial(saida_serial),
        .fim_posicao(fim_posicao), .db_modo(modo)
    );
    always #10 clock = ~clock; // 50 MHz: periodo de 20 ns.

    // Acelera SOMENTE a espera entre medidas: 2 s -> 400 us.
    // Para tempo real, comente esta linha e aumente o timeout ao final.
    defparam dut.FD.TIMER_2SEG.M = 20_000;

    initial begin
        // ==========================================================
        // EDITE AQUI: roteiro do cenario caracteres invalidos e comandos repetidos
        // medir(distancia_em_cm, angulo_esperado, modo_esperado);
        // modo: 0 = localizacao, 1 = atencao.
        // Cada medir espera trigger, fornece echo e confere envio UART.
        // ==========================================================
        reiniciar;
        ligar = 1;
        medir(100, 20, 0);
        enviar("x"); // Ignorado.
        conferir_modo(0);
        enviar("v"); // Ja esta em localizacao.
        conferir_modo(0);
        medir( 90, 40, 0);
        enviar("a");
        conferir_modo(1);
        medir( 80, 60, 1);
        enviar("a"); // Ja esta em atencao: nao deve alternar o modo.
        conferir_modo(1);
        enviar("A"); // Maiuscula nao e o comando 'a'.
        conferir_modo(1);
        medir( 70, 60, 1);
        enviar("v");
        conferir_modo(0);
        medir( 60, 60, 0);
        terminar;
    end

    // ==============================================================
    // APOIO: normalmente nao precisa editar nada daqui para baixo.
    // Cada arquivo e independente: nao precisa copiar outros TBs.
    // ==============================================================
    task reiniciar;
        begin
            @(negedge clock);
            ligar = 0;
            echo = 0;
            entrada_serial = 1;
            reset = 1;
            repeat (5) @(negedge clock);
            reset = 0;
            repeat (5) @(negedge clock);
            if (modo !== 0 || posicao !== 0)
                $fatal(1, "Reset nao restaurou localizacao/20 graus");
        end
    endtask

    // Envia um caractere: start, 7 bits (LSB primeiro), paridade PAR, stop.
    task enviar;
        input [6:0] caractere;
        integer bit_n;
        begin
            @(negedge clock);
            entrada_serial = 0;
            #(BIT_NS);
            for (bit_n = 0; bit_n < 7; bit_n = bit_n + 1) begin
                entrada_serial = caractere[bit_n];
                #(BIT_NS);
            end
            entrada_serial = ^caractere;
            #(BIT_NS);
            entrada_serial = 1;
            #(BIT_NS);
            $display("Comando enviado: %c", caractere);
        end
    endtask

    task conferir_modo;
        input esperado;
        begin
            @(negedge clock);
            if (modo !== esperado)
                $fatal(1, "Modo recebido=%b; esperado=%b", modo, esperado);
        end
    endtask

    // Le os 8 caracteres do pacote AAA,DDD# diretamente do fio TX.
    // Tambem confere a paridade e o stop bit de cada caractere.
    task receber_pacote;
        output [63:0] pacote;
        reg [6:0] caractere;
        integer letra, bit_n;
        begin
            pacote = 0;
            for (letra = 0; letra < 8; letra = letra + 1) begin
                @(negedge saida_serial); // Inicio do start bit.
                #(BIT_NS / 2);
                if (saida_serial !== 0) $fatal(1, "Start UART invalido");
                for (bit_n = 0; bit_n < 7; bit_n = bit_n + 1) begin
                    #(BIT_NS);
                    caractere[bit_n] = saida_serial;
                end
                #(BIT_NS);
                if (saida_serial !== (^caractere))
                    $fatal(1, "Paridade TX incorreta");
                #(BIT_NS);
                if (saida_serial !== 1) $fatal(1, "Stop UART invalido");
                pacote = {pacote[55:0], 1'b0, caractere};
            end
        end
    endtask

    task medir;
        input integer cm;
        input integer graus;
        input modo_esperado;
        reg [63:0] recebido, esperado;
        reg [2:0] proxima_posicao;
        begin
            // Posicoes: 0=20, 1=40, 2=60, ... 7=160 graus.
            @(posedge trigger);
            ciclo = ciclo + 1;
            if (posicao !== ((graus - 20) / 20) || modo !== modo_esperado)
                $fatal(1, "Ciclo %0d: posicao=%0d modo=%b; esperado %0d graus modo=%b",
                       ciclo, posicao, modo, graus, modo_esperado);
            proxima_posicao = modo_esperado ? posicao : posicao + 3'd1;
            // Monta o texto esperado, incluindo zeros a esquerda.
            esperado[63:56] = 48 + graus / 100;
            esperado[55:48] = 48 + (graus / 10) % 10;
            esperado[47:40] = 48 + graus % 10;
            esperado[39:32] = ",";
            esperado[31:24] = 48 + cm / 100;
            esperado[23:16] = 48 + (cm / 10) % 10;
            esperado[15:8]  = 48 + cm % 10;
            esperado[7:0]   = "#";
            fork
                begin
                    @(negedge trigger);
                    #100_000; // Sensor responde 100 us depois do trigger.
                    echo = 1;
                    #(cm * 58_820); // 2941 clocks/cm x 20 ns, conforme o FD.
                    echo = 0;
                end
                receber_pacote(recebido);
            join
            // fim_posicao sinaliza medida E transmissao concluidas.
            wait (fim_posicao === 1'b1);
            @(negedge clock);
            if (recebido !== esperado)
                $fatal(1, "Pacote recebido='%s'; esperado='%s'", recebido, esperado);
            if (posicao !== proxima_posicao)
                $fatal(1, "Avanco de posicao incorreto no ciclo %0d", ciclo);
            $display("OK ciclo %0d: modo=%b, TX=%s", ciclo, modo_esperado, recebido);
        end
    endtask

    // Usar entre medidas, depois que medir retornar.
    task desligar_e_conferir;
        begin
            @(negedge clock);
            ligar = 0;
            repeat (30_000) begin // 600 us, maior que o timer acelerado.
                @(negedge clock);
                if (trigger !== 0 || dut.s_medir !== 0)
                    $fatal(1, "Nova medida com ligar=0");
            end
        end
    endtask

    task terminar;
        begin
            desligar_e_conferir;
            $display("PASSOU: sonar_tb_comandos (%0d ciclos completos)", ciclo);
            $finish;
        end
    endtask

    initial begin
        #200_000_000; // 200 ms. Com timer real, use #60_000_000_000 (60 s).
        $fatal(1, "Timeout: ciclo=%0d estado=%0d. Verifique trigger/echo/UART.", ciclo, estado);
    end
endmodule
