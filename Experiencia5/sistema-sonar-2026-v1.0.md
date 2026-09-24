# Sistema de Sonar

**EPUSP — PCS3645 — Laboratório de Projeto de Sistemas Digitais II**  
**Versão 2026**

## OBJETIVOS

Após a conclusão desta experiência, os seguintes tópicos devem ser conhecidos pelos alunos:

- Aplicação de sensor ultrassônico de distância e de servomotor em sistemas digitais;
- Uso de comunicação serial para transmissão de dados;
- Desenvolvimento de circuito para varredura e detecção de objetos;
- Desenvolvimento de máquina de estados para controle de um sistema estrutural;
- Aplicação da refatoração de código para revisar projetos funcionais;
- Desenvolvimento de circuitos e bancadas de teste para a composição de múltiplos componentes;
- Realização de testes de unidade e testes de integração de circuitos digitais;
- Projeto de circuitos em FPGA.

## RESUMO

Esta experiência tem por objetivo iniciar o desenvolvimento de um circuito que realiza a varredura e a detecção de objetos próximos com a utilização de um sensor ultrassônico de distância e de um servomotor e que possui uma saída serial de dados para se comunicar com um dispositivo de apresentação de dados.

O sistema de sonar será desenvolvido e testado para a placa FPGA DE0-CV usando a infraestrutura disponível na bancada do Laboratório Digital.

# 1. ESPECIFICAÇÃO DO PROJETO

Sistemas digitais conhecidos como **radar, lidar ou sonar** podem ser caracterizados como variações de um sistema que tem como função principal detectar objetos à distância. Inicialmente, o termo *radar* foi criado a partir do acrônimo da expressão em inglês *radio detection and ranging* que, em tradução livre, significa *detecção e localização por rádio (frequência)*. Essa detecção pode ser realizada por meio de ondas eletromagnéticas que são emitidas pelo radar, refletidas nos objetos distantes e recebidas por sensores. A detecção desses objetos permite localizá-los e medir sua distância. Dependendo do sinal eletromagnético usado, um sistema de detecção de objetos pode ser nomeado de forma diferente. Em sistemas veiculares autônomos em desenvolvimento por diversas empresas e grupos de pesquisa, por exemplo, uma das alternativas utilizadas é o **lidar** (*light detection and ranging*), em que a distância a objetos é aferida com o uso de um sinal luminoso (*laser*). Já em submarinos, usam-se ondas acústicas para propagação na água, e seu sistema de detecção e localização de objetos é chamado **sonar** (*sound navigation and ranging*). Dependendo da frequência acústica usada, o sonar pode ser infrassônico (baixas frequências) ou ultrassônico (altas frequências). Nesta experiência, o sensor ultrassônico de distância HC-SR04, que trabalha com pulsos ultrassônicos de 40KHz, será utilizado para projetar um sistema de sonar.

## 1.1. Interface do Circuito

O projeto desta experiência visa desenvolver um circuito digital que permite rastrear objetos pela medida de distância aos objetos. A interface básica de sinais do circuito deve seguir os sinais apresentados na figura 1. O processo de varredura e medida de distância aos objetos é executado com auxílio de um atuador e de um sensor específico.

O atuador escolhido é um servomotor de posição, responsável por posicionar o sensor de distância para a varredura e localização de objetos. O sensor escolhido é o sensor ultrassônico HC-SR04, já comentado.

### Figura 1: Interface básica do Sistema de Sonar

A figura apresenta o módulo principal conectado a um servomotor e a um sensor HC-SR04. A interface textual indicada no documento é:

```verilog
module sonar (
    input       clock,
    input       reset,
    input       ligar,
    input       echo,
    output      trigger,
    output      pwm,
    output      saida_serial,
    output      fim_posição
);
```

Conexões funcionais mostradas no diagrama:

- Entradas do sistema: `ligar`, `reset`, `clock` e `echo`.
- Saídas do sistema: `saida_serial`, `fim_posicao`, `pwm` e `trigger`.
- O sinal `pwm` é ligado ao servomotor.
- O sinal `trigger` é ligado ao sensor HC-SR04.
- O sinal `echo` retorna do sensor HC-SR04 para o circuito.

A montagem física dos componentes do sonar deve permitir uma variação angular **dentro dos limites especificados para o servomotor**. A figura 2 ilustra uma possível montagem física.

### Figura 2: Montagem do sistema de sonar na bancada do Laboratório Digital

> Imagem omitida neste arquivo Markdown, conforme solicitado.

A figura 2 mostra os principais elementos do projeto e sua interação durante o funcionamento do sistema de sonar. O sensor HC-SR04 deve ser acoplado ao servomotor, permitindo que o sensor seja rotacionado em relação ao eixo do servomotor. A cada posição angular, a distância ao objeto mais próximo deve ser medida. Em seguida, um bloco de informação composto por **posição angular e distância** deve ser enviado pela interface serial para que, posteriormente, ele seja graficamente representado na tela do computador. Um programa desenvolvido no ambiente *Processing* é fornecido como aplicação final da interface.

## 1.2. Descrição Sucinta do Funcionamento

O funcionamento do sistema de sonar deve seguir a seguinte descrição:

> O circuito do Sistema de Sonar deve somente iniciar sua operação com o acionamento do sinal **LIGAR**. A qualquer momento, o “desacionamento” do sinal **LIGAR** deve interromper o funcionamento do sistema. A interface do sonar com os componentes externos ocorre por meio dos sinais **TRIGGER, ECHO e PWM**. No modo de localização, o sistema deve continuamente realizar o ciclo de rastreamento de objetos, que consiste em (i.) medir a distância, (ii.) enviar os dados de posição e (iii.) reposicionar o conjunto servomotor e sensor a uma **taxa de 1 medida a cada 2 segundos**. Ao final de uma etapa de medição, envio serial e reposicionamento, o circuito deve gerar um pulso na saída **FIM_POSICAO**. O sinal de saída do circuito **SAIDA_SERIAL** é um sinal RS-232C que deve ser conectado a um dispositivo de comunicação serial, e a informação enviada é composta por dois valores: o ângulo de posicionamento do servomotor e a distância ao objeto nessa posição. Essa saída deve ser transmitida por um sinal RS-232C na configuração **7E1 a 115200 bauds** em formato **“ângulo,distância#”**, usando **caracteres ASCII**. Cada informação (ângulo e distância) deve ser composta por 3 dígitos BCD em código ASCII. Elas são separadas por um caractere `,` (vírgula), e um caractere `#` (*hashtag*) termina a mensagem, totalizando **8 dados ASCII enviados**. Por exemplo, uma saída que indica um objeto na posição angular 120° a 17 cm de distância deve ser composta pela sequência de dados ASCII **“120,017#”**.

## 1.3. Considerações para o Desenvolvimento do Projeto

Na sequência, apresentam-se considerações sobre o método de desenvolvimento do projeto do circuito do Sistema de Sonar.

### 1.3.1. Refatoração de Código

Inicialmente, deve-se executar a **refatoração do código fonte** dos circuitos projetados nas experiências anteriores. A refatoração é uma atividade ampla em projetos de Engenharia (de Software, principalmente) e envolve a alteração do projeto (ex.: código-fonte) visando, por exemplo, (i.) melhoria da legibilidade e entendimento, (ii.) melhoria de eficiência ou (iii.) correção de problemas. No contexto desta experiência, a técnica de refatoração deve ser utilizada para **revisar os componentes preexistentes** de forma a **adequar o seu funcionamento** para o sistema de sonar (e eventuais próximas experiências).

Convém mencionar que qualquer refatoração, revisão ou modificação de código deve ser seguida da realização do **teste** deste código, uma vez que ele foi alterado de alguma forma. Recomenda-se o uso do ModelSim para a execução dos testes para a verificação de funcionamento dos códigos após as refatorações.

#### A) Revisão do circuito de controle do servomotor

A revisão desse componente envolve uma modificação além da revisão de código. O circuito de controle do servomotor (`controle_servo.v`) deve ser modificado para gerar o sinal PWM de saída para **8 posições angulares** com as larguras de pulso da Tabela 1.

**Tabela 1: Posições, largura de pulso PWM, ciclos de clock de 50MHz e ângulos do servomotor.**

| posição | largura do pulso (ms) | ciclos de clock | ângulo |
|---|---:|---:|---:|
| 000 | 0,7 | 35.000 | 20° |
| 001 | 0,914 | 45.700 | 40° |
| 010 | 1,129 | 56.450 | 60° |
| 011 | 1,343 | 67.150 | 80° |
| 100 | 1,557 | 77.850 | 100° |
| 101 | 1,771 | 88.550 | 120° |
| 110 | 1,986 | 99.300 | 140° |
| 111 | 2,2 | 110.000 | 160° |

O módulo refatorado deve ser chamado `controle_servo_8` e seguir a interface da Figura 3.

### Figura 3: Módulo revisado para o controle do servomotor

```verilog
module controle_servo_8 (
    input       clock,
    input       reset,
    input [2:0] posicao,
    output      controle,
    output      db_reset,
    output [2:0] db_posicao,
    output      db_controle
);
```

Os sinais de depuração `db_reset` e `db_posicao` predefinidos podem ser usados na depuração do circuito em caso de mau funcionamento na placa FPGA. O sinal `db_reset` pode ser usado para verificar a entrada de *reset* do componente, e os sinais `db_posicao` e `db_controle` servem para depurar o funcionamento do circuito. Por exemplo, o sinal `db_controle` pode ser ligado em osciloscópio para monitorar sua forma de onda.

Para a realização de testes de verificação funcional do componente refatorado usando o **ModelSim**, recomenda-se o desenvolvimento de um *testbench* que gere o sinal de saída para as 8 posições definidas. Isso pode ser realizado em um único teste incluindo todos os casos de testes, um para cada posição do servomotor. A análise da forma de onda resultante deve validar as larguras de pulso para cada posição.

#### B) Revisão do circuito de transmissão serial

O circuito de transmissão serial assíncrona (`tx_serial_7E1.v`) com o modo de transmissão **7E1**, com dados de **7 bits**, paridade par e taxa de **115200 bauds**, deve ser refatorado antes de ser usado como componente interno. Os elementos para interface com dispositivos externos, como o detector de borda de início de transmissão (usado para tratar pulsos largos de entrada) e os codificadores de saída para *displays* de 7 segmentos, **devem ser retirados**. Além disso, as saídas projetadas para serem apresentadas em *displays* de 7 segmentos devem ser revisadas para mostrarem seus respectivos **valores binários**.

A definição do módulo revisado é apresentada na figura 4.

O sinal de depuração `db_partida` pode ser usado para verificar a entrada `partida`. Já o sinal `db_saida_serial` pode ser conectado em osciloscópio e analisador lógico para verificar o sinal serial. Por fim, o sinal de estado da Unidade de Controle do módulo de transmissão serial, `db_estado`, pode ser usado para verificar o funcionamento do componente.

O respectivo *testbench* aplicado na experiência de transmissão serial assíncrona deve ser adaptado para as simulações com o ModelSim. As formas de onda resultantes devem ser analisadas para validar o funcionamento do componente refatorado.

### Figura 4: Módulo revisado para a transmissão serial

```verilog
module tx_serial_7E1 (
    input       clock,
    input       reset,
    input       partida,
    input [6:0] dados_ascii,
    output      saida_serial,
    output      pronto,
    output      db_partida,
    output      db_saida_serial,
    output [3:0] db_estado
);
```

#### C) Revisão do circuito de interface com o sensor ultrassônico de distância

A funcionalidade do circuito interno da interface com o sensor ultrassônico de distância HC-SR04 (`interface_hcsr04.v`)¹ não precisa ser modificada para esta experiência. Recomenda-se apenas realizar uma revisão do código para ajustar a interface do componente.

O módulo refatorado de `interface_hcsr04` deve seguir a interface da Figura 5.

### Figura 5: Módulo revisado para a interface com HC-SR04

```verilog
module interface_hcsr04 (
    input        clock,
    input        reset,
    input        medir,
    input        echo,
    output       trigger,
    output [11:0] medida,
    output       pronto,
    output       db_reset,
    output       db_medir,
    output [3:0] db_estado
);
```

Os sinais de depuração definidos servem para os procedimentos de verificação de mau funcionamento na placa FPGA. Por exemplo, os sinais `db_reset` e `db_medir` podem ser usados para verificar as entradas do componente, ao passo que o sinal `db_estado` pode ser usado para monitorar o funcionamento interno do componente.

Este componente refatorado pode ser testado e verificado com o ModelSim usando como base o *testbench* fornecido na experiência **“Interface com Sensor Ultrassônico de Distância”**.

### 1.3.2. Dicas para o desenvolvimento do Sistema de Sonar

Segundo o método de projeto de Sistemas Digitais, é recomendável elaborar o **pseudocódigo** do funcionamento do sistema como ponto de partida. Com base no pseudocódigo, deve-se elaborar a sequência de operações² essenciais com o acionamento dos componentes correspondentes, devidamente desenvolvidos e testados em experiências anteriores e/ou durante o processo de refatoração.

Um esboço do pseudocódigo do Sistema de Sonar é apresentado na Figura 6.

### Figura 6: Esboço do pseudocódigo do sistema de sonar

```text
pseudocódigo: Sistema de Sonar
entradas: ligar, echo
saídas: trigger, pwm, saida_serial, fim_posicao

1. loop infinito
2.     enquanto ligar=0 espera
3.         inicie componentes internos
4.         posicionamento inicial do servomotor
5.         faça
6.             aguardar 2 segundos
7.             medir distância ao objeto
8.             transmitir dados do sonar
9.             mudar servomotor para próxima posição
10.        enquanto ligar=1
11. fim loop
```

Para o **desenvolvimento incremental** do projeto da experiência, sugere-se que a integração dos componentes descritos seja realizada de forma incremental. Por exemplo, em uma primeira etapa pode-se realizar a integração inicial dos circuitos de controle do **servomotor** e de interface com o **sensor de distância** com a **geração dos dados seriais** (trena digital).

> **ATENÇÃO:** a **movimentação do servomotor** deve iniciar na primeira posição espacial (000), conforme definido na seção 1.3.1. A, e percorrer sequencialmente até a última posição (111), voltando logo em seguida para a posição inicial (000). Esta movimentação será denominada **“movimentação vai”**. Outras formas de movimentação do servomotor poderiam ser implementadas, como por exemplo, a **“movimentação vai-e-volta”** onde o servomotor realiza inicialmente o movimento de ida (000 até 111) e, em seguida, o movimento de volta (111 até 000) e assim por diante.

---

¹ O módulo `exp3_sensor` **NÃO deve ser usado para sintetizar o circuito da experiência 3 para a placa FPGA**. Deve-se empregar somente o módulo interno da interface com o sensor ultrassônico, `interface_hcsr04`.

² Por exemplo, o ciclo básico de funcionamento do circuito do sistema de sonar envolve o posicionamento do servomotor, em seguida a medição de distância a objetos e posterior envio dos dados de ângulo e distância para a saída serial do sistema digital.

# 2. PARTE EXPERIMENTAL

## 2.1. Atividade 1 – Projeto e Verificação do Sistema de Sonar

Esta atividade visa desenvolver o projeto e a verificação do Sistema de Sonar usando as ferramentas apresentadas e usadas no Laboratório Digital. A qualidade da documentação do projeto é um ponto importante da avaliação do desempenho do grupo.

**a)** Desenvolva o **projeto do circuito** do Sistema de Sonar, conforme especificação apresentada na seção 1 da apostila. Siga as etapas de desenvolvimento, elaborando e documentando os projetos de cada um dos circuitos intermediários. Apresente as decisões de projeto e os detalhes do seu funcionamento. Acrescente na documentação **diagramas de projeto** (diagrama de blocos do fluxo de dados e diagrama de transição de estados para unidade de controle), **planos de teste e simulações** para cada componente.

> **DICA:** na documentação do projeto, escreva um parágrafo descrevendo o funcionamento do circuito, fornecendo a cada passo os componentes envolvidos e as ações tomadas pelos elementos.

**b)** Defina um **Plano de Teste** com a descrição dos casos de teste para a verificação de funcionamento do sistema de sonar como um todo.

**c)** Elabore o(s) *testbench(es)* necessários e execute a **verificação funcional** do projeto utilizando simulação dos casos de teste definidos para o sistema de sonar usando o ModelSim. Anote as figuras das formas de onda obtidas para mostrar o correto funcionamento dos módulos testados e anexe-as, de forma **legível**, no Planejamento.

> **DICA:** as **anotações** das formas de onda devem mostrar os principais eventos no funcionamento do circuito, como por exemplo, envio do sinal *Trigger* para início da medida de distância pelo sensor HC-SR04, início da transmissão de cada caractere serial, término de cada ciclo de medidas, posição do servomotor e reinício do ciclo da “movimentação vai”. Outros eventos relevantes podem ser indicados se o grupo julgar relevante.

**d)** Submeta junto com o Planejamento um arquivo zip (`exp5_modelsim_txbyy.zip`) contendo os códigos Verilog usados para simulação com o ModelSim (código fonte dos módulos, circuitos de teste e *testbenches*). Inclua **TODOS os testbenches** utilizados na refatoração e no projeto do sonar.

**e)** Responda a seguinte questão no Planejamento: **“Como o Sistema de Sonar de seu grupo irá se comportar se o sensor de distância não devolver o sinal echo em qualquer posição da varredura? Se o funcionamento for comprometido, como você sugere melhorar o projeto para evitar esse problema?”**.

## 2.2. Atividade 2 – Planejamento da Execução Experimental

Esta atividade experimental visa planejar como a parte experimental será executada na bancada do Laboratório Digital. **A qualidade deste plano também será considerada na avaliação do grupo.**

**f)** Elabore um **Plano de Execução Experimental** a ser seguido durante a execução das atividades experimentais na bancada remota. Mostre:

1. como serão realizados a montagem e os testes incrementais do Sistema de Sonar;
2. como cada componente de hardware deve ser energizado e que cuidados devem ser tomados ao fazer as conexões de alimentação de cada componente (ex.: tensão de alimentação).
3. quais são os circuitos de teste intermediários definidos;
4. como o funcionamento correto de cada módulo é validado;
5. quais testes devem ser aplicados para verificar o Sistema de Sonar e suas partes;
6. os principais sinais de depuração definidos pelo grupo e que podem ser monitorados durante os testes intermediários e a demonstração final do projeto. Mostre também as ferramentas selecionadas para a monitoração destes sinais e seus recursos e configurações.

> **DICA:** elabore uma tabela descrevendo cada sinal de depuração, sua função ou aplicação no monitoramento e na depuração do circuito, que recurso deve ser usado para isso e como ele deve ser monitorado.

**g)** Mostre no Planejamento a sequência de atividades planejadas pelo grupo para serem executadas na bancada do Laboratório Digital.

**h)** Como preparação para a síntese, execute a designação de sinais aos recursos da placa FPGA. Adote a designação mínima de pinos da Tabela 2 e complete-a com os pinos necessários da FPGA. Recomenda-se que o grupo acrescente sinais de depuração e documente-os no Planejamento.

**Tabela 2 – Designação mínima (incompleta) de pinos para o Sistema de Sonar.**

| sinal | pino DE0-CV | pino da FPGA |
|---|---|---|
| clock | CLOCK_50 | M9 |
| reset | chave SW0 | |
| ligar | chave SW1 | |
| trigger | GPIO_1_D1 | |
| echo | GPIO_1_D3 | |
| pwm | GPIO_0_D35 | |
| saida_serial | GPIO_0_D1 | |
| fim_posicao | GPIO_1_D35 | |

**i)** Submeta o arquivo QAR do projeto (`exp5_txbyy.qar`) junto com o Planejamento.

## 2.3. Atividade 3 – Procedimento Experimental na Bancada do Laboratório

Esta atividade experimental visa executar o Plano de Execução Experimental elaborado pelo grupo para testar o projeto do Sistema de Sonar na bancada do Laboratório Digital.

**j)** A cada etapa de testes, programe a placa FPGA e execute os testes planejados. Mostre para o professor o correto funcionamento de cada circuito de teste planejado e relate ocorrências experimentais.

**k)** Capture formas de onda dos principais sinais de depuração usando ferramentas do **Analog Discovery** e imagens de saídas em *displays* de 7 segmentos e LEDs para o Sistema de Sonar. Documente também as saídas observadas no software **Processing** (na interface gráfica e no console de mensagens).

**l)** Finalmente, teste o circuito (completo) do Sistema de Sonar.

**m)** Relate quaisquer ocorrências experimentais no Relato da experiência.

**n)** Realize uma demonstração de funcionamento do Sistema de Sonar ao professor.

**o)** Submeta o arquivo QAR final do projeto do sistema de sonar `exp5_final_txbyy.qar` junto com o Relatório.

## 2.4. Atividade 4 – Desafio

**p)** Uma atividade adicional será apresentada pelo professor. Execute-a e documente sua realização no Relato da experiência.

# 3. BIBLIOGRAFIA

- ALMEIDA, F.V. de; SATO, L.M.; MIDORIKAWA, E.T. *Tutorial para criação de circuitos digitais em Verilog no Quartus Prime 20.1*. Apostila de Laboratório Digital. Departamento de Engenharia de Computação e Sistemas Digitais, Escola Politécnica da USP. Edição de 2024.
- ALMEIDA, F.V. de; SATO, L.M.; MIDORIKAWA, E.T. *Tutorial para criação de circuitos digitais hierárquicos em VHDL no Quartus Prime 16.1*. Apostila de Laboratório Digital. Departamento de Engenharia de Computação e Sistemas Digitais, Escola Politécnica da USP. Edição de 2017.
- ALTERA / Intel. *DE0-CV User Manual*. 2015.
- ALTERA / Intel. *Quartus Prime Introduction Using Verilog Designs*. 2016.
- ALTERA / Intel. *Quartus Prime Introduction to Simulation of Verilog Designs*. 2016.
- Cytron Technologies. *HC-SR04 Product user’s manual*. May 2013.
- Electronic Industries Association. *Interface Between Data Terminal Equipment and Data Communication Equipment Employing Serial Date Interchange EIA-RS-232-C*, Washington, August 1969.
- HELD, G. *Understanding Data Communications*. 6th ed., New Riders, 1999.
- MIDORIKAWA, E.T. *Metodologia de Projeto com Dispositivos Programáveis*. Apostila de Laboratório Digital. PCS-EPUSP, 2016.
- PROCESSING. Site do programa Processing. http://processing.org. Acesso em 19/09/2026.
- Ricardo Menotti, Ricardo dos Santos Ferreira. *Introdução à Lógica Digital com Verilog: uma abordagem prática*. Kindle. 2023.
- WAKERLY, John F. *Digital Design Principles & Practices*. 5th edition, Prentice Hall, 2018.

# 4. MATERIAL DISPONÍVEL

- 1 placa com circuito integrado CP2102 (módulo de interface USB serial).
- 1 servomotor de posição Micro Servo 9g SG90 ou equivalente.
- 1 sensor ultrassônico HC-SR04 com VCC=3,3V.
- 1 protoboard ou outra plataforma de montagem.
- 1 ou mais objetos para medida de distância.
- 1 régua ou outra ferramenta de medida de distância.

# 5. EQUIPAMENTOS NECESSÁRIOS

- 1 computador com interface serial (ou 1 cabo USB serial) e software de comunicação.
- 1 computador com software Intel Quartus Prime e ModelSim.
- 1 dispositivo Analog Discovery da Digilent.
- 1 placa de desenvolvimento FPGA DE0-CV com a FPGA Cyclone V 5CEBA4F23C7N.

# Histórico de Revisões

- E.T.M./2015 – versão inicial.
- E.T.M./2019 – revisão e atualização.
- E.T.M./2020 – revisão e reorganização da experiência para acesso remoto.
- E.T.M./2021 – revisão.
- E.T.M./2022 – revisão e atualização para o ensino presencial.
- E.T.M./2023 – revisão.
- E.T.M./2024 – revisão e adaptação para Verilog.
- E.T.M./2025 – revisão.
- E.T.M. & A.V.S.N./2026 – revisão.
