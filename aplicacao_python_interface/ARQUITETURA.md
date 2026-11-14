# Organização e integração

As pastas `Experiencia*` e `Semana1` a `Semana4` contêm as etapas do hardware.
`arquivosESP8266` reúne o código do microcontrolador. A interface desktop fica
em `aplicacao_python_interface` e recebe diretamente a UART da FPGA.

## Caminho dos dados

1. `Semana4/fabula_tea.v` integra controle, fluxo de dados, teclado, servo e displays.
2. `Semana4/fluxo_dados.v` transmite `H<história>,P<personagem>\n` por UART 7E1,
   115200 baud. `protocol.py` reagrupa e valida as mensagens no computador.
3. `app.py` apresenta os cartões de `historias.json` e `assets/`.
4. `player_store.py` salva jogadores, sessões e apresentações no SQLite;
   `cloud_outbox.py` mantém a fila persistente na mesma transação.
5. `cloud_firebase.py` autentica via Firebase Authentication e envia snapshots
   ao Cloud Firestore por HTTPS, em segundo plano.
6. `cloud_portable.py` restaura a autorização inicial incorporada ao executável;
   `cloud_credentials.py` usa o cofre do sistema quando disponível.
7. `runtime_paths.py` separa recursos do pacote e dados persistentes.

## Diferença entre Semana3 e Semana4

A Semana3 inclui mensagens de resultado `R0\n` e `R1\n`. A Semana4 atual
transmite apenas apresentações: as entradas D6 e D7 do mux de transmissão
estão em zero e não há transmissão de resultado na unidade de controle.
Assim, a interface é compatível com os cartões da Semana4, mas não consegue
inferir acertos/erros. Esses resultados permanecem ausentes no banco e ficam
fora do denominador da taxa. Para medir desempenho com a Semana4, será
necessário acrescentar o envio de resultado ao firmware e validá-lo em bancada.

## Firebase e executável

`firebase_defaults.json` define projeto, Web API Key, UID e intervalo. Não
contém senha. O acesso privado existente deve ser validado antes de compilar:

```powershell
.\.venv-build\Scripts\python.exe tools/prepare_private_access.py --check
```

Ensaio completo com autorização salva, instalação temporária e dados fictícios
(realiza operações reais no Firestore e remove os documentos ao terminar):

```powershell
.\.venv-build\Scripts\python.exe tools/check_cloud_integration.py --run-live --saved-access
```

Sem `--run-live`, nenhuma requisição é feita. Sem `--saved-access`, o ensaio
continua solicitando login interativamente.

Execute `gerar_windows.cmd` para gerar `dist/FabulaTEA.exe`. O pacote incorpora
configuração, autorização, catálogo e imagens. O computador de destino precisa
de Windows compatível, internet para sincronizar e driver USB/UART para a FPGA;
não precisa instalar Python ou copiar arquivos de configuração.

Cada instalação cria seu SQLite em `%LOCALAPPDATA%\FabulaTEA\registros` e
seu próprio identificador. O envio é local → nuvem: jogadores de outro
computador não são baixados. As rotas remotas são:

```text
operators/{UID}/installations/{INSTALLATION_ID}/players/{PLAYER_ID}
operators/{UID}/installations/{INSTALLATION_ID}/sessions/{SESSION_ID}
operators/{UID}/installations/{INSTALLATION_ID}/moves/{MOVE_ID}
```

O executável contém uma autorização recuperável e deve ser distribuído somente
a pessoas autorizadas. A senha não é incorporada. Revogar a sessão ou desabilitar
o operador impede acessos futuros; não existe garantia de conexão sem rede ou
com autorização revogada. Não inclua uma chave administrativa no aplicativo.
