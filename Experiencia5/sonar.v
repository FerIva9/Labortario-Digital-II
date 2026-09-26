/*
 * sonar.v - integracao da unidade de controle e do fluxo de dados.
 * Entradas reset e ligar ativas em 1, conectadas diretamente a UC.
 * Displays de sete segmentos ativos em zero (hexa7seg):
 *   medida2 medida1 medida0: distancia em cm, em tres digitos BCD;
 *   db_posicao: indice da posicao atual, de 0 a 7;
 *   db_estado1 db_estado0: estado da UC em hexadecimal, de 00 a 16.
 */
module sonar (
    input wire clock,
    input wire reset,
    input wire ligar,
    input wire echo,

    output wire trigger,
    output wire pwm,
    output wire saida_serial,
    output wire fim_posicao,

    output wire [6:0] medida0,
    output wire [6:0] medida1,
    output wire [6:0] medida2,
    output wire [6:0] db_posicao,
    output wire [6:0] db_estado0,
    output wire [6:0] db_estado1,

    // Pulsos para observacao no analisador logico/osciloscopio.
    output wire db_medir,
    output wire db_pronto_serial,
    output wire db_serial,
    output wire db_trigger,
    output wire db_echo
);
    wire [11:0] s_medida;
    wire [4:0] s_db_estado_uc;
    wire [2:0] s_db_posicao;
    wire s_reset_fd;
    wire s_zera_posicao;
    wire s_conta_posicao;
    wire s_zera_timer;
    wire s_conta_timer;
    wire s_medir;
    wire [2:0] s_sel_ascii;
    wire s_partida_serial;
    wire s_fim_medida;
    wire s_pronto_serial;
    wire s_fim_2seg;

    sonar_uc UC (
        .clock          (clock),
        .reset          (reset),
        .ligar          (ligar),
        .fim_medida     (s_fim_medida),
        .pronto_serial  (s_pronto_serial),
        .fim_2seg       (s_fim_2seg),
        .reset_fd       (s_reset_fd),
        .zera_posicao   (s_zera_posicao),
        .conta_posicao  (s_conta_posicao),
        .zera_timer     (s_zera_timer),
        .conta_timer    (s_conta_timer),
        .medir          (s_medir),
        .sel_ascii      (s_sel_ascii),
        .partida_serial (s_partida_serial),
        .fim_posicao    (fim_posicao),
        .db_estado      (s_db_estado_uc)
    );

    sonar_fd FD (
        .clock            (clock),
        .reset            (reset),
        .echo             (echo),
        .reset_fd         (s_reset_fd),
        .zera_posicao     (s_zera_posicao),
        .conta_posicao    (s_conta_posicao),
        .zera_timer       (s_zera_timer),
        .conta_timer      (s_conta_timer),
        .medir            (s_medir),
        .sel_ascii        (s_sel_ascii),
        .partida_serial   (s_partida_serial),
        .trigger          (trigger),
        .pwm              (pwm),
        .saida_serial     (saida_serial),
        .fim_medida       (s_fim_medida),
        .pronto_serial    (s_pronto_serial),
        .fim_2seg          (s_fim_2seg),
        .db_posicao       (s_db_posicao),
        .db_medida        (s_medida),
        .db_estado_sensor (),
        .db_estado_serial ()
    );

    hexa7seg DISPLAY0 (.hexa(s_medida[3:0]),  .display(medida0));
    hexa7seg DISPLAY1 (.hexa(s_medida[7:4]),  .display(medida1));
    hexa7seg DISPLAY2 (.hexa(s_medida[11:8]), .display(medida2));
    hexa7seg DISPLAY3 (.hexa({1'b0, s_db_posicao}), .display(db_posicao));
    hexa7seg DISPLAY4 (.hexa(s_db_estado_uc[3:0]), .display(db_estado0));
    hexa7seg DISPLAY5 (.hexa({3'b000, s_db_estado_uc[4]}), .display(db_estado1));

    assign db_medir         = s_medir;
    assign db_pronto_serial = s_pronto_serial;
    assign db_serial  = saida_serial;
    assign db_trigger = trigger;
    assign db_echo    = echo;
endmodule
