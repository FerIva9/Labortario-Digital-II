module sonar_uc (
    input wire clock,
    input wire reset,
    input wire ligar,

    input wire fim_medida,
    input wire pronto_serial,
    input wire fim_2seg,
    input wire pronto_rx,
    input wire [6:0] dados_ascii_rx,
    input wire paridade_par_rx,

    output reg reset_fd,
    output reg zera_posicao,
    output reg conta_posicao,
    output reg zera_timer,
    output reg conta_timer,
    output reg medir,
    output reg [2:0] sel_ascii,
    output reg partida_serial,
    output reg fim_posicao,
    output reg db_modo,
    output wire [5:0] db_estado
);
    reg [5:0] Eatual, Eprox;
    reg modo;

    // Estados originais do modo de localizacao.
    localparam inicial                       = 6'd0;
    localparam preparacao                    = 6'd1;
    localparam aguarda_2seg                  = 6'd2;
    localparam inicia_medida                 = 6'd3;
    localparam aguarda_medida                = 6'd4;
    localparam transmite_centena_angulo      = 6'd5;
    localparam espera_centena_angulo         = 6'd6;
    localparam transmite_dezena_angulo       = 6'd7;
    localparam espera_dezena_angulo          = 6'd8;
    localparam transmite_unidade_angulo      = 6'd9;
    localparam espera_unidade_angulo         = 6'd10;
    localparam transmite_virgula             = 6'd11;
    localparam espera_virgula                = 6'd12;
    localparam transmite_centena_distancia   = 6'd13;
    localparam espera_centena_distancia      = 6'd14;
    localparam transmite_dezena_distancia    = 6'd15;
    localparam espera_dezena_distancia       = 6'd16;
    localparam transmite_unidade_distancia   = 6'd17;
    localparam espera_unidade_distancia      = 6'd18;
    localparam transmite_hashtag             = 6'd19;
    localparam espera_hashtag                = 6'd20;
    localparam avanca_posicao                = 6'd21;
    localparam final_medida                  = 6'd22;

    // Estados novos: selecao do ramo e sequencia exclusiva de atencao.
    localparam seleciona_modo                = 6'd23;
    localparam inicia_medida_atencao         = 6'd24;
    localparam aguarda_medida_atencao        = 6'd25;
    localparam transmite_centena_angulo_atencao = 6'd26;
    localparam espera_centena_angulo_atencao = 6'd27;
    localparam transmite_dezena_angulo_atencao = 6'd28;
    localparam espera_dezena_angulo_atencao  = 6'd29;
    localparam transmite_unidade_angulo_atencao = 6'd30;
    localparam espera_unidade_angulo_atencao = 6'd31;
    localparam transmite_virgula_atencao     = 6'd32;
    localparam espera_virgula_atencao        = 6'd33;
    localparam transmite_centena_distancia_atencao = 6'd34;
    localparam espera_centena_distancia_atencao = 6'd35;
    localparam transmite_dezena_distancia_atencao = 6'd36;
    localparam espera_dezena_distancia_atencao = 6'd37;
    localparam transmite_unidade_distancia_atencao = 6'd38;
    localparam espera_unidade_distancia_atencao = 6'd39;
    localparam transmite_hashtag_atencao     = 6'd40;
    localparam espera_hashtag_atencao        = 6'd41;
    localparam final_atencao                 = 6'd42;

    // Mantem os tres blocos always da UC: estado, proximo estado e saidas.
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            Eatual <= inicial;
            modo   <= 1'b0;
        end else begin
            Eatual <= Eprox;
            if (pronto_rx && paridade_par_rx) begin
                if (dados_ascii_rx == 7'h61)
                    modo <= 1'b1; // 'a'
                else if (dados_ascii_rx == 7'h76)
                    modo <= 1'b0; // 'v'
            end
        end
    end

    always @(*) begin
        Eprox = inicial;
        if (!ligar) begin
            Eprox = inicial;
        end else begin
            case (Eatual)
                inicial:       Eprox = preparacao;
                preparacao:    Eprox = aguarda_2seg;
                aguarda_2seg:  Eprox = fim_2seg ? seleciona_modo : aguarda_2seg;
                seleciona_modo:Eprox = modo ? inicia_medida_atencao : inicia_medida;

                // Sequencia original de localizacao.
                inicia_medida: Eprox = aguarda_medida;
                aguarda_medida: Eprox = fim_medida ? transmite_centena_angulo : aguarda_medida;
                transmite_centena_angulo: Eprox = espera_centena_angulo;
                espera_centena_angulo: Eprox = pronto_serial ? transmite_dezena_angulo : espera_centena_angulo;
                transmite_dezena_angulo: Eprox = espera_dezena_angulo;
                espera_dezena_angulo: Eprox = pronto_serial ? transmite_unidade_angulo : espera_dezena_angulo;
                transmite_unidade_angulo: Eprox = espera_unidade_angulo;
                espera_unidade_angulo: Eprox = pronto_serial ? transmite_virgula : espera_unidade_angulo;
                transmite_virgula: Eprox = espera_virgula;
                espera_virgula: Eprox = pronto_serial ? transmite_centena_distancia : espera_virgula;
                transmite_centena_distancia: Eprox = espera_centena_distancia;
                espera_centena_distancia: Eprox = pronto_serial ? transmite_dezena_distancia : espera_centena_distancia;
                transmite_dezena_distancia: Eprox = espera_dezena_distancia;
                espera_dezena_distancia: Eprox = pronto_serial ? transmite_unidade_distancia : espera_dezena_distancia;
                transmite_unidade_distancia: Eprox = espera_unidade_distancia;
                espera_unidade_distancia: Eprox = pronto_serial ? transmite_hashtag : espera_unidade_distancia;
                transmite_hashtag: Eprox = espera_hashtag;
                espera_hashtag: Eprox = pronto_serial ? avanca_posicao : espera_hashtag;
                avanca_posicao: Eprox = final_medida;
                final_medida: Eprox = preparacao;

                // Sequencia nova de atencao: nao passa por avanca_posicao.
                inicia_medida_atencao: Eprox = aguarda_medida_atencao;
                aguarda_medida_atencao: Eprox = fim_medida ? transmite_centena_angulo_atencao : aguarda_medida_atencao;
                transmite_centena_angulo_atencao: Eprox = espera_centena_angulo_atencao;
                espera_centena_angulo_atencao: Eprox = pronto_serial ? transmite_dezena_angulo_atencao : espera_centena_angulo_atencao;
                transmite_dezena_angulo_atencao: Eprox = espera_dezena_angulo_atencao;
                espera_dezena_angulo_atencao: Eprox = pronto_serial ? transmite_unidade_angulo_atencao : espera_dezena_angulo_atencao;
                transmite_unidade_angulo_atencao: Eprox = espera_unidade_angulo_atencao;
                espera_unidade_angulo_atencao: Eprox = pronto_serial ? transmite_virgula_atencao : espera_unidade_angulo_atencao;
                transmite_virgula_atencao: Eprox = espera_virgula_atencao;
                espera_virgula_atencao: Eprox = pronto_serial ? transmite_centena_distancia_atencao : espera_virgula_atencao;
                transmite_centena_distancia_atencao: Eprox = espera_centena_distancia_atencao;
                espera_centena_distancia_atencao: Eprox = pronto_serial ? transmite_dezena_distancia_atencao : espera_centena_distancia_atencao;
                transmite_dezena_distancia_atencao: Eprox = espera_dezena_distancia_atencao;
                espera_dezena_distancia_atencao: Eprox = pronto_serial ? transmite_unidade_distancia_atencao : espera_dezena_distancia_atencao;
                transmite_unidade_distancia_atencao: Eprox = espera_unidade_distancia_atencao;
                espera_unidade_distancia_atencao: Eprox = pronto_serial ? transmite_hashtag_atencao : espera_unidade_distancia_atencao;
                transmite_hashtag_atencao: Eprox = espera_hashtag_atencao;
                espera_hashtag_atencao: Eprox = pronto_serial ? final_atencao : espera_hashtag_atencao;
                final_atencao: Eprox = preparacao;
                default: Eprox = inicial;
            endcase
        end
    end

    always @(*) begin
        reset_fd       = 1'b0;
        zera_posicao   = 1'b0;
        conta_posicao  = 1'b0;
        zera_timer     = 1'b0;
        conta_timer    = 1'b0;
        medir          = 1'b0;
        sel_ascii      = 3'b000;
        partida_serial = 1'b0;
        fim_posicao    = 1'b0;
        db_modo        = modo;

        case (Eatual)
            inicial: reset_fd = 1'b1;
            preparacao: zera_timer = 1'b1;
            aguarda_2seg: conta_timer = 1'b1;
            inicia_medida, inicia_medida_atencao: medir = 1'b1;

            transmite_centena_angulo, transmite_centena_angulo_atencao: begin
                sel_ascii = 3'b000; partida_serial = 1'b1;
            end
            espera_centena_angulo, espera_centena_angulo_atencao: sel_ascii = 3'b000;
            transmite_dezena_angulo, transmite_dezena_angulo_atencao: begin
                sel_ascii = 3'b001; partida_serial = 1'b1;
            end
            espera_dezena_angulo, espera_dezena_angulo_atencao: sel_ascii = 3'b001;
            transmite_unidade_angulo, transmite_unidade_angulo_atencao: begin
                sel_ascii = 3'b010; partida_serial = 1'b1;
            end
            espera_unidade_angulo, espera_unidade_angulo_atencao: sel_ascii = 3'b010;
            transmite_virgula, transmite_virgula_atencao: begin
                sel_ascii = 3'b011; partida_serial = 1'b1;
            end
            espera_virgula, espera_virgula_atencao: sel_ascii = 3'b011;
            transmite_centena_distancia, transmite_centena_distancia_atencao: begin
                sel_ascii = 3'b100; partida_serial = 1'b1;
            end
            espera_centena_distancia, espera_centena_distancia_atencao: sel_ascii = 3'b100;
            transmite_dezena_distancia, transmite_dezena_distancia_atencao: begin
                sel_ascii = 3'b101; partida_serial = 1'b1;
            end
            espera_dezena_distancia, espera_dezena_distancia_atencao: sel_ascii = 3'b101;
            transmite_unidade_distancia, transmite_unidade_distancia_atencao: begin
                sel_ascii = 3'b110; partida_serial = 1'b1;
            end
            espera_unidade_distancia, espera_unidade_distancia_atencao: sel_ascii = 3'b110;
            transmite_hashtag, transmite_hashtag_atencao: begin
                sel_ascii = 3'b111; partida_serial = 1'b1;
            end
            espera_hashtag, espera_hashtag_atencao: sel_ascii = 3'b111;

            avanca_posicao: conta_posicao = 1'b1;
            final_medida, final_atencao: fim_posicao = 1'b1;
            default: reset_fd = 1'b1;
        endcase
    end

    assign db_estado = Eatual;
endmodule
