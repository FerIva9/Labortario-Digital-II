
`timescale 1ns/1ps

module fluxo_dados_tb;

    reg clock = 0;
    always #10 clock = ~clock;

    reg reset = 1;
    reg registraModo = 0;
    reg registraDezena = 0;
    reg registraUnidade = 0;
    reg zeraC = 0;
    reg contaC = 0;
    reg escreve = 0;

    wire fimHistoria;
    wire tamanho_valido;
    wire [6:0] db_contagem;
    wire [6:0] db_tamanhohistoria;
    wire [5:0] db_memoria;

    integer i;

    fluxo_dados dut (
        .clock(clock),
        .reset(reset),

        .registraModo(registraModo),
        .registraDezena(registraDezena),
        .registraUnidade(registraUnidade),
        .zeraDigitos(1'b0),

        .contaC(contaC),
        .zeraC(zeraC),
        .escreve(escreve),

        .C(4'b1111),
        .escolhe_historia(2'b00),
        .registraHistoria(1'b0),
        .entrada_serial(1'b1),
        .habilitaJogada(1'b0),
        .registraR(1'b0),
        .zeraR(1'b0),
        .registraExibicao(1'b0),
        .contaExibicao(1'b0),
        .zeraExibicao(1'b0),
        .seletorLedsBM(1'b0),
        .partida_serial(1'b0),
        .selCaracter(3'b000),

        .fimHistoria(fimHistoria),
        .tamanho_valido(tamanho_valido),
        .db_contagem(db_contagem),
        .db_tamanhohistoria(db_tamanhohistoria),
        .db_memoria(db_memoria)
    );

    initial begin
        // Reset inicial
        repeat (2) @(negedge clock);
        reset = 0;

        // Simula tecla 9 pressionada
        force dut.tecla = 4'd9;

        // Registra dezena = 9
        registraDezena = 1;
        @(negedge clock);
        registraDezena = 0;

        // Registra unidade = 9
        registraUnidade = 1;
        @(negedge clock);
        registraUnidade = 0;

        release dut.tecla;

        // Salva o tamanho da historia
        registraModo = 1;
        @(negedge clock);
        registraModo = 0;

        #1;
        $display("Tamanho valido: %b", tamanho_valido);
        $display("Limite registrado: %d", db_tamanhohistoria);

        // Simula personagem recebido
        force dut.registrador_w = 6'b000001;

        // Escreve 99 personagens na RAM
        for (i = 0; i < 99; i = i + 1) begin
            escreve = 1;

            // Nao avanca apos o endereco 98
            contaC = (i < 98);

            @(posedge clock);
            #1;

            if (i == 0 || i == 15 ||
                i == 16 || i == 98) begin

                $display("Contador=%d | Fim=%b",
                         db_contagem, fimHistoria);
            end

            @(negedge clock);
        end

        escreve = 0;
        contaC = 0;

        #1;
        $display("Ultimo dado RAM: %b", db_memoria);

        if (db_contagem == 98 &&
            fimHistoria == 1 &&
            db_memoria == 6'b000001)
            $display("TESTE PASSOU!");
        else
            $display("TESTE FALHOU!");

        #50;
        $stop;
    end

endmodule
