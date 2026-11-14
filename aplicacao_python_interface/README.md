# Fábula TEA + — interface Python

Veja [ARQUITETURA.md](ARQUITETURA.md) para o caminho dos dados, a distribuição
do executável com Firebase e a diferença de protocolo da Semana4: essa versão
da FPGA envia apresentações, mas ainda não transmite os resultados R0/R1.

### Ubuntu

Em uma sessão gráfica do Ubuntu, instale `python3-tk` e `python3-venv`:

```bash
sudo apt update
sudo apt install python3-tk python3-venv
cd aplicacao_python_interface
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
python3 app.py
```

Para o Firebase automático, transfira `firebase_defaults.json` e
`.firebase-private/` por meio privado. Um clone sem esses arquivos abre a
interface em modo local; também é possível configurar o acesso pelo menu Nuvem.
Sem cofre seguro no Ubuntu, a autorização preparada usa o pacote privado
criptografado. A porta serial exige permissão do usuário (normalmente o grupo
`dialout`, após sair e entrar na sessão). O workflow `Interface Ubuntu` testa
a lógica e a interface em tela virtual sem credenciais Firebase.

### Diagnóstico do executável

No PowerShell, `Start-Process` permite aguardar o aplicativo sem console:

```powershell
$check = Start-Process -FilePath .\dist\FabulaTEA.exe -ArgumentList '--check-installation', 'diagnostico.txt' -Wait -PassThru
Get-Content -Encoding UTF8 diagnostico.txt
$check.ExitCode
```

Esse comando testa Tkinter e imagens e realiza um ensaio Firebase real usando
apenas dados fictícios de uma instalação temporária, removidos ao final.
Código de saída zero indica sucesso. Não acessa o histórico local de jogadores.
O executável com autorização incorporada fica fora do Git, assim como os arquivos
privados originais. Distribua-o por um canal privado.

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

Use **Encerrar sessão / trocar jogador** para voltar à tela inicial. A aplicação desconecta a placa, preserva o histórico salvo e limpa os cartões e registros visuais da sessão anterior. Escolha um perfil e clique em **Iniciar sessão** para outro atendimento. A tela inicial é uma seleção de perfis locais, sem senha. Perfis e jogadas ficam em `registros/jogadores.sqlite3`, ou `%LOCALAPPDATA%\FabulaTEA\registros\jogadores.sqlite3` no executável Windows. Faça backup desse arquivo com o aplicativo fechado. Os dados são mantidos localmente; o envio opcional ao Firebase depende da conexão pelo menu Nuvem. Prefira apelidos quando apropriado.

**Limpar histórico visual** não remove os dados do jogador. Os CSVs antigos de apresentações são preservados; como não contêm jogador nem resultado, não são importados automaticamente nas estatísticas. Os novos resultados persistem no SQLite e na exportação por jogador; os CSVs de sessão anteriores continuam como registros de apresentações. As estatísticas descrevem o desempenho no jogo e não representam uma avaliação clínica.

Para distribuir as alterações no Windows, gere novamente o executável conforme as instruções acima; o módulo `player_store.py` também deve acompanhar o código fonte.

### Gerenciar perfis

Selecione um jogador e abra **Opções do perfil** para **Renomear** ou **Excluir perfil…**. O formulário de nome aparece somente durante o cadastro ou edição; **Cancelar** o recolhe. Renomear mantém o identificador, as sessões e todas as estatísticas do jogador. Nomes iguais recebem um identificador curto na lista para distinguir os perfis.

Excluir exige confirmação e remove o perfil, suas sessões e jogadas do banco local, sem afetar outros jogadores. A exclusão não pode ser desfeita. Arquivos CSV já exportados e os antigos registros independentes de apresentações não são apagados. O gerenciamento fica na tela inicial, fora de uma sessão ativa.

## Sincronização automática e padrão Firebase (branch iot-estatisticas)

Os dados reais de conexão ficam em `firebase_config.json` e `firebase_defaults.json`, ignorados pelo Git. O executável inclui o padrão privado fornecido durante a geração. Um clone público sozinho não recebe autorização.

A pasta privada já preparada no Linux é `aplicacao_python_interface/.firebase-private/`. Ela é oculta por começar com ponto; no gerenciador de arquivos do Linux, pressione **Ctrl+H** para mostrá-la. Contém `access.enc` (autorização criptografada) e `access.key` (chave para abrir a autorização). Não publique nenhum dos dois, mesmo criptografados.

No computador Windows que vai gerar o executável, deixe os arquivos nesta estrutura:

```text
aplicacao_python_interface/
├── gerar_windows.cmd
├── firebase_defaults.json
├── .firebase-private/
│   ├── access.enc
│   └── access.key
├── app.py
└── tools/
```

`firebase_config.json` é uma configuração local opcional e também fica fora do Git. Transfira a pasta privada e o padrão por um meio privado, preservando os nomes; não crie uma segunda pasta `.firebase-private` dentro da primeira. Após gerar, somente `dist/FabulaTEA.exe` é necessário no computador de destino. Não publique esse executável em commits, Releases ou anexos públicos.

O `.gitignore` protege esses caminhos, os arquivos de acesso e os executáveis na pasta da aplicação. Isso não impede `git add -f`, uploads manuais ou o envio de cópias renomeadas. Antes de publicar, confira `git status --short` e `git diff --cached --name-only`. Arquivos já publicados exigem remoção do histórico e revogação do acesso; apenas adicionar ao `.gitignore` não corrige exposição anterior.

Para preparar o acesso sem redigitar credenciais:

1. Instale os requisitos e execute `python tools/prepare_private_access.py` na pasta da aplicação. Informe email e senha apenas nessa preparação. O programa valida o login e a autorização sem enviar dados clínicos; a senha não é gravada.
2. O programa cria `.firebase-private/access.enc` (configuração e refresh token criptografados) e `.firebase-private/access.key` (chave privada), e ativa a sincronização automática. O cofre do sistema também é usado quando disponível.
3. Transfira **por meio privado** a pasta `.firebase-private` completa e `firebase_defaults.json` para a pasta da aplicação clonada no Windows. Não use o Git para isso.
4. Execute `gerar_windows.cmd`. O gerador exige e valida a pasta privada e incorpora seu conteúdo no executável. Depois, copie **somente `dist/FabulaTEA.exe`** para outro computador: ele conecta automaticamente, sem pasta privada externa ou login. A aplicação tenta guardar a autorização renovada no cofre do usuário Windows; sem cofre, mantém uma cópia local criptografada nos dados do usuário.
5. Para trocar o acesso, use o menu Nuvem; para atualizar o pacote portátil com outra conta, execute novamente a preparação. Desmarcar a opção de lembrar remove o acesso local correspondente e desativa sua retomada automática. Isso não remove a autorização incorporada ao executável: para invalidar cópias já distribuídas, revogue as sessões da conta no Firebase ou retire a autorização do operador; para substituir o acesso embutido, gere um novo executável.

**Proteção e limite:** quem possuir o arquivo criptografado e a chave poderá usar a conta. A criptografia não protege contra alguém que obtenha ambos. A chave fica fora do código e do Git, mas **é incorporada ao executável junto com a autorização**. O executável permite recuperar o acesso e deve ser tratado como uma credencial privada: não publique o `.exe`. A pasta privada é necessária somente no computador de geração. Um clone público exige transferir esse pacote por meio privado antes de gerar o executável. Internet, regras, cotas e autorização válida continuam necessárias.

A sincronização começa automaticamente e os registros permanecem no SQLite quando a rede falha. O pacote não transporta o histórico de pacientes: cada instalação mantém seu banco e identificador próprios. Cotas e pausas do plano gratuito permanecem iguais. Tokens podem ser revogados; nesse caso, conecte novamente ou refaça a preparação. Referência: [sessões Firebase](https://firebase.google.com/docs/auth/admin/manage-sessions).

Os nomes locais dos jogadores não são enviados; a nuvem recebe perfis codificados, sessões, jogadas e resumos, incluindo exclusões. O fluxo é local → nuvem e não baixa ou combina dados de outras instalações. A primeira autenticação também publica o histórico pendente existente.

O uso permanece **estritamente gratuito**: mantenha o projeto no Spark sem conta de faturamento vinculada. O programa não verifica o plano do projeto. O intervalo padrão é 60 segundos; HTTP 429/RESOURCE_EXHAUSTED pausa o envio com a fila preservada. Não há habilitação de cobrança ou migração de plano pela aplicação.

Os testes automatizados usam transporte e cofre substituídos, sem acessar sua conta real. O roteiro `python tools/check_cloud_integration.py --run-live` cria somente dados fictícios em uma instalação temporária; sem essa opção, não faz requisições. A validação do executável atualizado deve ser concluída no Windows.
