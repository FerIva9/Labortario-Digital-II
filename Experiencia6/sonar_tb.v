// Dois casos para inspecao no ModelSim:
// 1: 20 graus, 100 cm -> "020,100#".
// 2: 40 graus,  50 cm -> "040,050#".
`timescale 1ns/1ns

module sonar_tb;
    reg clock;
    reg reset;
    reg ligar;
    reg echo;
    integer caso;

    wire trigger;
    wire pwm;
    wire saida_serial;
    wire fim_posicao;
    wire [6:0] medida0, medida1, medida2;
    wire [6:0] db_posicao, db_estado0;
    wire db_estado1;
    wire db_medir, db_pronto_serial;
    wire db_serial, db_trigger, db_echo;

    sonar dut (
        .clock(clock),
        .reset(reset),
        .ligar(ligar),
        .echo(echo),
        .trigger(trigger),
        .pwm(pwm),
        .saida_serial(saida_serial),
        .fim_posicao(fim_posicao),
        .medida0(medida0),
        .medida1(medida1),
        .medida2(medida2),
        .db_posicao(db_posicao),
        .db_estado0(db_estado0),
        .db_estado1(db_estado1),
        .db_medir(db_medir),
        .db_pronto_serial(db_pronto_serial),
        .db_serial(db_serial),
        .db_trigger(db_trigger),
        .db_echo(db_echo)
    );

    // SOMENTE NA SIMULACAO: espera de 20 ms em vez de 2 segundos.
    // Remova esta linha para simular o intervalo real do projeto.
    defparam dut.FD.TIMER_2SEG.M = 1_000_000;

    // Clock de 50 MHz.
    always #10 clock = ~clock;

    initial begin
        clock = 0;
        reset = 0;
        ligar = 0;
        echo = 0;
        caso = 0;

        // Reset inicial e acionamento do sonar.
        @(negedge clock);
        reset = 1;
        #100;
        reset = 0;
        #100;
        ligar = 1;

        // Caso 1: posicao 000 (20 graus), distancia de 100 cm.
        caso = 1;
        // Simula o sensor respondendo depois do pulso de trigger.
        @(posedge trigger);
        @(negedge trigger);
        #400000; // espera 400 us
        echo = 1;
        #5882000; // echo de 5882 us corresponde a 100 cm
        echo = 0;

        // Aguarda a mensagem completa e o avanco da posicao.
        @(posedge fim_posicao);
        #10000; // permite observar o pulso de fim e a nova posicao

        // Caso 2: o sonar avancou sozinho para 001 (40 graus).
        // Mantem ligar=1 e nao aplica reset entre as medicoes.
        caso = 2;
        @(posedge trigger);
        @(negedge trigger);
        #400000; // espera 400 us
        echo = 1;
        #2941000; // echo de 2941 us corresponde a 50 cm
        echo = 0;

        // Aguarda "040,050#" e o avanco para a posicao 010.
        @(posedge fim_posicao);
        #10000;

        // Encerra apos as duas medicoes.
        @(negedge clock);
        ligar = 0;
        #100;
        $stop;
    end
endmodule
