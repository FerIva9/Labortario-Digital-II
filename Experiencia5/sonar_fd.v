module sonar_fd (
    // Entradas externas.
    input wire        clock,
    input wire        reset,
    input wire        echo,

    // Comandos vindos da unidade de controle.
    input wire        reset_fd,
    input wire        zera_posicao,
    input wire        conta_posicao,
    input wire        zera_timer,
    input wire        conta_timer,
    input wire        medir,
    input wire [2:0]  sel_ascii,
    input wire        partida_serial,

    // Saidas externas.
    output wire       trigger,
    output wire       pwm,
    output wire       saida_serial,

    // Indicacoes para a unidade de controle.
    output wire       fim_medida,
    output wire       pronto_serial,
    output wire       fim_2seg,

    // Depuracao em valores binarios/BCD
    output wire [2:0]  db_posicao,
    output wire [11:0] db_medida,
    output wire [3:0]  db_estado_sensor,
    output wire [3:0]  db_estado_serial
);
    wire        s_reset_fd;
    wire [2:0]  s_posicao;
    wire [23:0] s_angulo_ascii;
    wire [11:0] s_medida;
    wire [6:0]  s_dados_ascii;

    assign s_reset_fd = reset | reset_fd;

    // Posicoes 000 a 111, retornando automaticamente a 000.
    contador_m #(
        .M(8),
        .N(3)
    ) CONTADOR_POSICAO (
        .clock   (clock),
        .zera_as (s_reset_fd),
        .zera_s  (zera_posicao),
        .conta   (conta_posicao),
        .Q       (s_posicao),
        .fim     (),
        .meio    ()
    );

    controle_servo_8 SERVO (
        .clock       (clock),
        .reset       (s_reset_fd),
        .posicao     (s_posicao),
        .controle    (pwm),
        .db_reset    (),
        .db_posicao  (),
        .db_controle ()
    );

    rom_angulos_8x24 ROM_ANGULOS (
        .endereco (s_posicao),
        .saida    (s_angulo_ascii)
    );

    interface_hcsr04 SENSOR (
        .clock     (clock),
        .reset     (s_reset_fd),
        .medir     (medir),
        .echo      (echo),
        .trigger   (trigger),
        .medida    (s_medida),
        .pronto    (fim_medida),
        .db_reset  (),
        .db_medir  (),
        .db_estado (db_estado_sensor)
    );

    // Angulo: usa os sete bits inferiores de cada byte da ROM.
    // Distancia: converte cada digito BCD em seu caractere ASCII.
    mux_8x1_n #(
        .BITS(7)
    ) MUX_ASCII (
        .D0      (s_angulo_ascii[22:16]),
        .D1      (s_angulo_ascii[14:8]),
        .D2      (s_angulo_ascii[6:0]),
        .D3      (7'h2C),
        .D4      ({3'b011, s_medida[11:8]}),
        .D5      ({3'b011, s_medida[7:4]}),
        .D6      ({3'b011, s_medida[3:0]}),
        .D7      (7'h23),
        .SEL     (sel_ascii),
        .MUX_OUT (s_dados_ascii)
    );

    // pronto_serial indica o fim de UM caractere, nao da mensagem.
    tx_serial_7E1 TX_SERIAL (
        .clock           (clock),
        .reset           (s_reset_fd),
        .partida         (partida_serial),
        .dados_ascii     (s_dados_ascii),
        .saida_serial    (saida_serial),
        .pronto          (pronto_serial),
        .db_partida      (),
        .db_saida_serial (),
        .db_estado       (db_estado_serial)
    );

    // 100.000.000 ciclos de 20 ns correspondem a 2 segundos.
    contador_m #(
        .M(100_000_000),
        .N(27)
    ) TIMER_2SEG (
        .clock   (clock),
        .zera_as (s_reset_fd),
        .zera_s  (zera_timer),
        .conta   (conta_timer),
        .Q       (),
        .fim     (fim_2seg),
        .meio    ()
    );

    assign db_posicao = s_posicao;
    assign db_medida  = s_medida;
endmodule
