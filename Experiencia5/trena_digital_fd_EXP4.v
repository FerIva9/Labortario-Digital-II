/* -------------------------------------------------------------
 * Arquivo   : trena_digital_fd.v
 *--------------------------------------------------------------
 * Descricao : fluxo de dados do circuito base da trena digital 
 * 
 *--------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     19/09/2025  1.0     Fernando Ivanov   criacao
 *--------------------------------------------------------------
 */

 module trena_digital_fd (
    input wire clock,
    input wire reset,

    // Entradas externas
    input wire mensurar,
    input wire echo,

    // Sinais de controle vindos da UC
    input wire medir,
    input wire [1:0] sel_ascii,
    input wire partida,
    input wire reset_fd,


    // Saídas para a UC
    output wire pulso_mensurar,
    output wire pronto_sensor,
    output wire pronto_serial,

    // Saídas do sistema
    output wire trigger,
    output wire [11:0] medida,
    output wire saida_serial,

    // Depuração
    output wire [3:0] db_estado_sensor,
    output wire [3:0] db_estado_serial
 );
    // Sinais internos

    wire s_mensurar;
    wire [11:0] s_medida;
    wire [6:0] s_ascii_centena;
    wire [6:0] s_ascii_dezena;
    wire [6:0] s_ascii_unidade;
    wire [6:0] s_ascii_hash;
    wire [6:0] s_dados_ascii;
    wire s_reset_fd;

    // Tratamento do sinal mensurar.

    assign s_mensurar = ~mensurar;

    edge_detector ED_MENSURAR (
        .clock (clock),
        .reset (s_reset_fd),
        .sinal (s_mensurar),
        .pulso (pulso_mensurar)
    );


    interface_hcsr04 SENSOR (
        .clock     (clock),
        .reset     (s_reset_fd),
        .medir     (medir),
        .echo      (echo),
        .trigger   (trigger),
        .medida    (s_medida),
        .pronto    (pronto_sensor),
        .db_estado (db_estado_sensor)
    );

    mux_4x1_n #(
        .BITS(7)
    ) MUX_ASCII (
        .D3      (s_ascii_hash),
        .D2      (s_ascii_unidade),
        .D1      (s_ascii_dezena),
        .D0      (s_ascii_centena),
        .SEL     (sel_ascii),
        .MUX_OUT (s_dados_ascii)
    );

    tx_serial_7E1 TX (
        .clock          (clock),
        .reset          (s_reset_fd),
        .partida        (partida),
        .dados_ascii    (s_dados_ascii),
        .saida_serial   (saida_serial),
        .pronto         (pronto_serial),

        .db_clock       (),
        .db_tick        (),
        .db_partida     (),
        .db_saida_serial(),
        .db_estado      (db_estado_serial)
    );

    assign s_ascii_centena = {3'b011, s_medida[11:8]};
    assign s_ascii_dezena  = {3'b011, s_medida[7:4]};
    assign s_ascii_unidade = {3'b011, s_medida[3:0]};
    assign s_ascii_hash = 7'h23;
    assign medida = s_medida;
    assign s_reset_fd = reset | reset_fd;


 endmodule