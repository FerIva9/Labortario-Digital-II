`timescale 1ns/1ps

module tb_exp4_trena;

    reg clock;
    reg reset;
    reg mensurar;
    reg echo;
    wire trigger;
    wire saida_serial;
    wire [6:0] medida0;
    wire [6:0] medida1;
    wire [6:0] medida2;
    wire pronto;
    wire db_mensurar;
    wire db_echo;
    wire db_trigger;
    wire db_saida_serial;
    wire [6:0] db_estado;
    wire db_pulso_mensurar;
    wire db_pronto_sensor;
    wire db_pronto_serial;


    exp4_trena DUT (
        .clock (clock),
        .reset (reset),
        .mensurar (mensurar),
        .echo (echo),
        .trigger (trigger),
        .saida_serial (saida_serial),
        .medida0 (medida0),
        .medida1 (medida1),
        .medida2 (medida2),
        .pronto (pronto),
        .db_mensurar (db_mensurar),
        .db_echo (db_echo),
        .db_trigger (db_trigger),
        .db_saida_serial (db_saida_serial),
        .db_estado (db_estado),
        .db_pulso_mensurar (db_pulso_mensurar),
        .db_pronto_sensor (db_pronto_sensor),
        .db_pronto_serial (db_pronto_serial)
    );

    initial begin
        clock = 1'b0;
        forever #10 clock = ~clock;
    end

    integer caso;
    integer distancia_cm;
    integer echo_us;

    task executar_teste;

        input integer numero_caso;
        input integer distancia;
        input integer largura_echo;

        begin

            $display("");
            $display("============================================================");
            $display("INICIO DO CENARIO %0d", numero_caso);
            $display("Distancia esperada: %0d cm", distancia);
            $display("Largura do ECHO: %0d us", largura_echo);
            $display("============================================================");


            reset = 1'b1;
            mensurar = 1'b1;
            echo = 1'b0;

            #100;

            $display("[%0t ns] Reset ativado", $time);

            reset = 1'b0;

            #100;

            $display("[%0t ns] Pulso MENSURAR", $time);

            mensurar = 1'b0;

            #20;

            mensurar = 1'b1;

            @(posedge trigger);

            $display("[%0t ns] TRIGGER detectado", $time);

            #400_000;

            $display("[%0t ns] Passaram 400 us", $time);


            echo = 1'b1;

            $display("[%0t ns] ECHO = 1", $time);

            #(largura_echo * 1000);

            echo = 1'b0;

            $display("[%0t ns] ECHO = 0", $time);


            @(posedge pronto);

            $display("[%0t ns] PRONTO = 1 -> transmissao finalizada",
                     $time);


            $display("[%0t ns] db_pulso_mensurar = %b",
                     $time, db_pulso_mensurar);

            $display("[%0t ns] db_pronto_sensor = %b",
                     $time, db_pronto_sensor);

            $display("[%0t ns] db_pronto_serial = %b",
                     $time, db_pronto_serial);

            #100_000;

            $display("[%0t ns] Final do cenario %0d",
                     $time, numero_caso);

        end

    endtask

    initial begin

        // Valores iniciais

        reset = 1'b1;
        mensurar = 1'b1;
        echo = 1'b0;

        executar_teste(
            1,
            9,
            529
        );

        executar_teste(
            2,
            32,
            1882
        );

        executar_teste(
            3,
            115,
            6764
        );

        executar_teste(
            4,
            115,
            6788
        );

        executar_teste(
            5,
            116,
            6800
        );

        executar_teste(
            6,
            2,
            118
        );

        executar_teste(
            7,
            450,
            26469
        );

        $display("");
        $display("============================================================");
        $display("TODOS OS 7 CENARIOS FORAM EXECUTADOS");
        $display("FIM DA SIMULACAO");
        $display("============================================================");

        $stop;

    end



    initial begin

        $monitor(
            "[%0t ns] reset=%b mensurar=%b echo=%b trigger=%b pronto=%b serial=%b",
            $time,
            reset,
            mensurar,
            echo,
            trigger,
            pronto,
            saida_serial
        );

    end

endmodule