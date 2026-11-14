> **Versão atual: sincronização bidirecional.** Após configurar o projeto, siga [SINCRONIZACAO_COMPARTILHADA.md](SINCRONIZACAO_COMPARTILHADA.md) e publique as regras desta versão.

# IoT: sincronizar as estatísticas com o Firebase

Guia da branch `iot-estatisticas`, revisado em **13/11/2026**. A integração está preparada no código. A criação do projeto, a publicação das regras e a habilitação da conta são feitas pelo responsável no Console. Os testes com o banco real ficam para depois dessa configuração.

## 1. Arquitetura adotada

```text
FPGA ── UART 115200/7E1 ──> aplicação Python
                              │
                              ├── SQLite: perfis, sessões, jogadas e resultados
                              ├── fila persistente de sincronização
                              └── HTTPS + Firebase Authentication ──> Cloud Firestore
```

O computador funciona como gateway IoT: recebe os eventos do circuito e usa sua conexão com a internet para publicar as estatísticas. Não é necessário alterar o Verilog, conectar Wi-Fi à FPGA, alterar a ESP8266 ou adicionar MQTT para essa etapa.

O SQLite continua sendo a fonte de dados da aplicação. O envio à nuvem é opcional e acontece em uma thread separada, que utiliza sua própria conexão SQLite. Sem conexão, o jogo e as estatísticas locais continuam funcionando; a fila mantém o que falta transmitir. As falhas transitórias de rede durante uma conexão autenticada têm novas tentativas com espera crescente. Se houver falha transitória de rede no início, a reconexão é automática; erros permanentes de conta/configuração exigem correção pelo operador.

Esta etapa implementa **envio da instalação local para a nuvem**. A interface ainda consulta suas estatísticas locais. Download/restauração de dados, fusão de perfis de computadores diferentes e um painel web são etapas posteriores. O Firebase Console já permite inspecionar os documentos recebidos.

## 2. Política obrigatória: uso estritamente gratuito

A configuração admitida para este projeto é **plano Spark, sem conta de Cloud Billing vinculada ao projeto**, usando **Cloud Firestore Standard `(default)`** e **Authentication por email/senha**. O projeto não deve ser migrado para Blaze. Se uma opção exigir faturamento, interrompa essa configuração e mantenha o funcionamento local.

### Como manter custo zero

1. No Firebase Console, confira que o projeto aparece como **Spark** antes de conectar.
2. No Google Cloud Console, confira que o projeto não está vinculado a uma conta de faturamento. Ter uma conta Google com cartão cadastrado é diferente de vincular Cloud Billing a este projeto.
3. Não vincule créditos promocionais nem uma conta de teste de faturamento: esse vínculo pode mudar o projeto automaticamente para Blaze.
4. Use somente os dois serviços previstos neste roteiro. Não habilite Cloud Functions, Cloud Run, Storage de arquivos, backups gerenciados, PITR ou exclusões por TTL como parte desta implementação gratuita. Os CSVs, imagens e backups locais continuam no computador.
5. Mantenha as regras restritivas publicadas e acompanhe a aba **Usage**. Leituras feitas pelo Console e operações de outras instalações também usam recursos do projeto.

O Spark limita o uso dos serviços às suas cotas; atingir uma cota pode interromper operações remotas. Não se deve tratar Blaze com alertas de orçamento como alternativa para este requisito: ele é um plano com cobrança por uso. A aplicação não consulta o plano de faturamento nem impede que um administrador o altere no Console; a condição de custo zero depende de manter o projeto no Spark sem vínculo de faturamento. Fonte: [planos do Firebase e vínculo com Cloud Billing](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans).

### Limites relevantes do Firestore Standard

| Recurso | Cota gratuita | Efeito no aplicativo |
| --- | --- | --- |
| Dados armazenados | 1 GiB total | O histórico remoto não pode crescer indefinidamente. Documentos e índices ocupam espaço. |
| Leituras | 50.000/dia | Incluem consultas e leituras necessárias à autorização; são compartilhadas pelo projeto. |
| Escritas | 20.000/dia | Cada documento criado ou atualizado conta; um lote não equivale a uma única escrita. |
| Exclusões | 20.000/dia | A remoção de um perfil pode incluir muitas jogadas e sessões. |
| Transferência de saída | 10 GiB/mês | Importa principalmente para futuras consultas e exportações remotas. |
| Bancos com cota gratuita | Um por projeto | Este código utiliza `(default)`. |

As cotas diárias reiniciam aproximadamente à meia-noite do Pacífico, não à meia-noite de Brasília. A cota mensal de transferência segue seu período próprio. Armazenamento não se renova diariamente: se ficar cheio, será necessário reduzir os dados remotos ou mudar a estratégia de publicação para continuar gratuitamente. Fontes: [cotas](https://firebase.google.com/docs/firestore/quotas) e [contabilização do uso](https://firebase.google.com/docs/firestore/pricing).

### Capacidade aproximada com o modelo atual

Uma apresentação altera três documentos: jogada, resumo da sessão e resumo do jogador. Seu resultado pode atualizar os mesmos três. Se esses dois momentos forem transmitidos separadamente, são até **seis escritas por jogada avaliada**, antes de considerar reenvios, criação de perfis/sessões e migração inicial. A fila agrupa várias atualizações do mesmo documento, o que pode reduzir esse consumo.

| Exemplo de uso | Jogadas avaliadas/dia | Estimativa conservadora dessas escritas |
| --- | --- | --- |
| 10 jogadores × 50 jogadas | 500 | Até cerca de 3.000/dia. |
| 20 jogadores × 50 jogadas | 1.000 | Até cerca de 6.000/dia. |
| 50 jogadores × 100 jogadas | 5.000 | Até cerca de 30.000/dia; pode ultrapassar a cota. |

Esses exemplos são estimativas, não um limite de jogadores garantido. As cotas são do projeto inteiro: vários computadores, regras, testes, consultas e eventuais reenvios precisam ser considerados. A primeira sincronização de um histórico grande também pode atingir a cota e precisar ser concluída ao longo de mais de um período.

Para o protótipo com poucos atendimentos, não há necessidade de trocar de banco ou retirar recursos de estatística. O principal compromisso é aceitar que a **sincronização possa ficar temporariamente indisponível** enquanto a coleta local continua. Em uso intenso ou histórico acumulado grande, uma evolução possível é publicar somente resumos por jogador/sessão e manter as jogadas detalhadas no SQLite/CSV. Essa opção reduziria armazenamento e operações, mas exigiria uma alteração explícita no código e limitaria análises remotas de jogadas individuais; não foi ativada automaticamente.

### Comportamento da aplicação para economizar cota

- O intervalo padrão de verificação periódica é **60 segundos**. Novas pendências acordam o trabalhador antes desse prazo, com um breve agrupamento. O valor no JSON funciona como verificação de segurança, não como atraso obrigatório para sessões e resultados.
- Os documentos utilizam IDs estáveis e snapshots completos, sem incrementar contadores a cada reenvio.
- Não há listener em tempo real: consultas incrementais verificam alterações remotas a cada 60 segundos, mesmo sem pendências locais.
- **HTTP 429 ou indicação RESOURCE_EXHAUSTED preserva a fila** e aguarda 15 minutos entre tentativas automáticas. O jogo continua coletando localmente.
- Confira Usage, aguarde o limite voltar a permitir operações e use **Nuvem → Configurar / conectar…** para retomar. A aplicação não consegue distinguir todas as causas de limite; armazenamento cheio, por exemplo, exige liberar espaço ou mudar a estratégia, e não apenas esperar um dia.
- A pausa também pode ocorrer por um limite transitório de requisições. Esse comportamento conservador evita insistir no serviço quando ele solicita redução de uso.

Agrupar documentos em lotes ou aumentar o intervalo não elimina a contagem por documento. O código não impõe uma cota global entre computadores e não mede todo o consumo do projeto. O limite de cobrança é mantido pela configuração Spark; a fila resolve a continuidade da coleta diante de uma interrupção do envio.

## 3. Conta do responsável e perfis dos jogadores

Há duas identidades diferentes:

- **Responsável/operador:** conta autenticada no Firebase, com email, senha e UID. Controla o acesso à nuvem.
- **Jogador:** perfil compartilhado entre as aplicações do mesmo operador, com identificador próprio. Não precisa de email ou senha do Firebase.

O código usa Firebase ID tokens via REST para que as Security Rules controlem o acesso. Não é necessário baixar uma chave privada de service account nem embutir credenciais administrativas no executável. A API key identifica o projeto; a autorização depende da conta e das regras. Referências: [Firestore REST e autorização](https://firebase.google.com/docs/firestore/use-rest-api), [Auth REST](https://firebase.google.com/docs/reference/rest/auth) e [API keys](https://firebase.google.com/docs/projects/api-keys).

O perfil remoto contém `player_id` e o nome ou apelido cadastrado no campo `label`, além das estatísticas. Sessões e jogadas referenciam o ID do jogador; o painel resolve o nome usando jogador e instalação, inclusive quando há nomes iguais. Renomear atualiza `label` sem alterar IDs ou o histórico. Nomes e desempenhos ficam acessíveis aos computadores autorizados do mesmo operador; o pacote de acesso deve continuar privado.

## 4. Criar o projeto Firebase

1. Abra o [Firebase Console](https://console.firebase.google.com/) com sua conta Google.
2. Selecione **Criar projeto / Add project**. Use um projeto exclusivo para o protótipo, por exemplo `fabula-tea-iot` se o ID estiver disponível.
3. Anote o **Project ID**, que é diferente do nome de exibição e do número do projeto.
4. Google Analytics é opcional e não é usado por esta integração; pode ficar desabilitado.
5. Mantenha o plano **Spark**, sem vincular uma conta de faturamento. Não é necessário habilitar Functions, Hosting, Storage ou um servidor pago para o fluxo preparado.

Os nomes dos grupos de menu podem variar conforme o idioma/versão do Console. Os produtos a localizar são **Firestore Database** e **Authentication**.

## 5. Criar o Firestore

1. Abra **Firestore Database** e clique em **Criar banco / Create database**.
2. Escolha **Standard edition** quando houver seleção de edição, com modo nativo do Firestore. Não use a opção de compatibilidade MongoDB.
3. Utilize o banco **`(default)`**, que é o utilizado pelo código e pela cota gratuita do primeiro banco.
4. Selecione o modo de **produção** para começar com acesso bloqueado.
5. Escolha uma região adequada. Para uma bancada no Brasil, `southamerica-east1` (São Paulo), se disponível, é uma opção próxima. A região do banco não pode ser alterada depois de criado; confirme a escolha antes de concluir. Fonte: [localizações do Firestore](https://firebase.google.com/docs/firestore/locations).
6. Conclua a criação. As coleções de jogadores, sessões e jogadas serão criadas pelo próprio envio; não é preciso cadastrar esses documentos manualmente.

Se o Console exigir faturamento para uma opção selecionada, revise se foi escolhido o primeiro banco `(default)` na edição Standard e se o projeto continua no plano pretendido. Não habilite faturamento para contornar essa tela: isso foge ao requisito de uso estritamente gratuito.

## 6. Habilitar Authentication e cadastrar o responsável

1. Abra **Authentication → Get started**.
2. Em **Sign-in method / Método de login**, habilite **Email/Password** e salve. A opção de link por email não é necessária.
3. Na aba **Users / Usuários**, clique em **Add user / Adicionar usuário**.
4. Cadastre um email acessível ao responsável e uma senha de acordo com a política do projeto.
5. Copie o **UID** da linha do usuário. Guarde esse valor para a configuração; ele não é o email nem o ID de um jogador.

A aplicação não cadastra contas do Firebase. A criação de outros operadores deve ser feita pelo responsável no Console. Não ative login anônimo para este roteiro.

## 7. Autorizar o operador no Firestore

O UID autenticado precisa também estar autorizado no banco. Isso impede que uma conta criada fora da aplicação obtenha acesso apenas por conhecer a API key.

1. Volte ao Firestore, na aba **Data / Dados**.
2. Crie a coleção **`operators`**.
3. Use como ID do documento **exatamente o UID** copiado de Authentication.
4. Adicione o campo **`enabled`**, do tipo **boolean**, com valor **`true`**. Não use a string `"true"`.
5. Salve.

Exemplo de estrutura administrativa:

```text
operators
└── UID_DO_RESPONSAVEL
    └── enabled: true     (boolean)
```

Esse documento é criado pelo Console administrativo. O aplicativo pode verificar a autorização, mas as regras não permitem que ele se habilite sozinho. Para suspender um operador, altere `enabled` para `false`; as próximas requisições de dados serão recusadas.

## 8. Publicar as Security Rules

1. Abra **Firestore → Rules / Regras**.
2. Abra no projeto o arquivo **`aplicacao_python_interface/firebase/firestore.rules`**.
3. Substitua o conteúdo do editor do Console pelo conteúdo completo desse arquivo.
4. Clique em **Publish / Publicar** e aguarde a confirmação. Se houver erro de sintaxe, preserve a mensagem para verificarmos antes de conectar dados.
5. Confira se não ficou uma regra temporária de teste como `allow read, write: if true`.

As regras fornecidas restringem o acesso ao UID autenticado, exigem `operators/UID.enabled == true` e validam a estrutura dos documentos. As coleções permitidas são players, sessions e moves, dentro da instalação do operador. As demais rotas ficam bloqueadas. O responsável administrativo pode publicar regras pelo Console; a aplicação não recebe essa permissão.

Referência: [iniciar com Security Rules](https://firebase.google.com/docs/firestore/security/get-started). A validação dessas regras no projeto real e os testes de autorização serão feitos na etapa de integração, depois da configuração.

## 9. Obter a Web API Key

1. Abra a engrenagem do projeto → **Project settings / Configurações do projeto → General / Geral**.
2. Anote o **Project ID** e a **Web API Key**.
3. Se a chave não aparecer, use **Your apps / Seus aplicativos → Add app → Web (`</>`)** para registrar um aplicativo com um nome como `FabulaTEADesktop`. Não habilite Hosting. Copie apenas `apiKey` e `projectId` do bloco de configuração mostrado. Não é necessário incorporar o SDK JavaScript ao Python.
4. Use uma chave destinada somente às APIs Firebase necessárias. Em **Google Cloud Console → APIs & Services → Credentials**, confira as restrições da chave e se Identity Toolkit API e Token Service API estão permitidas. Uma restrição por HTTP referrer de site não é adequada ao cliente desktop REST.
5. A criação do Firestore normalmente habilita sua API. Se aparecer erro de serviço desabilitado, confira **Cloud Firestore API**, **Identity Toolkit API** e **Token Service API** no projeto correto.

Não é necessário usar Database URL, measurementId, client secret, arquivo de service account ou chave privada. A URL do Firestore é montada com o Project ID.

## 10. Padrão distribuído e sincronização automática

O menu Nuvem mostra uma marca em **Sincronização automática** e mantém essa
preferência entre execuções. Ativá-la também habilita lembrar o acesso. Ao pausar
e reativar, a interface aguarda a requisição anterior terminar e reinicia o
trabalhador, sem exigir nova ativação. **Reconectar / sincronizar agora** também
solicita o envio das pendências. As regras já publicadas continuam válidas.

Cada 500 ms, a interface verifica a fila e acorda o trabalhador se houver dados.
O envio inclui sessões vazias e atualizações posteriores de apresentações com
resultados R1/R0, preservando os IDs. A fila é confirmada por revisão; uma
atualização feita durante o envio não é apagada pela confirmação da versão antiga.
Falhas transitórias usam novas tentativas; a pausa manual e falhas permanentes
preservam a fila. Se o aplicativo fechar antes da confirmação, o envio retoma na
próxima abertura com autorização válida e sincronização habilitada.

No Ubuntu, a execução continua sendo `python3 app.py`, após ativar o ambiente e
instalar os requisitos, `python3-tk`, `python3-venv` e `ca-certificates`. Sem cofre
seguro, um novo login lembrado cria automaticamente `.firebase-private/` com
refresh token criptografado; não exige que o pacote já exista. A senha não é
armazenada. O arquivo privado deve permanecer acessível somente às pessoas
autorizadas. Também é possível transferir o pacote preparado e o padrão por meio
privado. O mesmo transporte HTTPS e a mesma fila são usados nos dois sistemas.

Os dados reais de conexão ficam em `firebase_config.json` e `firebase_defaults.json`, ignorados pelo Git. O executável inclui o padrão privado fornecido durante a geração. Um clone público sozinho não recebe autorização.

Para preparar o acesso sem redigitar credenciais:

1. Instale os requisitos e execute `python tools/prepare_private_access.py` na pasta da aplicação. Informe email e senha apenas nessa preparação. O programa valida o login e a autorização sem enviar dados clínicos; a senha não é gravada.
2. O programa cria `.firebase-private/access.enc` (configuração e refresh token criptografados) e `.firebase-private/access.key` (chave privada), e ativa a sincronização automática. O cofre do sistema também é usado quando disponível.
3. Transfira **por meio privado** a pasta `.firebase-private` completa e `firebase_defaults.json` para a pasta da aplicação clonada no Windows. Não use o Git para isso.
4. Execute `gerar_windows.cmd`. O gerador exige e valida a pasta privada e incorpora seu conteúdo no executável. Depois, copie **somente `dist/FabulaTEA.exe`** para outro computador: ele conecta automaticamente, sem pasta privada externa ou login. A aplicação tenta guardar a autorização renovada no cofre do usuário Windows; sem cofre, mantém uma cópia local criptografada nos dados do usuário.
5. Para trocar o acesso, use o menu Nuvem; para atualizar o pacote portátil com outra conta, execute novamente a preparação. Desmarcar a opção de lembrar remove o acesso local correspondente e desativa sua retomada automática. Isso não remove a autorização incorporada ao executável: para invalidar cópias já distribuídas, revogue as sessões da conta no Firebase ou retire a autorização do operador; para substituir o acesso embutido, gere um novo executável.

**Proteção e limite:** quem possuir o arquivo criptografado e a chave poderá usar a conta. A criptografia não protege contra alguém que obtenha ambos. A chave fica fora do código e do Git, mas **é incorporada ao executável junto com a autorização**. O executável permite recuperar o acesso e deve ser tratado como uma credencial privada: não publique o `.exe`. A pasta privada é necessária somente no computador de geração. Um clone público exige transferir esse pacote por meio privado antes de gerar o executável. Internet, regras, cotas e autorização válida continuam necessárias.

A sincronização começa automaticamente e os registros permanecem no SQLite quando a rede falha. O pacote não transporta o histórico de pacientes: cada instalação mantém seu banco e identificador próprios. Cotas e pausas do plano gratuito permanecem iguais. Tokens podem ser revogados; nesse caso, conecte novamente ou refaça a preparação. Referência: [sessões Firebase](https://firebase.google.com/docs/auth/admin/manage-sessions).

## Painel de acompanhamento entre computadores

A tela inicial e o painel usam a base compartilhada do operador e recebem alterações pela sincronização automática. Para conferir diretamente o servidor, use **Acompanhamento → Consultar nuvem agora**. Publicação das regras, migração do histórico, exclusões e limites estão no [guia compartilhado](SINCRONIZACAO_COMPARTILHADA.md).

## 11. Base compartilhada, migração e funcionamento offline

As coleções atuais ficam em `operators/{UID}/installations/shared/{players|sessions|moves}/{ID_global}`, com `schema_version=2` e `updated_at` do servidor. A lista inicial, sessões e histórico são sincronizados automaticamente nos dois sentidos. A estrutura por instalação antiga é preservada como origem de migração.

O procedimento de atualização, a recuperação de históricos com fila antiga vazia, a cópia de segurança, as regras para conflitos/exclusões e os comandos de teste estão em [SINCRONIZACAO_COMPARTILHADA.md](SINCRONIZACAO_COMPARTILHADA.md). Esse guia substitui as orientações antigas de envio somente local → nuvem.

Sem as novas regras publicadas, o aplicativo continua coletando offline e avisa a recusa do servidor. Atualize todos os computadores; versões antigas não participam da troca contínua da base compartilhada.

## 14. Diagnóstico de problemas

| Sintoma | Conferir |
| --- | --- |
| Email ou senha inválidos | Usuário criado em Authentication do projeto correto; senha digitada localmente. |
| Conta não corresponde ao UID | Usar o UID da conta autenticada e o mesmo documento operators/UID. |
| Operação de login não habilitada | Ativar Email/Password em Authentication. |
| Acesso negado / HTTP 403 | Regras publicadas; enabled boolean true; UID; API habilitada e configuração da chave. |
| HTTP 404 antes do envio | Project ID, criação do Firestore `(default)` e documento operators/UID. |
| Falha HTTPS | Acesso à internet, certificados, proxy e horário do computador. A validação TLS permanece habilitada. |
| HTTP 429 / RESOURCE_EXHAUSTED | Fila preservada, nova tentativa automática em 15 minutos. Consultar Usage; não habilitar faturamento. |
| Fila não zera | Consultar Detalhes; corrigir erro permanente e reconectar. Pausa preserva os dados. |
| Outro projeto/operador bloqueado | Retomada automática encontrou destino diferente do vínculo local. Configure e autentique explicitamente o novo destino pelo menu. |
| Aparece código em vez do nome | Publique as regras atuais, atualize a aplicação na origem, aguarde a sincronização dos perfis e consulte novamente. O nome não pode ser deduzido de um código antigo sem a origem. |

## 15. Arquivos alterados ou incluídos

| Arquivo | Finalidade |
| --- | --- |
| player_store.py | Enfileira alterações e exclusões na transação dos dados. |
| cloud_outbox.py | Migração, snapshots, identidade da instalação, fila e confirmações. |
| cloud_firebase.py | HTTPS REST, sessão restaurada, renovação de token e reconexão automática. |
| cloud_credentials.py | Integração com o cofre seguro do sistema. |
| cloud_portable.py | Alternativa criptografada ao cofre e bootstrap privado do executável. |
| cloud_preferences.py | Persistência local de pausa, email e preferência de lembrar. |
| firebase_defaults.json | Padrão privado ignorado pelo Git, incluído no executável durante a geração. |
| app.py | Menu Nuvem, configuração e conexão do responsável, estado e pausa. |
| runtime_paths.py | Caminho externo para firebase_config.json. |
| firebase/firestore.rules | Regras para publicar no Console. |
| firebase_config.example.json | Modelo sem senha ou token. |
| tests/test_cloud_sync.py | Verificações locais com transporte substituído. |
| tools/check_cloud_integration.py | Ensaio remoto preparado para a etapa posterior à configuração. |

As verificações no Windows incluem testes gráficos e ensaios no Firebase real com dados fictícios, usando o trabalhador automático e resultados R1/R0. O `.exe` possui diagnóstico isolado para repetir a verificação. Os testes locais cobrem persistência sem cofre, envio após alterações, novas tentativas e reinício. O workflow Ubuntu executa a lógica e a interface sem credenciais reais; a verificação nativa de Ubuntu com Firebase e a bancada física da FPGA permanecem verificações separadas.

### Acesso negado antes do primeiro envio

A aplicação agora identifica a etapa da falha nos detalhes da sincronização:

- **Login Firebase — HTTP 403:** conferir restrições da Web API Key e Identity Toolkit API. Uma chave restrita a um site por HTTP referrer não atende ao cliente desktop. A mensagem também identifica SERVICE_DISABLED/API_KEY_SERVICE_BLOCKED quando o serviço retorna esse motivo estruturado.
- **Autorização do operador: operators/UID — HTTP 403:** o login já retornou o UID esperado; conferir no Firestore `(default)` o documento `operators/UID`, o campo `enabled` boolean true e a publicação das regras no mesmo projeto. A leitura de um documento inexistente também pode ser negada pela condição de autorização, em vez de retornar 404.
- **Envio de documentos ao Firestore — HTTP 403:** a autenticação e a leitura do operador passaram; conferir as regras das subcoleções e a validação dos campos enviados.

Abra **Nuvem → Detalhes da sincronização → Copiar detalhes** para obter a mensagem completa, com projeto e UID, sem copiar senha ou tokens. Reinicie a aplicação após atualizar o código para usar o diagnóstico novo. Os registros pendentes devem ser mantidos; não é necessário apagar o SQLite nem recriar os perfis.
