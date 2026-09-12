/* --------------------------------------------------------------------------
 *  Arquivo   : interface_hcsr04_fd-PARCIAL.v
 * --------------------------------------------------------------------------
 *  Descricao : CODIGO PARCIAL DO fluxo de dados do circuito de interface  
 *              com sensor ultrassonico de distancia
 *              
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 * --------------------------------------------------------------------------
 */
 
module interface_hcsr04_fd (
    input wire         clock,
    input wire         pulso,
    input wire         zera,
    input wire         gera,
    input wire         registra,
    output wire        fim_medida,
    output wire        trigger,
    output wire        fim,
    output wire [11:0] distancia
);

    // Sinais internos
    wire [11:0] s_medida;

    // (U1) pulso de 10us (??? clocks)
    gerador_pulso #(
        .largura(/* completar */) 
    ) U1 (
        .clock (clock  ),
        .reset (/* completar */),
        .gera  (/* completar */),
        .para  (/* completar */), 
        .pulso (/* completar */),
        .pronto(/* completar */)
    );

    // (U2) medida em cm (R=2941 clocks)
    contador_cm #(
        .R(2941), 
        .N(12)
    ) U2 (
        .clock  (clock         ),
        .reset  (/* completar */),
        .pulso  (/* completar */),
        .digito2(s_medida[11:8]),
        .digito1(s_medida[7:4] ),
        .digito0(s_medida[3:0] ),
        .fim    (/* completar */),
        .pronto (/* completar */)
    );

    // (U3) registrador
    registrador_n #(
        .N(12)
    ) U3 (
        .clock  (clock    ),
        .clear  (/* completar */),
        .enable (/* completar */),
        .D      (s_medida ),
        .Q      (/* completar */)
    );

endmodule
