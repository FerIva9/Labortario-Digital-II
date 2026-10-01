# PCS3645 — Laboratório de Projeto de Sistemas Digitais II
## Modificação do Sistema de Sonar (2026)
### Versão 2026 — v1.1

> Documento convertido para Markdown a partir da apostila **“Modificação do Sistema de Sonar (2026)”**.
> O objetivo desta versão é facilitar a leitura por ferramentas como Codex.
> Figuras gráficas foram substituídas por descrições textuais e, quando possível, por interfaces/códigos equivalentes em texto.

---

# Objetivos — Resumo

Após a conclusão desta experiência, os seguintes tópicos devem ser conhecidos pelos alunos:

- Aplicação de sensores, atuadores e comunicação serial para compor sistemas digitais;
- Desenvolvimento de circuito para varredura e detecção de objetos;
- Desenvolvimento de máquina de estados para controle de um sistema estrutural;
- Realização de testes de unidade e testes de integração de circuitos digitais;
- Projeto de circuitos em FPGA.

Esta experiência tem por objetivo desenvolver uma modificação do Sistema de Sonar da experiência anterior adicionando um novo modo de funcionamento a ele.

O Sistema de Sonar é um circuito que realiza a varredura e a detecção de objetos próximos com a utilização de um sensor ultrassônico de distância e de um servomotor.

Ele também possui interfaces de comunicação serial para se comunicar com dispositivos externos para apresentar dados e receber comandos.

O Sistema de Sonar Modificado será desenvolvido e testado com base na placa de desenvolvimento FPGA DE0-CV e usando a infraestrutura disponível na bancada do Laboratório Digital.

---

# 1. Especificação do Projeto

O projeto da experiência está relacionado com a adição de novos modos de funcionamento do sistema de Sonar desenvolvido anteriormente.

O funcionamento do sistema de Sonar deve ser modificado com base em caracteres recebidos de um terminal ou dispositivo serial através de um sinal de entrada.

Depois do acionamento do sinal de `reset`, o circuito deve iniciar no modo normal de funcionamento (`modo=0`), implantado na Experiência 5 e denominado **modo de localização**.

Quando o circuito receber um caractere `C1`, o Sonar deve mudar para o novo modo de funcionamento (`modo=1`), em que uma funcionalidade adicional deve ser implementada.

O recebimento de um caractere `C2`, com `C2 ≠ C1`, deve fazer o sistema voltar ao modo normal.

Exemplo genérico apresentado na apostila:

- `C1 = 'N'` → entra no modo Novo;
- `C2 = 'A'` → volta ao modo Antigo.

## 1.1. Novo Modo de Funcionamento

O circuito do Sonar deve iniciar no modo normal de localização (`modo=0`) com:

- realização da varredura;
- movimentação do conjunto do servomotor e sensor;
- medida de distância;
- transmissão de dados;
- espera de 2 segundos;

tudo conforme já implantado na experiência anterior.

Quando o circuito recebe o caractere minúsculo:

```text
'a'
```

pela porta serial, ele deve mudar para o **modo de atenção (`modo=1`)**.

No modo de atenção:

- a movimentação do servomotor é interrompida;
- as medidas de distância continuam sendo realizadas;
- os dados continuam sendo transmitidos pela porta serial;
- a transmissão/medição continua ocorrendo a cada 2 segundos.

Quando o circuito receber o caractere minúsculo:

```text
'v'
```

o Sonar deve voltar ao funcionamento normal.

Ao voltar:

- o servomotor volta a se movimentar;
- as medidas de distância continuam;
- a transmissão continua;
- a varredura deve ser retomada **a partir da posição em que estava quando foi interrompida**.

O Sonar deve responder **somente** aos caracteres:

```text
'a'
'v'
```

ambos minúsculos.

Quaisquer outros caracteres devem ser ignorados.

Para implementar essa funcionalidade, é acrescentado ao Sistema de Sonar um novo sinal de entrada:

```text
entrada_serial
```

Esse sinal deve ser transmitido serialmente pelo computador para a placa FPGA.

Portanto, nessa comunicação:

- o computador transmite serialmente o dado de mudança de modo;
- o sistema de Sonar recebe esse dado serialmente;
- o circuito decide se deve alterar seu modo de funcionamento.

---

## Figura 1 — Interface modificada do Sistema de Sonar

A interface básica sugerida para o circuito é:

```verilog
module sonar2 (
    input  clock,
    input  reset,
    input  ligar,
    input  entrada_serial,
    input  echo,
    output trigger,
    output pwm,
    output saida_serial,
    output fim_posicao
);
```

Conexões externas representadas na figura:

```text
                         +----------------------------+
ligar ----------------->|                            |----> saida_serial
entrada_serial -------->|   Sistema de Sonar         |----> fim_posicao
reset ----------------->|   Modificado               |
clock ----------------->|                            |
                         +----------------------------+
                              |            |
                              | pwm        | trigger
                              v            v
                         +----------+   +-----------+
                         |  Servo   |   | HC-SR04   |
                         |  motor   |   | Sensor    |
                         +----------+   +-----------+
                                           |
                                           | echo
                                           +--------> sistema
```

Para depuração, deve ser acrescentada uma nova saída:

```text
db_modo
```

que deve indicar o modo de funcionamento do circuito.

Outros sinais de depuração também devem ser acrescentados à interface básica e documentados no Planejamento do grupo.

Sinais de depuração já existentes na versão original do Sistema de Sonar devem ser:

- mantidos; ou
- adaptados.

Recomenda-se utilizar a técnica de **multiplexação de recursos**, apresentada na seção 1.2-C, para aprimorar o uso dos sinais de depuração do projeto.

---

# 1.2. Considerações para o Desenvolvimento do Projeto

## A) Adição do circuito de recepção serial

É fornecido no e-Disciplinas um circuito de recepção serial assíncrona denominado:

```text
rx_serial_7E1
```

Arquivo:

```text
rx_serial_7E1.v
```

Características:

- comunicação serial assíncrona;
- formato `7E1`;
- taxa de `115200 bauds`.

Esse módulo deve ser utilizado como **componente interno do Fluxo de Dados** do Sistema de Sonar Modificado.

Também é fornecido um testbench do componente para facilitar:

- o entendimento do funcionamento;
- a aplicação do módulo no projeto da experiência.

### Figura 2 — Módulo para recepção serial

A interface apresentada na apostila é:

```verilog
module rx_serial_7E1 (
    input        clock,
    input        reset,
    input        RX,
    output       pronto,
    output [6:0] dados_ascii,
    output       paridade,
    output       paridade_par,
    output       db_clock,
    output       db_tick,
    output [3:0] db_estado
);
```

---

## B) Restrição de Projeto

A modificação do novo modo de funcionamento deve ser implementada **alterando a máquina de estados da Unidade de Controle**.

Cada modo deve estar associado a **uma sequência de estados diferente**.

Não devem ser introduzidos blocos lógicos sobre sinais de controle dentro do Fluxo de Dados.

Exemplo explicitamente proibido pela apostila:

> Não incluir uma porta lógica para inibir o sinal de controle `pwm` do servomotor quando o circuito estiver no modo de atenção.

Em outras palavras, a mudança de comportamento entre os modos deve ocorrer **pela Unidade de Controle / máquina de estados**, e não por "gambiarras" combinacionais adicionadas no caminho dos sinais de controle do Fluxo de Dados.

O diagrama de transição de estados da Unidade de Controle deve ser documentado de forma detalhada.

Esse diagrama deve deixar claro:

- quais estados pertencem ao modo de localização;
- quais estados pertencem ao modo de atenção;
- como ocorre a transição entre os modos;
- em que condições essas transições acontecem.

---

## C) Apresentação de Sinais de Depuração em LEDs e Displays — DESAFIO

O mapeamento de sinais de depuração em LEDs e displays de 7 segmentos disponíveis na placa FPGA é um recurso importante para verificar o funcionamento do projeto sintetizado na bancada.

Recursos disponíveis na DE0-CV:

- 10 LEDs;
- 6 displays de 7 segmentos.

Como esses recursos são limitados, pode ser necessário utilizar **multiplexação de recursos** para aumentar a quantidade de sinais que podem ser monitorados.

### Multiplexação dos displays

A Figura 3 apresenta conceitualmente um multiplexador `4x1`.

Cada entrada do multiplexador possui 24 bits, correspondentes aos 6 displays de 7 segmentos.

Estrutura conceitual:

```text
sinais00 [23:0] ----\
sinais01 [23:0] -----\
sinais10 [23:0] ------> MUX 4x1 ----> 24 bits ----> 6 displays de 7 segmentos
sinais11 [23:0] -----/
                     ^
                     |
                  sel_mux [1:0]
```

Com esse arranjo, os 6 displays podem apresentar até:

```text
4 conjuntos × 6 displays = 24 valores distintos de display
```

O sinal:

```text
sel_mux
```

seleciona qual conjunto de sinais de depuração será mostrado.

Durante a depuração, o responsável pelos testes pode alterar `sel_mux` através de entradas de depuração para selecionar o conjunto desejado.

### Tabela 1 — Exemplo de sinais de depuração exibidos nos displays

| `sel_mux` | componente | HEX5 | HEX4 | HEX3 | HEX2 | HEX1 | HEX0 |
|---|---|---|---|---|---|---|---|
| `00` | servomotor + HC-SR04 | posição do servo | `estado_hcsr04` | a definir | `distancia2` | `distancia1` | `distancia0` |
| `01` | uart | `estado_tx` | `DADO_TX1` | `DADO_TX0` | `estado_rx` | `DADO_RX1` | `DADO_RX0` |
| `10` | tx dados sonar | `estado_tx_sonar` | `contagem_selmux` | `dado_sonar1` | `dado_sonar2` | a definir | a definir |
| `11` | sonar | `estado_sonar` | a definir | a definir | `angulo2` | `angulo1` | `angulo0` |

O mesmo conceito pode ser aplicado aos 10 LEDs da placa FPGA DE0-CV.

O sinal de seleção da multiplexação pode ser compartilhado entre:

- LEDs;
- displays.

A definição dos sinais mapeados em LEDs deve ser apresentada no Planejamento.

---

## Figura 4 — Interface com multiplexação de displays

Com a adição dos sinais de seleção da multiplexação e dos sinais de depuração, a apostila sugere conceitualmente a seguinte organização:

```text
                 +--------------------------------------+
                 | Displays de 7 segmentos e LEDs       |
                 | da placa FPGA                        |
                 +--------------------------------------+
                       ^                  ^
                       | ledR             | hex
                       |                  |
                 +----------------------------------+
ligar ---------->|                                  |----> saida_serial
entrada_serial ->| Sistema de Sonar Modificado      |
reset ---------->|                                  |
clock ---------->|                                  |
                 +----------------------------------+
                         |       |        |
                         | pwm   | trigger| echo
                         v       v        ^
                    +---------+       +---------+
                    | Servo   |       | HC-SR04 |
                    | motor   |       | sensor  |
                    +---------+       +---------+
```

Se necessário, o número de sinais monitorados nos displays pode ser aumentado usando um multiplexador:

```text
8x1
```

em vez do multiplexador `4x1`.

---

# 2. Parte Experimental

## 2.1. Atividade 1 — Projeto e Verificação do Sistema de Sonar Modificado

Esta atividade visa desenvolver o projeto e a verificação do Sistema de Sonar Modificado usando as ferramentas apresentadas e utilizadas no Laboratório Digital.

A qualidade da documentação do projeto é um ponto importante da avaliação do desempenho do grupo.

### a) Projeto do circuito

Desenvolver o projeto do circuito conforme a especificação da seção 1.

Devem ser realizadas as etapas de desenvolvimento e elaborados os projetos dos circuitos intermediários.

A documentação deve apresentar:

- decisões de projeto;
- detalhes do funcionamento;
- diagrama de blocos do Fluxo de Dados;
- diagrama de transição de estados da Unidade de Controle.

### b) Plano de Teste

Definir um Plano de Teste contendo:

- descrição dos casos de teste;
- verificação do funcionamento do sistema;
- testbench ou testbenches necessários.

### c) Verificação funcional no ModelSim

Executar a verificação funcional do projeto através de simulação dos casos de teste definidos.

Ferramenta:

```text
ModelSim
```

Devem ser registradas figuras das formas de onda obtidas para mostrar o correto funcionamento dos módulos testados.

Essas figuras devem ser anexadas ao Planejamento.

#### Dica para as formas de onda

As anotações devem mostrar os principais eventos do funcionamento do circuito, por exemplo:

- envio do sinal `trigger` para início da medida de distância do HC-SR04;
- início da transmissão de cada caractere serial;
- término de cada ciclo de medidas;
- outros eventos relevantes do sistema.

### d) Arquivo ZIP da simulação

Submeter junto com o Planejamento:

```text
exp6_modelsim_txbyy.zip
```

O ZIP deve conter:

- testbenches;
- códigos-fonte dos módulos;
- circuitos de teste;
- demais códigos Verilog utilizados para simulação no ModelSim.

---

# 2.2. Atividade 2 — Planejamento da Execução Experimental

Esta atividade visa planejar como a parte experimental será executada na bancada do Laboratório Digital.

A qualidade desse plano será considerada na avaliação do grupo.

## e) Plano de Execução Experimental

Elaborar um Plano de Execução Experimental a ser seguido na bancada remota.

O plano deve mostrar:

1. como serão realizadas a montagem e os testes incrementais do Sistema de Sonar Modificado;

2. diagramas indicando:
   - como cada componente de hardware deve ser energizado;
   - cuidados com as conexões de alimentação;
   - tensão de alimentação;
   - conexões entre os diversos componentes;
   - servomotor;
   - protoboard;
   - sensor de distância;
   - módulo serial;
   - GPIOs da placa FPGA;

3. quais circuitos de teste intermediários foram definidos;

4. como o funcionamento correto de cada módulo será validado;

5. quais testes devem ser aplicados para verificar:
   - o Sistema de Sonar Modificado completo;
   - suas partes individuais;

6. os principais sinais de depuração definidos pelo grupo que podem ser monitorados:
   - durante os testes;
   - durante a demonstração final.

Também deve ser mostrado:

- quais ferramentas serão utilizadas para monitoramento;
- como essas ferramentas devem ser configuradas.

### Dica

Elaborar uma tabela descrevendo cada sinal de depuração e sua:

- função;
- aplicação;
- utilidade no processo de monitoração e depuração.

## f) Sequência de atividades

Mostrar no Planejamento a sequência de atividades programadas pelo grupo para execução na bancada do Laboratório Digital.

## g) Designação de sinais para síntese

Como preparação para a síntese, executar a designação de sinais aos recursos da placa FPGA.

Deve ser adotada, no mínimo, a designação da Tabela 2.

Recomenda-se acrescentar sinais de depuração, preferencialmente seguindo a técnica de multiplexação de recursos da seção 1.2-C.

Esses sinais adicionais devem ser documentados no Planejamento.

### Tabela 2 — Designação mínima de pinos para o Sistema de Sonar

| sinal | pino DE0-CV | pino da FPGA |
|---|---|---|
| `clock` | `CLOCK_50` | `M9` |
| `reset` | chave `SW0` | — |
| `ligar` | chave `SW1` | — |
| `entrada_serial` | `GPIO_0_D3` | — |
| `trigger` | `GPIO_1_D1` | — |
| `echo` | `GPIO_1_D3` | — |
| `pwm` | `GPIO_0_D35` | — |
| `saida_serial` | `GPIO_0_D1` | — |
| `fim_posicao` | `GPIO_1_D35` | — |

## h) Arquivo QAR do projeto

Submeter junto com o Planejamento:

```text
exp6_txbyy.qar
```

---

# 2.3. Atividade 3 — Procedimento Experimental na Bancada do Laboratório

Esta atividade visa executar o Plano de Execução Experimental elaborado pelo grupo para testar o projeto do Sistema de Sonar na bancada do Laboratório Digital.

## i) Testes incrementais

A cada etapa de testes:

1. programar a placa FPGA;
2. executar os testes incrementais planejados;
3. mostrar ao professor o funcionamento correto de cada circuito de teste;
4. relatar ocorrências experimentais.

## j) Captura de sinais e evidências

Capturar formas de onda dos principais sinais de depuração utilizando ferramentas do:

```text
Analog Discovery
```

Também devem ser registradas:

- imagens das saídas nos displays de 7 segmentos;
- imagens dos LEDs;
- saídas observadas no software Processing;
- interface gráfica do Processing;
- console de mensagens do Processing.

## k) Teste final

Testar o circuito completo do Sistema de Sonar Modificado.

## l) Relato

Relatar quaisquer ocorrências experimentais no Relato da experiência.

## m) Demonstração

Realizar uma demonstração de funcionamento do Sistema de Sonar Modificado ao professor.

## n) Arquivo QAR final

Submeter junto com o Relato:

```text
exp6_final_txbyy.qar
```

---

# 2.4. Atividade 4 — Desafio

## o) Atividade adicional

Uma atividade adicional será apresentada pelo professor.

Ela deve ser:

- executada;
- documentada no Relato da experiência.

---

# 3. Bibliografia

- ALMEIDA, F. V. de; SATO, L. M.; MIDORIKAWA, E. T. *Tutorial para criação de circuitos digitais em Verilog no Quartus Prime 20.1*. Apostila de Laboratório Digital. Departamento de Engenharia de Computação e Sistemas Digitais, Escola Politécnica da USP. Edição de 2024.

- ALMEIDA, F. V. de; SATO, L. M.; MIDORIKAWA, E. T. *Tutorial para criação de circuitos digitais hierárquicos em VHDL no Quartus Prime 16.1*. Apostila de Laboratório Digital. Departamento de Engenharia de Computação e Sistemas Digitais, Escola Politécnica da USP. Edição de 2017.

- ALTERA / Intel. *DE0-CV User Manual*. 2015.

- ALTERA / Intel. *Quartus Prime Introduction Using Verilog Designs*. 2016.

- ALTERA / Intel. *Quartus Prime Introduction to Simulation of Verilog Designs*. 2016.

- Cytron Technologies. *HC-SR04 Product user’s manual*. May 2013.

- Electronic Industries Association. *Interface Between Data Terminal Equipment and Data Communication Equipment Employing Serial Date Interchange EIA-RS-232-C*. Washington, August 1969.

- HELD, G. *Understanding Data Communications*. 6th ed., New Riders, 1999.

- MIDORIKAWA, E. T. *Metodologia de Projeto com Dispositivos Programáveis*. Apostila de Laboratório Digital. PCS-EPUSP, 2016.

- PROCESSING. Site do programa Processing. `http://processing.org`. Acesso em 12/09/2025.

- MENOTTI, Ricardo; FERREIRA, Ricardo dos Santos. *Introdução à Lógica Digital com Verilog: uma abordagem prática*. Kindle, 2023.

- WAKERLY, John F. *Digital Design Principles & Practices*. 5th edition, Prentice Hall, 2018.

---

# 4. Material Disponível

- 1 placa com circuito integrado CP2102 — módulo de interface USB serial;
- 1 servomotor;
- 1 sensor ultrassônico HC-SR04 com `VCC = 3,3 V`;
- 1 protoboard ou outra plataforma de montagem;
- 1 objeto para medida de distância;
- 1 régua ou outra ferramenta de medida.

---

# 5. Equipamentos Necessários

- 1 computador com interface serial ou 1 cabo USB serial e software de comunicação;
- 1 computador com Intel Quartus Prime e ModelSim;
- 1 dispositivo Analog Discovery da Digilent;
- 1 placa de desenvolvimento FPGA DE0-CV com dispositivo:

```text
Cyclone V 5CEBA4F23C7N
```

---

# Histórico de Revisões

- E.T.M./2015 — versão inicial.
- E.T.M./2019 — revisão e atualização.
- E.T.M./2020 — revisão e reorganização da experiência para acesso remoto.
- E.T.M./2021 — revisão.
- E.T.M./2022 — revisão e atualização para o ensino presencial.
- E.T.M./2023 — revisão.
- E.T.M./2024 — revisão e adaptação para Verilog.
- E.T.M./2025 — revisão.
- E.T.M. & A.V.S.N./2026 — revisão.

---

# Resumo técnico para implementação

## Comportamento global esperado

### Após `reset`

```text
modo = 0
```

O sistema inicia no modo de localização.

### Modo de localização (`modo = 0`)

O sistema deve:

1. mover o servomotor;
2. realizar medida com HC-SR04;
3. transmitir os dados;
4. esperar 2 segundos;
5. continuar a varredura.

Se o receptor serial indicar que foi recebido:

```text
'a'
```

o sistema deve passar ao modo de atenção.

### Modo de atenção (`modo = 1`)

O sistema deve:

1. manter o servomotor parado na posição atual;
2. continuar realizando medidas com HC-SR04;
3. continuar transmitindo os dados;
4. repetir esse processo a cada 2 segundos.

Se for recebido:

```text
'v'
```

o sistema retorna ao modo de localização e retoma a varredura a partir da posição em que estava.

### Caracteres inválidos

Qualquer caractere diferente de:

```text
'a'
'v'
```

deve ser ignorado.

---

# Restrições arquiteturais importantes

1. O receptor `rx_serial_7E1` deve fazer parte do **Fluxo de Dados**.

2. A mudança entre modo de localização e modo de atenção deve ser implementada pela **máquina de estados da Unidade de Controle**.

3. Não deve ser adicionada lógica combinacional artificial para bloquear sinais de controle no Fluxo de Dados.

4. Cada modo deve possuir uma sequência própria de estados na Unidade de Controle.

5. O projeto deve possuir o sinal de depuração:

```text
db_modo
```

6. O diagrama de estados deve identificar claramente os estados associados a cada modo.

7. A posição do servomotor deve ser preservada durante o modo de atenção para que a varredura possa continuar do ponto onde parou.

---

# Arquivos e entregas citados na especificação

## Arquivos fornecidos

```text
rx_serial_7E1.v
```

e seu respectivo testbench.

## Entrega de simulação

```text
exp6_modelsim_txbyy.zip
```

## Entrega do projeto para o Planejamento

```text
exp6_txbyy.qar
```

## Entrega final

```text
exp6_final_txbyy.qar
```

---

# Checklist para o grupo

## Projeto

- [ ] Integrar `rx_serial_7E1` ao Fluxo de Dados.
- [ ] Detectar `'a'`.
- [ ] Detectar `'v'`.
- [ ] Ignorar caracteres inválidos.
- [ ] Criar/atualizar `modo`.
- [ ] Alterar a máquina de estados da UC.
- [ ] Criar sequência de estados do modo de localização.
- [ ] Criar sequência de estados do modo de atenção.
- [ ] Manter a posição do servo no modo de atenção.
- [ ] Retomar a varredura na mesma posição.
- [ ] Manter medições no modo de atenção.
- [ ] Manter transmissão serial no modo de atenção.
- [ ] Manter intervalo de 2 s.
- [ ] Adicionar `db_modo`.
- [ ] Definir demais sinais de depuração.
- [ ] Implementar multiplexação de displays/LEDs, se utilizada.

## Documentação

- [ ] Diagrama de blocos do Fluxo de Dados.
- [ ] Diagrama de estados da Unidade de Controle.
- [ ] Identificação dos estados de cada modo.
- [ ] Decisões de projeto.
- [ ] Plano de Teste.
- [ ] Testbenches.
- [ ] Formas de onda anotadas.
- [ ] Plano de Execução Experimental.
- [ ] Diagramas de montagem.
- [ ] Tensões de alimentação.
- [ ] Conexões de GPIO.
- [ ] Circuitos intermediários de teste.
- [ ] Tabela dos sinais de depuração.
- [ ] Sequência das atividades de bancada.
- [ ] Designação de pinos.
- [ ] Relato das ocorrências experimentais.

## Bancada

- [ ] Testar circuitos intermediários.
- [ ] Programar FPGA a cada etapa.
- [ ] Monitorar sinais com Analog Discovery.
- [ ] Verificar LEDs.
- [ ] Verificar displays.
- [ ] Verificar Processing.
- [ ] Testar o sistema completo.
- [ ] Demonstrar ao professor.
