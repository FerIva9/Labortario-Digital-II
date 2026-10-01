/*
 * sonar_uc.v - unidade de controle Moore do sonar, com 23 estados.
 * Sequencia: espera 2 s, mede, transmite "angulo,distancia#" e avanca.
 * ligar=0 retorna a inicial na proxima borda do clock.
 */
module sonar_uc (
    input wire clock,
    input wire reset,
    input wire ligar,

    // Indicacoes vindas do fluxo de dados.
    input wire fim_medida,
    input wire pronto_serial,
    input wire fim_2seg,

    // Comandos para o fluxo de dados.
    output reg reset_fd,
    output reg zera_posicao,
    output reg conta_posicao,
    output reg zera_timer,
    output reg conta_timer,
    output reg medir,
    output reg [2:0] sel_ascii,
    output reg partida_serial,

    output reg fim_posicao,
    output wire [4:0] db_estado
);
    reg [4:0] Eatual, Eprox;

    localparam inicial                       = 5'd0;
    localparam preparacao                    = 5'd1;
    localparam aguarda_2seg                  = 5'd2;
    localparam inicia_medida                 = 5'd3;
    localparam aguarda_medida                = 5'd4;
    localparam transmite_centena_angulo      = 5'd5;
    localparam espera_centena_angulo         = 5'd6;
    localparam transmite_dezena_angulo       = 5'd7;
    localparam espera_dezena_angulo          = 5'd8;
    localparam transmite_unidade_angulo      = 5'd9;
    localparam espera_unidade_angulo         = 5'd10;
    localparam transmite_virgula             = 5'd11;
    localparam espera_virgula                = 5'd12;
    localparam transmite_centena_distancia   = 5'd13;
    localparam espera_centena_distancia      = 5'd14;
    localparam transmite_dezena_distancia    = 5'd15;
    localparam espera_dezena_distancia       = 5'd16;
    localparam transmite_unidade_distancia   = 5'd17;
    localparam espera_unidade_distancia      = 5'd18;
    localparam transmite_hashtag             = 5'd19;
    localparam espera_hashtag                = 5'd20;
    localparam avanca_posicao                = 5'd21;
    localparam final_medida                  = 5'd22;

    // Registrador de estado, com reset assincrono ativo em 1.
    always @(posedge clock or posedge reset) begin
        if (reset)
            Eatual <= inicial;
        else
            Eatual <= Eprox;
    end

    // Desligar tem prioridade sobre todas as transicoes normais.
    always @(*) begin
        Eprox = inicial;
        if (!ligar) begin
            Eprox = inicial;
        end else begin
            case (Eatual)
                inicial:       Eprox = preparacao;
                preparacao:    Eprox = aguarda_2seg;
                aguarda_2seg:  Eprox = fim_2seg ? inicia_medida : aguarda_2seg;
                inicia_medida: Eprox = aguarda_medida;
                aguarda_medida: Eprox = fim_medida ? transmite_centena_angulo : aguarda_medida;
                transmite_centena_angulo:
                    Eprox = espera_centena_angulo;
                espera_centena_angulo:
                    Eprox = pronto_serial ? transmite_dezena_angulo : espera_centena_angulo;
                transmite_dezena_angulo:
                    Eprox = espera_dezena_angulo;
                espera_dezena_angulo:
                    Eprox = pronto_serial ? transmite_unidade_angulo : espera_dezena_angulo;
                transmite_unidade_angulo:
                    Eprox = espera_unidade_angulo;
                espera_unidade_angulo:
                    Eprox = pronto_serial ? transmite_virgula : espera_unidade_angulo;
                transmite_virgula:
                    Eprox = espera_virgula;
                espera_virgula:
                    Eprox = pronto_serial ? transmite_centena_distancia : espera_virgula;
                transmite_centena_distancia:
                    Eprox = espera_centena_distancia;
                espera_centena_distancia:
                    Eprox = pronto_serial ? transmite_dezena_distancia : espera_centena_distancia;
                transmite_dezena_distancia:
                    Eprox = espera_dezena_distancia;
                espera_dezena_distancia:
                    Eprox = pronto_serial ? transmite_unidade_distancia : espera_dezena_distancia;
                transmite_unidade_distancia:
                    Eprox = espera_unidade_distancia;
                espera_unidade_distancia:
                    Eprox = pronto_serial ? transmite_hashtag : espera_unidade_distancia;
                transmite_hashtag:
                    Eprox = espera_hashtag;
                espera_hashtag:
                    Eprox = pronto_serial ? avanca_posicao : espera_hashtag;
                avanca_posicao: Eprox = final_medida;
                final_medida:   Eprox = preparacao;
                default:        Eprox = inicial;
            endcase
        end
    end

    // Saidas Moore: dependem somente do estado atual.
    always @(*) begin
        reset_fd      = 1'b0;
        // O reset_fd ja zera a posicao em inicial.
        zera_posicao  = 1'b0;
        conta_posicao = 1'b0;
        zera_timer    = 1'b0;
        conta_timer   = 1'b0;
        medir         = 1'b0;
        sel_ascii     = 3'b000;
        partida_serial = 1'b0;
        fim_posicao   = 1'b0;

        case (Eatual)
            inicial: reset_fd = 1'b1;
            // Nao acionar reset_fd aqui: a posicao deve ser preservada.
            preparacao: zera_timer = 1'b1;
            aguarda_2seg: conta_timer = 1'b1;
            inicia_medida: medir = 1'b1;
            aguarda_medida: begin end
            transmite_centena_angulo: begin
                sel_ascii = 3'b000;
                partida_serial = 1'b1;
            end
            espera_centena_angulo: sel_ascii = 3'b000;
            transmite_dezena_angulo: begin
                sel_ascii = 3'b001;
                partida_serial = 1'b1;
            end
            espera_dezena_angulo: sel_ascii = 3'b001;
            transmite_unidade_angulo: begin
                sel_ascii = 3'b010;
                partida_serial = 1'b1;
            end
            espera_unidade_angulo: sel_ascii = 3'b010;
            transmite_virgula: begin
                sel_ascii = 3'b011;
                partida_serial = 1'b1;
            end
            espera_virgula: sel_ascii = 3'b011;
            transmite_centena_distancia: begin
                sel_ascii = 3'b100;
                partida_serial = 1'b1;
            end
            espera_centena_distancia: sel_ascii = 3'b100;
            transmite_dezena_distancia: begin
                sel_ascii = 3'b101;
                partida_serial = 1'b1;
            end
            espera_dezena_distancia: sel_ascii = 3'b101;
            transmite_unidade_distancia: begin
                sel_ascii = 3'b110;
                partida_serial = 1'b1;
            end
            espera_unidade_distancia: sel_ascii = 3'b110;
            transmite_hashtag: begin
                sel_ascii = 3'b111;
                partida_serial = 1'b1;
            end
            espera_hashtag: sel_ascii = 3'b111;
            avanca_posicao: conta_posicao = 1'b1;
            final_medida: fim_posicao = 1'b1;
            default: reset_fd = 1'b1;
        endcase
    end

    assign db_estado = Eatual;
endmodule
