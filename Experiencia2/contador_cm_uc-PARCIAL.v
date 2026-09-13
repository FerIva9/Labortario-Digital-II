/* -------------------------------------------------------------------------- 
 *  Arquivo   : contador_cm_uc-PARCIAL.v 
 * -------------------------------------------------------------------------- 
 *  Descricao : unidade de controle do componente contador_cm 
 * 
 *              incrementa contagem de cm a cada sinal de tick enquanto 
 *              o pulso de entrada permanece ativo 
 * 
 * -------------------------------------------------------------------------- 
 *  Revisoes  : 
 *      Data        Versao  Autor             Descricao 
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog 
 *      13/09/2026  1.1     Guilherme Muller  versao preenchida 
 * -------------------------------------------------------------------------- 
 */ 
 
module contador_cm_uc ( 
    input wire clock, 
    input wire reset, 
    input wire pulso, 
    input wire tick, 
    input wire meio, 
    output reg zera_tick, 
    output reg conta_tick, 
    output reg zera_bcd, 
    output reg conta_bcd, 
    output reg pronto 
); 
 
    reg [2:0] Eatual, Eprox; 
 
    parameter inicial       = 3'b000; 
    parameter preparacao    = 3'b001; 
    parameter espera        = 3'b010; 
    parameter conta         = 3'b011; 
    parameter arredonda     = 3'b100; 
    parameter final_estado  = 3'b101; 
 
    // Registrador de estado 
    always @(posedge clock or posedge reset) begin 
        if (reset) 
            Eatual <= inicial; 
        else 
            Eatual <= Eprox; 
    end 
 
    // Logica de proximo estado 
    always @(*) begin 
        case (Eatual) 
 
            inicial: 
                Eprox = pulso ? preparacao : inicial; 
 
            preparacao: 
                Eprox = espera; 
 
            espera: 
                Eprox = (pulso && tick) ? conta : 
                        (pulso ? espera : arredonda); 
 
            conta: 
                Eprox = (pulso && tick) ? conta : 
                        (pulso ? espera : arredonda); 
 
            arredonda: 
                Eprox = final_estado; 
 
            final_estado: 
                Eprox = inicial; 
 
            default: 
                Eprox = inicial; 
 
        endcase 
    end 
 
    // Saidas de controle 
    always @(*) begin 
 
        // Valores padrao 
        zera_bcd   = 1'b0; 
        zera_tick  = 1'b0; 
        conta_bcd  = 1'b0; 
        conta_tick = 1'b0; 
        pronto     = 1'b0; 
 
        case (Eatual) 
 
            preparacao: begin 
                zera_bcd  = 1'b1; 
                zera_tick = 1'b1; 
            end 
 
            espera: begin 
                conta_tick = pulso; 
            end 
 
            conta: begin 
                conta_tick = pulso; 
                conta_bcd  = 1'b1;
            end 
 
            arredonda: begin 
                /*
                 * Se o resto da contagem corresponde a pelo menos
                 * metade de um centimetro, incrementa o valor inteiro.
                 */
                conta_bcd = meio;
            end 
 
            final_estado: begin 
                pronto = 1'b1; 
            end 
 
            default: begin 
                zera_bcd   = 1'b0; 
                zera_tick  = 1'b0; 
                conta_bcd  = 1'b0; 
                conta_tick  = 1'b0; 
                pronto     = 1'b0; 
            end 
 
        endcase 
    end 
 
endmodule