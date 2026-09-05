/* -------------------------------------------------------------
 * Arquivo   : tx_serial_7N2_fd_corrigido.v
 * Descricao : fluxo de dados do circuito base de transmissao
 *             serial assincrona (7N2)
 *             deslocador com 11 bits e contador modulo 12
 * -------------------------------------------------------------
 */

module tx_serial_7N2_fd (
    input        clock,
    input        reset,
    input        zera,
    input        conta,
    input        carrega,
    input        desloca,
    input  [6:0] dados_ascii,
    output       saida_serial,
    output       fim
);

    wire [10:0] s_dados;
    wire [10:0] s_saida;
    wire [3:0]  s_contador;

    // Composicao dos dados seriais: repouso + start + 7 dados + 2 stop
    assign s_dados[0]   = 1'b1;             // repouso
    assign s_dados[1]   = 1'b0;             // start bit
    assign s_dados[8:2] = dados_ascii[6:0]; // dado
    assign s_dados[9]   = 1'b1;             // stop bit 1
    assign s_dados[10]  = 1'b1;             // stop bit 2

    // Deslocador
    deslocador_n #(.N(11)) U1 (
        .clock          (clock),
        .reset          (reset),
        .carrega        (carrega),
        .desloca        (desloca),
        .entrada_serial (1'b1),
        .dados          (s_dados),
        .saida          (s_saida)
    );

    // Contador modulo 12
    // O reset geral tambem inicializa o contador em zero.
    contador_m #(.M(12), .N(4)) U2 (
        .clock   (clock),
        .zera_as (reset),
        .zera_s  (zera),
        .conta   (conta),
        .Q       (s_contador),
        .fim     (fim),
        .meio    ()
    );

    // Saida serial: LSB primeiro
    assign saida_serial = s_saida[0];

endmodule
