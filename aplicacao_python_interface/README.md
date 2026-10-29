# Fábula TEA + — interface Python

Aplicação desktop Tkinter para mostrar no monitor o personagem recebido da FPGA. O circuito não foi alterado.

## Execução

Requer Python 3.10+ com Tkinter. Nesta pasta:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python app.py
```

Windows: use `python` em vez de `python3` e `.venv\Scripts\activate` para ativar o ambiente. No PyCharm, abra esta pasta, selecione o interpretador do ambiente e execute `app.py`. Se Tkinter estiver ausente no Linux, instale `python3-tk` pela distribuição.

Instale os requisitos para disponibilizar Pillow (tratamento das imagens). O modo de demonstração funciona mesmo sem pyserial: execute `python3 app.py`, escolha história e personagem e clique em **Mostrar personagem**. F11 alterna tela cheia; Esc sai dela.

## Conexão com a FPGA

1. Conecte `saida_serial` ao RX de um adaptador USB–UART compatível com os níveis elétricos da placa e interligue os GNDs. Consulte a pinagem do circuito.
2. Selecione ou digite a porta (`COM3`, `/dev/ttyUSB0`, etc.) e clique em **Conectar**. Feche outros programas que usem a porta. No Linux, a conta precisa ter acesso ao dispositivo serial.
3. Acione os personagens na placa. Cada mensagem completa apresenta o cartão, atualiza o histórico e salva um registro CSV.
4. Desconecte antes de trocar a porta. A demonstração fica desabilitada enquanto houver conexão.

A aplicação somente recebe dados; não envia comandos. A entrada serial da ESP8266 no circuito é um caminho distinto.

## Protocolo

Confirmado em `../Semana1/fluxo_dados.v`, `tx_serial_7E1.v` e `codificadorPersonagem.v`:

- **115200 baud, 7 bits, paridade par, 1 stop bit (7E1)**; sem controle de fluxo.
- ASCII `H<história>,P<personagem>` seguido por LF (`0x0A`). Exemplo: `H0,P2\n` = seis bytes hexadecimais `48 30 2C 50 32 0A`.
- História `0..3`; personagem `0..5`, correspondendo aos bits `000001` até `100000` e posições do servo de 15° até 165°.
- Aceita também CRLF. Reagrupa leituras parciais e processa mensagens consecutivas. Informa quadros inválidos no status; quadros acima de 64 bytes são descartados até LF.

O protocolo não informa fase, início/fim da rodada, acerto ou erro. Contagem, recontagem e relembrar usam o mesmo formato. Todas as ocorrências são apresentadas, inclusive repetições; o histórico não representa automaticamente a sequência original do jogo.

## Cartões e imagens

Edite `historias.json` e reinicie a aplicação. Cada história tem exatamente seis personagens em ordem de índice. O mapeamento adotado segue a ordem das páginas e a leitura da esquerda para a direita, de cima para baixo. O PDF não define IDs: confirme essa associação com os cartões físicos antes da integração.

| História | Tema | Personagens 0 → 5 |
| --- | --- | --- |
| 0 | Aventura pirata | Navio pirata, Mapa do tesouro, Ilha, Tesouro, Pirata, Tempestade |
| 1 | Reino encantado | Cavaleiro, Dragão, Castelo, Floresta, Tesouro, Princesa |
| 2 | Viagem espacial | Foguete, Astronauta, Planeta, Alienígena, Base espacial, Pistola espacial |
| 3 | Minha rotina | Acordar, Tomar café, Tomar banho, Escovar os dentes, Vestir-se, Ir à escola |

As imagens originais estão em `assets/pdf_originais/`; a procedência e reprodução da extração estão em `assets/ORIGEM.md`. A galeria permite selecionar cartões na demonstração e destaca o personagem apresentado. As imagens se ajustam ao espaço ao redimensionar a janela. Histórico e galeria ficam em abas; conexão e demonstração ficam na lateral.

Para usar imagem própria, coloque um PNG em `assets/` e configure o personagem:

```json
{"nome": "Princesa", "simbolo": "♕", "imagem": "assets/princesa.png"}
```

Sem imagem, aparece um cartão com símbolo e índice. A disponibilidade de símbolos depende da fonte instalada. PNGs são reduzidos mantendo a proporção. Imagem ausente ou inválida usa o cartão de reserva e informa o erro no status.

## Registros e implementação

Cada sessão cria `registros/sessao_<data_hora>.csv`, UTF-8, com data/hora e fuso, origem (Serial ou Demonstração), IDs e nomes. A escrita é descarregada a cada evento. **Limpar histórico visual** não apaga os CSVs. A tabela mantém até 200 eventos; o arquivo mantém toda a sessão.

`protocol.py` valida e reagrupa os bytes. `app.py` consulta a porta sem bloqueio a cada 30 ms no loop Tkinter, apresenta os cartões e persiste os eventos. Não requer navegador ou servidor.

## Testes

```bash
python3 -m unittest discover -s tests -v
```

Cobrem os 24 códigos possíveis, fragmentação, quadros consecutivos, CRLF, repetições, ruído, entradas inválidas e recuperação após excesso de bytes. Em bancada, compare a interface com HEX0/HEX1, teste todos os cartões e a desconexão do cabo. A validação física requer placa e adaptador e não foi realizada automaticamente.

A área principal prioriza a imagem do cartão. Use **Mostrar cartões e histórico** no rodapé para abrir a galeria e os registros; recolha esse painel para ampliar novamente o personagem. F11 aproveita a tela inteira.

## Executável para Windows

A geração é feita **no Windows**, com Python 3.10+ instalado (incluindo pip e Tcl/Tk). O computador que apenas executa o `.exe` não precisa de Python. O driver do adaptador serial continua necessário.

1. Copie esta pasta completa para o Windows, incluindo `assets`, `tools`, `tests` e os arquivos de requisitos.
2. Dê duplo clique em **`gerar_windows.cmd`**. Na primeira execução, é necessário acesso à internet para baixar as dependências.
3. Aguarde os testes e a geração. Se houver erro, a janela permanece aberta com o diagnóstico.
4. O resultado fica em **`dist\FabulaTEA.exe`**. Distribua esse arquivo; o catálogo e as 24 imagens já estão incluídos. Nenhuma janela de terminal acompanha o aplicativo.

O script usa um ambiente separado, `.venv-build`, e PyInstaller no modo de arquivo único. Os originais do PDF e a imagem do catálogo não são incluídos no executável.

### Atualizar a partir do código

Após alterar o código, imagens ou catálogo, execute **`gerar_windows.cmd` novamente** no Windows. Feche o aplicativo antigo e substitua `FabulaTEA.exe` pelo novo arquivo de `dist`. A geração recompõe o pacote completo com o conteúdo atual. Não é uma atualização automática pela internet.

No executável, os CSVs ficam em **`%LOCALAPPDATA%\FabulaTEA\registros`**. Para abrir essa pasta, cole o caminho na barra do Explorador de Arquivos. Os registros permanecem ao substituir o executável; sessões anteriores executadas com `python app.py` continuam em `registros/` dentro do projeto e não são migradas automaticamente.

Para alterar somente nomes ou associações sem recompilar, coloque uma cópia de `historias.json` ao lado do `.exe` e edite-a. Para imagens próprias, coloque também a pasta `assets` com os arquivos referenciados ao lado do executável. A aplicação usa essas imagens quando existem e procura as demais no pacote interno. Reinicie após as alterações. Um catálogo externo tem prioridade sobre o catálogo embutido: atualize ou remova essa cópia se quiser usar o catálogo de uma nova compilação.

A preparação foi verificada em Linux; a criação e o teste final do `.exe` precisam ser feitos no Windows. Após gerar, abra o executável fora da pasta do código, teste uma imagem de cada história, verifique o CSV e depois faça a recepção serial com a placa conectada.
