# Testbenches para a prova de LabDigII

Comece por **sonar_tb_M.v**. Cada arquivo é independente e tem o roteiro no primeiro `initial`, marcado **EDITE AQUI**. O `sonar_tb.v` original foi preservado.

| Arquivo | Roteiro | Posições medidas (graus) |
|---|---|---|
| `sonar_tb_M.v` | 3 ciclos de localização, recebe `a`, 2 de atenção | 20, 40, 60 → 80, 80 |
| `sonar_tb_localizacao.v` | Varredura completa e retorno ao início | 20, 40, 60, 80, 100, 120, 140, 160, 20 |
| `sonar_tb_retorno.v` | Localização → `a` → atenção → `v` → localização | 20, 40 → 60, 60 → 60, 80 |
| `sonar_tb_comandos.v` | Caracteres inválidos e comandos repetidos | Confere que `x` e `A` são ignorados e repetir um comando mantém o modo |
| `sonar_tb_reset.v` | Reset em atenção, entre duas medidas | Reinicia em localização, 20° |
| `sonar_tb_liga_desliga.v` | Inicialmente desligado, liga, desliga e religa | Confere ausência de novas medidas desligado e reinício em 20° |

## Como adaptar em poucos minutos

```verilog
reiniciar;             // Reset; deixa ligar=0, localização, posição 20°.
ligar = 1;
medir(100, 20, 0);     // Simula 100 cm, espera 20°, em localização.
medir( 75, 40, 0);     // Simula 75 cm, espera 40°, em localização.
enviar("a");           // Envia pela entrada serial de verdade, em 7E1.
conferir_modo(1);
repeat (3) medir(50, 60, 1); // Três medidas de 50 cm, parado em 60°.
enviar("v");
conferir_modo(0);
medir(80, 60, 0);      // Retoma a varredura a partir de 60°.
medir(90, 80, 0);
terminar;              // Desliga, confere e encerra a simulação.
```

- **Quantidade de ciclos:** acrescente/remova chamadas de `medir`. Um ciclo aqui significa uma medida e o envio dos oito caracteres, não um período do clock.
- **Distância:** mude o primeiro argumento (use valores inteiros de 2 a 400 cm para estes roteiros).
- **Ângulo esperado:** mude o segundo argumento. Localização avança 20° por ciclo e retorna a 20° depois de 160°. Atenção mantém a posição.
- **Modo esperado:** terceiro argumento: `0` localização, `1` atenção.
- **Comandos:** use `enviar("a")` ou `enviar("v")`, entre chamadas de `medir`. Os argumentos de `medir` conferem ângulo/modo; não forçam o circuito a assumir esses valores.
- **Reset:** `reiniciar; ligar = 1;`. O contador `ciclo` do testbench continua contando para identificar as etapas no Transcript.

Evite inserir atrasos arbitrários entre chamadas: o próximo trigger pode acontecer enquanto o roteiro está esperando. Com o timer acelerado, cabem os dois comandos consecutivos usados nos exemplos; para sequências maiores, aumente o timer. A tarefa `medir` precisa estar esperando quando o trigger subir.

## Por que o cenário M fica em 80°?

Neste RTL, `sonar_uc.v` passa por `avanca_posicao` **antes** de levantar `fim_posicao`. Assim, quando o terceiro `medir` termina, a medida enviada foi em 60°, mas o comando do servo já está em 80°. Receber `a` nesse intervalo mantém 80° nos ciclos seguintes.

Se o enunciado exigir atenção em 60°, isso precisa ser discutido em relação à sequência da UC: simplesmente trocar o ângulo esperado no testbench não muda o circuito. Receber `a` durante uma medida de localização também não cancela o avanço já previsto nessa sequência de estados. `db_modo` muda com o comando recebido, mas o ramo da medida seguinte é escolhido em `seleciona_modo`.

## Executar no ModelSim

Na pasta `Experiencia6`, pelo Transcript:

```tcl
set cenario M
do sonar_cenarios.do
```

Troque `M` por `localizacao`, `retorno`, `comandos`, `reset` ou `liga_desliga`. O script compila os `.v` em SystemVerilog para suportar `$fatal`, seleciona **somente um módulo de testbench** e adiciona os sinais à janela Wave. Os arquivos usam sintaxe simples de Verilog, com `$fatal` para interromper falhas.

Sem o script, em uma biblioteca `work` já criada:

```tcl
vlog -sv *.v
vsim -onfinish stop work.sonar_tb_M
add wave sim:/sonar_tb_M/*
run -all
```

Para entregar com o nome obrigatório `sonar_tb.v`, copie o cenário escolhido para uma pasta separada, renomeie o arquivo e altere também `module sonar_tb_M;` para `module sonar_tb;`. Compile nessa pasta com os fontes do circuito, sem outro módulo de mesmo nome.

## O que observar e o que é conferido

Cada `medir` espera o trigger, gera um echo e lê o pacote **diretamente de `saida_serial`**, verificando start, paridade par, stop e os oito caracteres `AAA,DDD#`. Por exemplo: `020,100#`. Depois espera `fim_posicao` e verifica o avanço (ou a manutenção) da posição. Falhas interrompem com `FATAL`; sucesso termina com `PASSOU`.

Na Wave, `posicao` é um índice: 0=20°, 1=40°, …, 7=160°. `distancia_bcd` deve ser vista em hexadecimal: `100` representa 100 cm em BCD. `pwm` está disponível para inspeção; estes roteiros não verificam automaticamente a largura dos pulsos do servo. A leitura de posição e estado depende dos nomes internos do projeto atual.

A largura do echo é `cm * 58_820` ns, calculada a partir dos 2941 clocks/cm usados no circuito. Para ensaiar arredondamentos ou pulsos específicos, edite esse atraso na tarefa `medir` e ajuste o valor esperado do pacote conforme a distância resultante.

## Tempo de simulação

Por padrão, `defparam dut.FD.TIMER_2SEG.M = 20_000` reduz **apenas** a espera entre medidas de 2 s para 400 µs. Clock, echo, UART e PWM mantêm suas temporizações. Isso testa a sequência lógica, mas não comprova o intervalo real de 2 s nem o movimento físico do servo.

Se a prova exigir o intervalo real, comente o `defparam`, mude o timeout final para `#60_000_000_000` (60 s) e execute `run -all`. Para observar o circuito desligado por mais de 2 s, aumente também o `repeat (30_000)` de `desligar_e_conferir`, por exemplo para `repeat (110_000_000)` (2,2 s). A simulação será bem mais demorada.

Os cenários de reset e desligamento atuam **entre medidas**. Eles não cobrem interrupção no meio de um echo ou de um pacote serial, nem ausência de resposta do sensor ou erro de paridade na entrada RX.
