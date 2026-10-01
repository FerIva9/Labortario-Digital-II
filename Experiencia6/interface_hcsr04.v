/* --------------------------------------------------------------------------
 *  Arquivo   : interface_hcsr04.v
 * --------------------------------------------------------------------------
 *  Descricao : circuito de interface com sensor ultrassonico de distancia
 *              
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 *      25/09/2024  1.1     Fernando Ivanov   adição de saídas de depuração
 * --------------------------------------------------------------------------
 */
 
module interface_hcsr04 (
    input wire         clock,
    input wire         reset,
    input wire         medir,
    input wire         echo,
    output wire        trigger,
    output wire [11:0] medida,
    output wire        pronto,
    output wire        db_reset,
    output wire        db_medir,
    output wire [3:0]  db_estado
);

    // Sinais internos
    wire        s_zera;
    wire        s_gera;
    wire        s_registra;
    wire        s_fim_medida;
    wire        s_zera_timeout;
    wire        s_conta_timeout;
    wire        s_timeout;
    wire [11:0] s_medida;

    // Unidade de controle
    interface_hcsr04_uc U1 (
        .clock     (clock       ),
        .reset     (reset       ),
        .medir     (medir       ),
        .echo      (echo        ),
        .fim_medida(s_fim_medida),
        .zera_timeout (s_zera_timeout ),
        .conta_timeout(s_conta_timeout),
        .timeout      (s_timeout      ),
        .zera      (s_zera      ),
        .gera      (s_gera      ),
        .registra  (s_registra  ),
        .pronto    (pronto      ),
        .db_estado (db_estado   )
    );

    // Fluxo de dados
    interface_hcsr04_fd U2 (
        .clock     (clock       ),
        .pulso     (echo        ), 
        .zera      (s_zera      ),
        .gera      (s_gera      ),
        .registra  (s_registra  ),
        .fim_medida(s_fim_medida),
        .zera_timeout (s_zera_timeout ),
        .conta_timeout(s_conta_timeout),
        .timeout      (s_timeout      ),
        .trigger   (trigger     ),
        .fim       (            ),  // (desconectado)
        .distancia (s_medida    )
    );

    // Saída
    assign medida = s_medida; 
    assign db_reset = reset;
    assign db_medir = medir;

endmodule
