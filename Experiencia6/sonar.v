module sonar (
    input wire clock,
    input wire reset,
    input wire ligar,
    input wire echo,
    input wire entrada_serial,
    input wire [1:0] sel_mux,

    output wire trigger,
    output wire pwm,
    output wire saida_serial,
    output wire fim_posicao,

    output wire [6:0] medida0,
    output wire [6:0] medida1,
    output wire [6:0] medida2,
    output wire [6:0] db_posicao,
    output wire [6:0] db_estado0,
    output wire [6:0] display5,
    output wire db_estado1,
    output wire db_estado2,
    output wire db_modo,

    // Pulsos para observacao no analisador logico/osciloscopio.
    output wire db_medir,
    output wire db_pronto_serial,
    output wire db_serial,
    output wire db_trigger,
    output wire db_echo
);
    wire [11:0] s_medida;
    wire [11:0] s_angulo;
    wire [5:0] s_db_estado_uc;
    wire s_db_modo;
    wire [2:0] s_db_posicao;
    wire [6:0] s_dados_ascii_tx;
    wire [3:0] s_db_estado_sensor;
    wire [3:0] s_db_estado_serial;
    wire [3:0] s_db_estado_rx;
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
    wire s_pronto_rx;
    wire [6:0] s_dados_ascii_rx;
    wire s_paridade_rx;
    wire s_paridade_par_rx;

    wire [3:0] s_hex0_group0;
    wire [3:0] s_hex1_group0;
    wire [3:0] s_hex2_group0;
    wire [3:0] s_hex3_group0;
    wire [3:0] s_hex4_group0;
    wire [3:0] s_hex5_group0;

    wire [3:0] s_hex0_group1;
    wire [3:0] s_hex1_group1;
    wire [3:0] s_hex2_group1;
    wire [3:0] s_hex3_group1;
    wire [3:0] s_hex4_group1;
    wire [3:0] s_hex5_group1;

    wire [3:0] s_hex0_group2;
    wire [3:0] s_hex1_group2;
    wire [3:0] s_hex2_group2;
    wire [3:0] s_hex3_group2;
    wire [3:0] s_hex4_group2;
    wire [3:0] s_hex5_group2;

    wire [3:0] s_hex0_group3;
    wire [3:0] s_hex1_group3;
    wire [3:0] s_hex2_group3;
    wire [3:0] s_hex3_group3;
    wire [3:0] s_hex4_group3;
    wire [3:0] s_hex5_group3;

    wire [23:0] s_sinais00;
    wire [23:0] s_sinais01;
    wire [23:0] s_sinais10;
    wire [23:0] s_sinais11;
    wire [23:0] s_sinais_sel;

    sonar_uc UC (
        .clock          (clock),
        .reset          (reset),
        .ligar          (ligar),
        .fim_medida     (s_fim_medida),
        .pronto_serial  (s_pronto_serial),
        .fim_2seg       (s_fim_2seg),
        .pronto_rx      (s_pronto_rx),
        .dados_ascii_rx (s_dados_ascii_rx),
        .paridade_par_rx(s_paridade_par_rx),
        .reset_fd       (s_reset_fd),
        .zera_posicao   (s_zera_posicao),
        .conta_posicao  (s_conta_posicao),
        .zera_timer     (s_zera_timer),
        .conta_timer    (s_conta_timer),
        .medir          (s_medir),
        .sel_ascii      (s_sel_ascii),
        .partida_serial (s_partida_serial),
        .fim_posicao    (fim_posicao),
        .db_modo        (s_db_modo),
        .db_estado      (s_db_estado_uc)
    );

    sonar_fd FD (
        .clock            (clock),
        .reset            (reset),
        .echo             (echo),
        .entrada_serial   (entrada_serial),
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
        .pronto_rx        (s_pronto_rx),
        .dados_ascii_rx   (s_dados_ascii_rx),
        .paridade_rx      (s_paridade_rx),
        .paridade_par_rx  (s_paridade_par_rx),
        .db_posicao       (s_db_posicao),
        .db_medida        (s_medida),
        .db_angulo        (s_angulo),
        .dados_ascii_tx   (s_dados_ascii_tx),
        .db_estado_sensor (s_db_estado_sensor),
        .db_estado_serial (s_db_estado_serial),
        .db_estado_rx     (s_db_estado_rx)
    );

    // Grupo 00: sensor + posicao.
    assign s_hex0_group0 = s_medida[3:0];
    assign s_hex1_group0 = s_medida[7:4];
    assign s_hex2_group0 = s_medida[11:8];
    assign s_hex3_group0 = {1'b0, s_db_posicao};
    assign s_hex4_group0 = s_db_estado_sensor;
    assign s_hex5_group0 = 4'h0;

    // Grupo 01: sinais de comunicacao serial.
    assign s_hex0_group1 = s_dados_ascii_rx[3:0];
    assign s_hex1_group1 = {1'b0, s_dados_ascii_rx[6:4]};
    assign s_hex2_group1 = s_db_estado_rx;
    assign s_hex3_group1 = s_dados_ascii_tx[3:0];
    assign s_hex4_group1 = {1'b0, s_dados_ascii_tx[6:4]};
    assign s_hex5_group1 = s_db_estado_serial;

    // Grupo 10: estados internos do sonar e modo de operacao.
    assign s_hex0_group2 = 4'h0;
    assign s_hex1_group2 = 4'h0;
    assign s_hex2_group2 = s_dados_ascii_tx[3:0];
    assign s_hex3_group2 = {1'b0, s_dados_ascii_tx[6:4]};
    assign s_hex4_group2 = s_db_estado_serial;
    assign s_hex5_group2 = 4'h0;

    // Grupo 11: replicacao do estado normal para facilitar a depuracao.
    assign s_hex0_group3 = s_angulo[3:0];
    assign s_hex1_group3 = s_angulo[7:4];
    assign s_hex2_group3 = s_angulo[11:8];
    assign s_hex3_group3 = s_db_modo ? 4'h1 : 4'h0;
    assign s_hex4_group3 = {1'b0, s_db_posicao};
    assign s_hex5_group3 = 4'h0;

    assign s_sinais00 = {
        s_hex5_group0, s_hex4_group0, s_hex3_group0,
        s_hex2_group0, s_hex1_group0, s_hex0_group0
    };
    assign s_sinais01 = {
        s_hex5_group1, s_hex4_group1, s_hex3_group1,
        s_hex2_group1, s_hex1_group1, s_hex0_group1
    };
    assign s_sinais10 = {
        s_hex5_group2, s_hex4_group2, s_hex3_group2,
        s_hex2_group2, s_hex1_group2, s_hex0_group2
    };
    assign s_sinais11 = {
        s_hex5_group3, s_hex4_group3, s_hex3_group3,
        s_hex2_group3, s_hex1_group3, s_hex0_group3
    };

    mux_4x1_n #(
        .BITS(24)
    ) MUX_DISPLAYS (
        .D3      (s_sinais11),
        .D2      (s_sinais10),
        .D1      (s_sinais01),
        .D0      (s_sinais00),
        .SEL     (sel_mux),
        .MUX_OUT (s_sinais_sel)
    );

    hexa7seg DISPLAY0 (.hexa(s_sinais_sel[3:0]),   .display(medida0));
    hexa7seg DISPLAY1 (.hexa(s_sinais_sel[7:4]),   .display(medida1));
    hexa7seg DISPLAY2 (.hexa(s_sinais_sel[11:8]),  .display(medida2));
    hexa7seg DISPLAY3 (.hexa(s_sinais_sel[15:12]), .display(db_posicao));
    hexa7seg DISPLAY4 (.hexa(s_sinais_sel[19:16]), .display(db_estado0));
    hexa7seg DISPLAY5 (.hexa(s_sinais_sel[23:20]), .display(display5));
    // Bits superiores do codigo de estado da UC.
    assign db_estado1 = s_db_estado_uc[4];
    assign db_estado2 = s_db_estado_uc[5];
    assign db_modo = s_db_modo;

    assign db_medir         = s_medir;
    assign db_pronto_serial = s_pronto_serial;
    assign db_serial  = saida_serial;
    assign db_trigger = trigger;
    assign db_echo    = echo;
endmodule
