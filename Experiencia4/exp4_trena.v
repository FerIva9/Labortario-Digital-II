/* -------------------------------------------------------------
 * Arquivo   : exp4_trena.v
 *--------------------------------------------------------------
 * Descricao : circuito digital da trena digital 
 * 
 *--------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     19/09/2025  1.0     Fernando Ivanov   criacao
 *--------------------------------------------------------------
 */


module exp4_trena (
    input  clock,
    input  reset,
    input  mensurar,
    input  echo,
    output trigger,
    output saida_serial,
    output [6:0] medida0,
    output [6:0] medida1,
    output [6:0] medida2,
    output pronto,
    output db_mensurar,
    output db_echo,
    output db_trigger,
    output db_saida_serial,
    output [6:0] db_estado,
    output db_pulso_mensurar,
    output db_pronto_sensor,
    output db_pronto_serial
);

    wire [11:0] s_medida;
    wire s_pulso_mensurar;
    wire s_pronto_sensor;
    wire s_pronto_serial;
    wire s_medir;
    wire [1:0] s_sel_ascii;
    wire s_partida;
    wire s_reset_fd;
    wire [3:0] s_db_estado_sensor;
    wire [3:0] s_db_estado_serial;
    wire [3:0] s_db_estado_uc;

    trena_digital_uc UC (
        .clock          (clock),
        .reset          (reset),
        .pulso_mensurar (s_pulso_mensurar),
        .pronto_sensor  (s_pronto_sensor),
        .pronto_serial  (s_pronto_serial),
        .reset_fd       (s_reset_fd),
        .medir          (s_medir),
        .sel_ascii      (s_sel_ascii),
        .partida        (s_partida),
        .pronto         (pronto),
        .db_estado      (s_db_estado_uc)
    );

    trena_digital_fd FD (
        .clock            (clock),
        .reset            (reset),
        .mensurar         (mensurar),
        .echo             (echo),
        .medir            (s_medir),
        .sel_ascii        (s_sel_ascii),
        .partida          (s_partida),
        .reset_fd         (s_reset_fd),
        .pulso_mensurar   (s_pulso_mensurar),
        .pronto_sensor    (s_pronto_sensor),
        .pronto_serial    (s_pronto_serial),
        .trigger          (trigger),
        .medida           (s_medida),
        .saida_serial     (saida_serial),
        .db_estado_sensor (s_db_estado_sensor),
        .db_estado_serial (s_db_estado_serial)
    );


    hexa7seg HEX0 (
        .hexa    (s_medida[3:0]),
        .display (medida0)
    );

    hexa7seg HEX1 (
        .hexa    (s_medida[7:4]),
        .display (medida1)
    );

    hexa7seg HEX2 (
        .hexa    (s_medida[11:8]),
        .display (medida2)
    );

    hexa7seg HEX5 (
        .hexa    (s_db_estado_uc),
        .display (db_estado)
    );

    assign db_mensurar = ~mensurar;
    assign db_echo = echo;
    assign db_trigger = trigger;
    assign db_saida_serial = saida_serial;
    assign db_pulso_mensurar = s_pulso_mensurar;
    assign db_pronto_sensor = s_pronto_sensor;
    assign db_pronto_serial = s_pronto_serial;

endmodule