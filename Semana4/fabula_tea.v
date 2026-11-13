// Top do Fabula TEA+: UC, FD e seis displays da FPGA.
// Clock de 50 MHz; UART 115200 baud, 7E1.
module fabula_tea (
    input wire clock,
    input wire reset,
    input wire contar,
    input wire recontar,
    input wire relembrar,
    input wire entrada_serial,

    // Selecao do tamanho da historia
    input wire escolhe_tamanho,

    // Selecao da historia
    input wire [1:0] escolhe_historia,

    // Teclado matricial 4x4
    input wire [3:0] C,
    output wire [3:0] L,

    // Saidas principais
    output wire pwm,
    output wire saida_serial,
    output wire acertou,
    output wire errou,
    output wire contando,
    output wire recontando,
    output wire relembrando,
    output wire selecionando_tamanho,

    // Displays de sete segmentos
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,

    output wire [6:0] display_dezena,
    output wire [6:0] display_unidade,

    // Depuracao
    output wire db_rx_serial,
    output wire db_pronto_rx,
    output wire db_jogada_feita,
    output wire db_pwm,
    output wire partida_serial,
    output wire db_tx_serial,
    output wire pronto_serial
);

    // --------------------------------------------------
    // Fios de conexao UC <-> FD
    // --------------------------------------------------

    wire fimHistoria;
    wire fimExibicao;
    wire igual;

    wire contaC;
    wire zeraC;
    wire registraR;
    wire zeraR;
    wire registraModo;
    wire escreve;

    wire leds_BM;
    wire contaExibicao;
    wire zeraExibicao;

    wire habilitaJogada;
    wire registraExibicao;
    wire registraHistoria;

    wire [2:0] selCaracter;

    // --------------------------------------------------
    // Fios de controle da selecao de tamanho
    // --------------------------------------------------

    wire digito_valido;
    wire tamanho_valido;

    wire registraDezena;
    wire registraUnidade;
    wire zeraDigitos;

    // --------------------------------------------------
    // Fios de depuracao
    // --------------------------------------------------

    wire [6:0] db_estado;
    wire [6:0] db_contagem;
    wire [6:0] db_tamanhohistoria;
    wire [2:0] db_personagem;
    wire [1:0] db_historia;
    wire [3:0] situacao;

    // Controle dos displays externos
    wire [7:0] tamanho_real;
    wire [3:0] dezena_bcd;
    wire [3:0] unidade_bcd;
    wire habilita_displays;

    reg tamanho_configurado_display;

    // --------------------------------------------------
    // Sinais dos botoes apos debounce
    // --------------------------------------------------

    wire reset_db;
    wire contar_db;
    wire recontar_db;
    wire relembrar_db;
    wire escolhe_tamanho_db;


    // --------------------------------------------------
    // Debounce dos botoes - clock de 50 MHz
    // --------------------------------------------------

    debounce #(.DELAY(1_000_000)) db_reset (
        .clk(clock),
        .button_in(reset),
        .button_out(reset_db)
    );

    debounce #(.DELAY(1_000_000)) db_contar (
        .clk(clock),
        .button_in(contar),
        .button_out(contar_db)
    );

    debounce #(.DELAY(1_000_000)) db_recontar (
        .clk(clock),
        .button_in(recontar),
        .button_out(recontar_db)
    );

    debounce #(.DELAY(1_000_000)) db_relembrar (
        .clk(clock),
        .button_in(relembrar),
        .button_out(relembrar_db)
    );

    debounce #(.DELAY(1_000_000)) db_escolhe_tamanho (
        .clk(clock),
        .button_in(escolhe_tamanho),
        .button_out(escolhe_tamanho_db)
    );


    // --------------------------------------------------
    // Unidade de controle
    // --------------------------------------------------

    unidade_controle UC (
        .clock(clock),
        .reset(reset_db),

        // Comandos do jogador
        .contar(contar_db),
        .recontar(recontar_db),
        .relembrar(relembrar_db),
        .escolhe_tamanho(escolhe_tamanho_db),

        // Condicoes vindas do FD
        .fimHistoria(fimHistoria),
        .fimExibicao(fimExibicao),
        .jogada(db_jogada_feita),
        .igual(igual),
        .pronto_serial(pronto_serial),

        // Condicoes de selecao do tamanho
        .digito_valido(digito_valido),
        .tamanho_valido(tamanho_valido),

        // Saidas de situacao
        .acertou(acertou),
        .errou(errou),
        .contando(contando),
        .recontando(recontando),
        .relembrando(relembrando),
        .selecionando_tamanho(selecionando_tamanho),

        // Controle do FD
        .contaC(contaC),
        .zeraC(zeraC),
        .registraR(registraR),
        .zeraR(zeraR),
        .registraModo(registraModo),
        .escreve(escreve),
        .leds_BM(leds_BM),
        .contaExibicao(contaExibicao),
        .zeraExibicao(zeraExibicao),
        .habilitaJogada(habilitaJogada),
        .registraExibicao(registraExibicao),
        .registraHistoria(registraHistoria),

        // Controle da selecao do tamanho
        .registraDezena(registraDezena),
        .registraUnidade(registraUnidade),
        .zeraDigitos(zeraDigitos),

        // Controle UART
        .selCaracter(selCaracter),
        .partida_serial(partida_serial),

        // Depuracao
        .db_estado(db_estado)
    );

    // --------------------------------------------------
    // Fluxo de dados
    // --------------------------------------------------

    fluxo_dados FD (
        .clock(clock),
        .reset(reset_db),

        // UART de entrada
        .entrada_serial(entrada_serial),

        // Selecao da historia
        .escolhe_historia(escolhe_historia),

        // Teclado matricial
        .C(C),
        .L(L),

        // Controle de selecao do tamanho
        .registraDezena(registraDezena),
        .registraUnidade(registraUnidade),
        .zeraDigitos(zeraDigitos),
        .registraModo(registraModo),

        // Condicoes para a UC
        .digito_valido(digito_valido),
        .tamanho_valido(tamanho_valido),
        .fimHistoria(fimHistoria),
        .fimExibicao(fimExibicao),
        .jogada_feita(db_jogada_feita),
        .igual(igual),
        .pronto_serial(pronto_serial),

        // Comandos da UC
        .contaC(contaC),
        .zeraC(zeraC),
        .registraR(registraR),
        .zeraR(zeraR),
        .escreve(escreve),
        .seletorLedsBM(leds_BM),
        .contaExibicao(contaExibicao),
        .zeraExibicao(zeraExibicao),
        .habilitaJogada(habilitaJogada),
        .registraExibicao(registraExibicao),
        .registraHistoria(registraHistoria),

        // UART de saida
        .selCaracter(selCaracter),
        .partida_serial(partida_serial),

        // Saidas principais
        .pwm(pwm),
        .saida_serial(saida_serial),

        // Depuracao
        .db_contagem(db_contagem),
        .db_memoria(),
        .db_tamanhohistoria(db_tamanhohistoria),
        .db_historia(db_historia),
        .db_personagem(db_personagem),
        .db_pronto_rx(db_pronto_rx)
    );

    // --------------------------------------------------
    // Indicacao da situacao do sistema
    // --------------------------------------------------

    // 0 = Inicial
    // 1 = Contando
    // 2 = Recontando
    // 3 = Relembrando
    // 4 = Acertou
    // 5 = Errou
    // 6 = Selecionando tamanho

    assign situacao = selecionando_tamanho ? 4'd6 :
                      acertou             ? 4'd4 :
                      errou               ? 4'd5 :
                      relembrando         ? 4'd3 :
                      recontando          ? 4'd2 :
                      contando            ? 4'd1 : 4'd0;


    // --------------------------------------------------
    // Conversao do tamanho da historia para BCD
    // --------------------------------------------------

    // RegModo armazena tamanho - 1
    assign tamanho_real = {1'b0, db_tamanhohistoria} + 8'd1;

    // Separacao em dezena e unidade
    assign dezena_bcd = tamanho_real / 8'd10;
    assign unidade_bcd = tamanho_real % 8'd10;


    // --------------------------------------------------
    // Habilitacao dos displays externos
    // --------------------------------------------------

    always @(posedge clock or posedge reset_db) begin
        if (reset_db)
            tamanho_configurado_display <= 1'b0;
        else if (registraModo)
            tamanho_configurado_display <= 1'b1;
    end

    assign habilita_displays =
        tamanho_configurado_display && !selecionando_tamanho;


    // --------------------------------------------------
    // Displays externos de sete segmentos
    // --------------------------------------------------

    encoder_display_externo encoder_dezena (
        .digito(dezena_bcd),
        .enable(habilita_displays),
        .segmentos(display_dezena)
    );

    encoder_display_externo encoder_unidade (
        .digito(unidade_bcd),
        .enable(habilita_displays),
        .segmentos(display_unidade)
    );

    // --------------------------------------------------
    // Displays de sete segmentos
    // --------------------------------------------------

    // HEX0: historia escolhida
    hexa7seg_3bits display_historia (
        .hexa({1'b0, db_historia}),
        .enable(1'b1),
        .display(HEX0)
    );

    // HEX1: personagem apresentado
    hexa7seg display_personagem (
        .hexa({1'b0, db_personagem}),
        .display(HEX1)
    );

    // HEX2: endereco da RAM
    hexa7seg display_contagem (
        .hexa(db_contagem[3:0]),
        .display(HEX2)
    );

    // HEX3: situacao do sistema
    hexa7seg display_situacao (
        .hexa(situacao),
        .display(HEX3)
    );

    // HEX4: digito menos significativo do estado
    hexa7seg display_estado_lo (
        .hexa(db_estado[3:0]),
        .display(HEX4)
    );

    // HEX5: digito mais significativo do estado
    // Suporta estados ate 66 decimal (42 hexadecimal)
    hexa7seg_3bits display_estado_hi (
        .hexa(db_estado[6:4]),
        .enable(1'b1),
        .display(HEX5)
    );

    // --------------------------------------------------
    // Sinais de depuracao
    // --------------------------------------------------

    assign db_rx_serial = entrada_serial;
    assign db_pwm = pwm;
    assign db_tx_serial = saida_serial;

endmodule
