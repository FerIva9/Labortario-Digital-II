/* -------------------------------------------------------------
 * Arquivo   : tx_serial_7E1.v
 *--------------------------------------------------------------
 * Descricao : circuito base de transmissao serial assincrona 
 *             ==> comunicacao serial de 7 bits de dados, 
 *                 com partidade par, 1 stop bit e 115.200 bauds
 * 
 * entradas : partida, dados_ascii
 * saidas   : saida_serial, pronto
 * depuracao: db_clock, db_tick, db_partida, db_saida_serial
 *            e db_estado
 *
 *--------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     05/09/2026  1.0     Fernando Ivanov   criacao
 *     19/09/2026  1.1     Fernando Ivanov   adaptação p/ exp 4
 *--------------------------------------------------------------
 */

module tx_serial_7E1 (
    input  wire       clock,
    input  wire       reset,
    input  wire       partida,
    input  wire [6:0] dados_ascii,

    output wire       saida_serial,
    output wire       pronto,
    output wire       db_clock,
    output wire       db_tick,
    output wire       db_partida,
    output wire       db_saida_serial,
    output wire [3:0] db_estado
);

    wire s_zera;
    wire s_conta;
    wire s_carrega;
    wire s_desloca;
    wire s_tick;
    wire s_fim;
    wire s_saida_serial;

    /*
     * Fluxo de dados
     */
    tx_serial_7E1_fd U1_FD (
        .clock        (clock),
        .reset        (reset),
        .zera         (s_zera),
        .conta        (s_conta),
        .carrega      (s_carrega),
        .desloca      (s_desloca),
        .dados_ascii  (dados_ascii),
        .saida_serial (s_saida_serial),
        .fim          (s_fim)
    );

    /*
     * Unidade de controle
     *
     * partida já é um pulso de 1 ciclo,
     * gerado pela UC da Trena.
     */
    tx_serial_uc U2_UC (
        .clock     (clock),
        .reset     (reset),
        .partida   (partida),
        .tick      (s_tick),
        .fim       (s_fim),
        .zera      (s_zera),
        .conta     (s_conta),
        .carrega   (s_carrega),
        .desloca   (s_desloca),
        .pronto    (pronto),
        .db_estado (db_estado)
    );

    /*
     * Gerador de tick para 115200 bauds
     * 50 MHz / 115200 ≈ 434
     */
    contador_m #(
        .M(434),
        .N(9)
    ) U3_TICK (
        .clock   (clock),
        .zera_as (1'b0),
        .zera_s  (s_zera),
        .conta   (1'b1),
        .Q       (),
        .fim     (s_tick),
        .meio    ()
    );

    assign saida_serial = s_saida_serial;

    /*
     * Depuração
     */
    assign db_clock        = clock;
    assign db_tick         = s_tick;
    assign db_partida      = partida;
    assign db_saida_serial = s_saida_serial;


endmodule 