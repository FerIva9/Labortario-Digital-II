# Fábula TEA + — interface Python

Aplicação desktop Tkinter para mostrar no monitor o personagem recebido da FPGA. Compatível com o protocolo da Semana3.

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

Confirmado em `../Semana3/fluxo_dados.v`, `tx_serial_7E1.v` e `codificadorPersonagem.v`:

- **115200 baud, 7 bits, paridade par, 1 stop bit (7E1)**; sem controle de fluxo.
- ASCII `H<história>,P<personagem>` seguido por LF (`0x0A`). Exemplo: `H0,P2\n` = seis bytes hexadecimais `48 30 2C 50 32 0A`.
- História `0..3`; personagem `0..5`, correspondendo aos bits `000001` até `100000` e posições do servo de 15° até 165°.
- Aceita também CRLF. Reagrupa leituras parciais e processa mensagens consecutivas. Informa quadros inválidos no status; quadros acima de 64 bytes são descartados até LF.

Na recontagem, cada `H<história>,P<personagem>\n` é seguido por `R1\n` (acerto) ou `R0\n` (erro). O resultado corresponde à comparação daquela jogada, não ao resultado final da história. A interface mostra o cartão imediatamente e associa o próximo resultado à apresentação serial mais recente, uma única vez. Mensagens inválidas ou desconexão desfazem a associação pendente; resultados sem apresentação são ignorados com aviso. Repetições válidas são jogadas distintas. O protocolo não tem identificadores de jogada, portanto uma perda de quadros completos não pode ser detectada com segurança.

Apresentações sem resultado continuam disponíveis, mas não entram nas taxas de acerto. O protocolo não informa início/fim de rodada; a aplicação não calcula histórias concluídas nem duração de rodadas.

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

## Apresentação somente do personagem

Clique em **Tela cheia · personagem** ou pressione **F11** para ocupar a tela com apenas a imagem, em fundo branco e com proporção preservada. Controles, nomes e histórico ficam ocultos. **Esc** (ou F11 novamente) retorna à interface completa. A conexão serial continua ativa e cada mensagem válida atualiza o personagem em tela cheia; os registros continuam sendo salvos. Antes da primeira mensagem, a tela de apresentação fica em branco. Para usar essa mudança no executável Windows, gere novamente com `gerar_windows.cmd`.

## Tamanho da janela e escala do Windows

A janela inicial se ajusta ao tamanho da tela, usa Segoe UI no Windows e permite reduzir a janela. Os controles laterais e o painel principal oferecem rolagem vertical quando necessário; a galeria distribui os cartões em várias linhas conforme a largura disponível. Cabeçalho, rodapé e nomes longos se reorganizam com quebra de texto. A tabela tem rolagem horizontal e vertical. O modo somente personagem continua ocupando a tela inteira.

`windows.manifest` declara a escala de DPI do sistema para o executável; ao rodar o código diretamente, `windows_display.py` configura isso antes de criar a janela. Não é necessário reduzir a escala do Windows para usar o aplicativo. A escala é a do sistema no início da execução; mudanças de escala durante o uso podem exigir reiniciar o aplicativo. Inclua `ui_layout.py`, `windows_display.py` e `windows.manifest` ao copiar o código para recompilar no Windows.

Verificação gráfica opcional: `python tools/check_layout.py`. O script abre janelas temporárias para conferir três tamanhos (1240×900, 1024×650 e 800×600) em quatro escalas de fontes, incluindo galeria, limites dos controles, redimensionamento e apresentação de novos personagens em tela cheia. Esses testes foram executados em Linux; a conferência visual final no Windows continua necessária.

## Jogadores e acompanhamento

1. Na tela inicial, escolha um jogador na lista ou clique em **+ Novo jogador**, preencha o nome/apelido e clique em **Salvar**. Use a busca para localizar perfis. Os perfis possuem identificadores próprios, inclusive quando os nomes coincidem.
2. Confira o perfil selecionado e clique em **Iniciar sessão** para abrir a interface do jogo. Cadastrar ou selecionar um jogador não inicia a sessão automaticamente. O nome ativo e o horário de início aparecem na lateral. Sessões são agrupamentos manuais da aplicação, não rodadas detectadas no circuito.
3. Clique em **Ver desempenho do jogador** para consultar a taxa global, acertos/erros, sessão atual e evolução por tema, data e sessão. A taxa é `acertos / jogadas com R0 ou R1`; demonstrações e apresentações sem resultado ficam fora do cálculo. As datas preservam o horário local e fuso registrados.
4. Use **Exportar histórico do jogador (CSV)** para obter todas as apresentações reais do perfil, com sessão, horário, história, personagem e resultado (`0`, `1` ou vazio quando não recebido).

Use **Encerrar sessão / trocar jogador** para voltar à tela inicial. A aplicação desconecta a placa, preserva o histórico salvo e limpa os cartões e registros visuais da sessão anterior. Escolha um perfil e clique em **Iniciar sessão** para outro atendimento. A tela inicial é uma seleção de perfis locais, sem senha. Perfis e jogadas ficam em `registros/jogadores.sqlite3`, ou `%LOCALAPPDATA%\FabulaTEA\registros\jogadores.sqlite3` no executável Windows. Faça backup desse arquivo com o aplicativo fechado. Os dados ficam locais, sem envio a um servidor. Prefira apelidos quando apropriado.

**Limpar histórico visual** não remove os dados do jogador. Os CSVs antigos de apresentações são preservados; como não contêm jogador nem resultado, não são importados automaticamente nas estatísticas. Os novos resultados persistem no SQLite e na exportação por jogador; os CSVs de sessão anteriores continuam como registros de apresentações. As estatísticas descrevem o desempenho no jogo e não representam uma avaliação clínica.

Para distribuir as alterações no Windows, gere novamente o executável conforme as instruções acima; o módulo `player_store.py` também deve acompanhar o código fonte.

### Gerenciar perfis

Selecione um jogador e abra **Opções do perfil** para **Renomear** ou **Excluir perfil…**. O formulário de nome aparece somente durante o cadastro ou edição; **Cancelar** o recolhe. Renomear mantém o identificador, as sessões e todas as estatísticas do jogador. Nomes iguais recebem um identificador curto na lista para distinguir os perfis.

Excluir exige confirmação e remove o perfil, suas sessões e jogadas do banco local, sem afetar outros jogadores. A exclusão não pode ser desfeita. Arquivos CSV já exportados e os antigos registros independentes de apresentações não são apagados. O gerenciamento fica na tela inicial, fora de uma sessão ativa.
