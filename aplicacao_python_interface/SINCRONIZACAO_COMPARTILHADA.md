# Base compartilhada e funcionamento offline

Esta versão usa o Firebase como base compartilhada dos computadores do **mesmo operador**. O SQLite é a cópia disponível offline e guarda a fila de alterações ainda não confirmadas. Jogadores remotos aparecem na tela inicial e suas sessões/jogadas entram no histórico do aplicativo, sem copiar manualmente bancos SQLite.

## Ativar a versão nova

1. Feche as versões antigas em todos os computadores. Faça uma cópia de segurança de `registros/jogadores.sqlite3` (no executável Windows: `%LOCALAPPDATA%\FabulaTEA\registros\jogadores.sqlite3`).
2. No Console Firebase, abra **Firestore Database → Rules**. Substitua o conteúdo pelo arquivo **`firebase/firestore.rules` completo desta versão** e clique em **Publish**. Não abra as regras para acesso público. A conta continua exigindo `operators/UID.enabled == true`.
3. Atualize o código e as dependências com `python -m pip install -r requirements.txt` em cada computador. No Windows, gere novamente pelo `gerar_windows.cmd`, mantendo o pacote privado no computador de geração, como explicado no README.
4. Abra a aplicação com a configuração e autorização já salvas, internet e **Nuvem → Sincronização automática** habilitada. Aguarde **Nuvem em dia**. Não é necessário criar uma sessão nem apertar um botão para enviar dados.
5. Abra a versão atualizada no outro computador. Após a primeira sincronização, os mesmos jogadores e históricos estarão disponíveis. Nomes iguais não unem perfis diferentes: a identidade é o ID, não o nome.

O código não publica as regras por conta própria: a autorização do aplicativo é de operador, não de administrador do projeto. Enquanto as regras não forem publicadas, o envio v2 será recusado, a coleta continuará localmente e haverá nova tentativa automática a cada cinco minutos. O botão de reconexão não interrompe uma requisição ou espera já em andamento; reabrir a aplicação inicia uma nova tentativa.

## O que é sincronizado

- Criação, alteração de nome e exclusão de jogadores.
- Novas sessões, inclusive sessões ainda sem jogadas, e históricos de todos os computadores.
- Apresentações recebidas pela serial e cada resultado `R0`/`R1` associado à sua jogada.
- Estatísticas calculadas a partir do histórico disponível; apresentações sem resultado continuam separadas das avaliações.

Uma sessão nova recebe um ID próprio e passa a fazer parte do histórico compartilhado. Consultar uma sessão antiga não a transforma na sessão ativa de recepção serial. Demonstrações visuais continuam fora das estatísticas.

## Conexão e atualização

A aplicação primeiro lê as alterações remotas, combina-as com pendências locais e envia o que falta. A primeira leitura inclui a base compartilhada inteira. As leituras seguintes pedem somente documentos alterados desde o horário fornecido pelo servidor. O cursor é mantido em memória; reiniciar faz uma nova leitura inicial completa.

Sem alterações locais, a verificação ocorre a cada **60 segundos** por padrão. Pendências novas acordam o trabalhador antes desse intervalo, com um pequeno agrupamento. Portanto, não é um listener instantâneo: a outra instalação vê a mudança na próxima consulta, conforme conexão e intervalo configurado.

Sem internet, os perfis, sessões e resultados ficam no SQLite, na mesma transação da fila. O aplicativo mantém as informações já baixadas e permite novos atendimentos offline. A reconexão acontece automaticamente com espera crescente, até 120 segundos entre tentativas transitórias. Não é necessário iniciar uma sessão para disparar o envio.

Ao atingir cota do Firebase, a coleta continua e o trabalhador tenta novamente **a cada 15 minutos**, sem habilitar cobrança. Uma conta revogada ou desabilitada exige corrigir o acesso: conexão de internet sozinha não restaura credenciais inválidas.

## Migração e recuperação do histórico antigo

Os novos documentos ficam em:

```text
operators/{UID}/installations/shared/players/{ID_global}
operators/{UID}/installations/shared/sessions/{ID_global}
operators/{UID}/installations/shared/moves/{ID_global}
```

O `schema_version` é 2. O horário `updated_at` é atribuído pelo Firestore. IDs globais mantêm a associação correta entre jogadores, sessões e jogadas, mesmo que computadores antigos tenham usado os mesmos números locais.

Na primeira sincronização da versão nova, cada computador cria `jogadores.pre-compartilhado.sqlite3`, ao lado do banco principal, antes de enfileirar a recuperação. Essa cópia contém dados privados e fica fora do Git. Os registros locais são reenfileirados uma vez, inclusive se a fila antiga estava vazia. Assim, o histórico antigo que só existia no SQLite pode chegar ao Firebase.

A migração lê também os históricos antigos indexados na nuvem e consulta diretamente a instalação local, mesmo que ela estivesse ausente do índice antigo. Ela usa IDs determinísticos para não duplicar os registros em reinícios. Uma instalação legada que não está indexada e cujo banco local não está disponível não pode ser descoberta automaticamente; atualize e abra a aplicação naquele computador.

Os documentos legados são preservados, sem exclusão automática. Após a migração, os aplicativos devem usar a versão nova: uma versão antiga que continua escrevendo na estrutura legada não participa da sincronização v2 em andamento.

## Conflitos e exclusões

- Uma alteração local ainda não enviada é preservada ao receber dados remotos. Para renomeações simultâneas do mesmo perfil, prevalece a última edição reconciliada e confirmada pelo servidor.
- Criar sessões em dois computadores não sobrescreve o atendimento do outro: cada sessão tem ID próprio.
- A escrita usa a versão do documento como pré-condição. Se outro computador mudou o registro, a aplicação lê novamente e reconcilia; a fila não é apagada por uma escrita recusada.
- Uma exclusão remota prevalece sobre uma edição antiga ou atendimento ainda pendente daquele perfil. Essas pendências deixam de ser publicadas para impedir a recriação do perfil excluído. O backup local anterior à migração e backups realizados pelo responsável são independentes dessa exclusão.
- Excluir cria um marcador mínimo, sem nome ou histórico, e propaga a exclusão às sessões/jogadas relacionadas. As regras impedem substituir esse marcador por um registro ativo. **Não remova os marcadores manualmente no Console**: eles impedem que computadores offline restaurem dados excluídos.
- Exclusões devem ser feitas pela aplicação; apagar documentos manualmente no Console não é o protocolo de exclusão suportado.

## Plano gratuito e acesso privado

Mantenha o projeto no Spark sem conta de faturamento vinculada. Consultas incrementais reduzem releituras, mas consultas vazias, regras, migração, inicialização de cada computador e marcadores de exclusão também consomem recursos. Não há promessa de volume ilimitado ou monitoramento de toda a cota global pelo aplicativo. Acompanhe Usage, especialmente com vários computadores ligados continuamente.

A pasta `.firebase-private/`, `firebase_defaults.json`, `firebase_config.json`, preferências, bancos locais e executáveis permanecem ignorados pelo Git. A pasta privada é necessária para gerar o executável autossuficiente; depois, somente o `.exe` é distribuído. O `.exe` contém autorização extraível e deve ser tratado como credencial privada. Não publique em commits ou Releases. A criptografia com chave incorporada não impede extração por quem possui o executável.

## Verificação

```bash
python -m unittest discover -s tests -v
python tools/check_layout.py
python tools/check_performance.py
```

Com o emulador oficial do Firestore em `127.0.0.1:8686`, projeto `demo-fabula`, carregando `firebase/firestore.rules`:

```bash
python tools/check_shared_integration.py --emulator
```

Depois de publicar as regras no Firebase real, o ensaio explícito usa a autorização salva e dois bancos locais temporários:

```bash
python tools/check_shared_integration.py --run-live
```

Esse último comando pode realizar a migração inicial dos documentos legados. Cria somente perfis de teste, verifica duas instalações e remove seus dados ao final, deixando os marcadores mínimos de exclusão. Se a rede falhar antes da limpeza, será necessário conferir os perfis fictícios no aplicativo/Console; não há exclusão indiscriminada de coleções reais.

No Windows, após gerar:

```powershell
$check = Start-Process .\dist\FabulaTEA.exe -ArgumentList '--check-ui', 'diagnostico-ui.txt' -Wait -PassThru
Get-Content -Encoding UTF8 diagnostico-ui.txt
$check.ExitCode
```

`--check-ui` verifica Tkinter, imagens, painel e presença do acesso incorporado sem usar internet. `--check-installation` inclui o ensaio explícito no Firebase real. O workflow está preparado para testar lógica/interface no Ubuntu e no Windows e empacota, no Windows, um executável com autorização inteiramente fictícia para conferir a execução fora da pasta de origem. Nenhuma credencial real é necessária no CI e nenhum executável com acesso real é publicado.

Referências técnicas: [consultas REST](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/runQuery), [pré-condições de escrita](https://firebase.google.com/docs/firestore/reference/rest/v1/Precondition), [cotas](https://firebase.google.com/docs/firestore/quotas).
