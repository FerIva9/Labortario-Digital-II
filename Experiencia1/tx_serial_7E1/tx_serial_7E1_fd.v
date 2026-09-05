/* -------------------------------------------------------------
 * Arquivo   : tx_serial_7E1_fd.v
 *--------------------------------------------------------------
 * Descricao : fluxo de dados do circuito base de transmissao 
 *             serial assincrona (7E1) 
 *             ==> contem deslocador com 12 bits e contador
 *                 modulo 12
 * 
 *--------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     30/08/2025  1.0     Edson Midorikawa  criacao
 *     05/-9/20206 2.0     Fernando Ivanov   adaptação para 7E1
 *--------------------------------------------------------------
 */
 
 module tx_serial_7E1_fd (
    input        clock        ,
    input        reset        ,
    input        zera         ,
    input        conta        ,
    input        carrega      ,
    input        desloca      ,
    input  [6:0] dados_ascii  ,
    output       saida_serial ,
    output       fim
);

    wire [10:0] s_dados;
    wire [10:0] s_saida;
    wire        paridade;

    // calculo da paridade
    assign paridade = ^dados_ascii[6:0]; // paridade par

    // composicao dos dados seriais
    assign s_dados[0]   = 1'b1;             // repouso
    assign s_dados[1]   = 1'b0;             // start bit
    assign s_dados[8:2] = dados_ascii[6:0]; // dado
    assign s_dados[9]   = paridade;         // bit de paridade
    assign s_dados[10]  = 1'b1;             // stop bit (único)
  
    // Instanciação do deslocador_n
    deslocador_n #(
        .N(11) 
    ) U1 (
        .clock         (clock  ),
        .reset         (reset  ),
        .carrega       (carrega),
        .desloca       (desloca),
        .entrada_serial(1'b1   ), 
        .dados         (s_dados),
        .saida         (s_saida)
    );
    
    // Instanciação do contador_m
    // são necessários 11 deslocamentos para transmitir 1 start bit, 7 bits de dados, 1 bit de paridade e 2 stop bits
    contador_m #(
        .M(12),
        .N(4)
    ) U2 (
        .clock   (clock),
        .zera_as (1'b0 ),
        .zera_s  (zera ),
        .conta   (conta),
        .Q       (     ), // porta Q em aberto (desconectada)
        .fim     (fim  ),
        .meio    (     )  // porta meio em aberto (desconectada)
    );
    
    // Saida serial do transmissor
    assign saida_serial = s_saida[0];
  
endmodule
