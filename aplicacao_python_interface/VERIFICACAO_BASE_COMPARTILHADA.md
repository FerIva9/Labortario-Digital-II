# Verificação da base compartilhada — 14/11/2026

Verificação original no Linux, com Python 3.10. A verificação adicional nativa no Windows está registrada ao final. Os ensaios preservam o SQLite real do usuário e os históricos reais do Firebase.

| Verificação | Resultado |
| --- | --- |
| Testes unitários e de integração local | 86 passaram. |
| Interface principal | 12 combinações de tamanho e escala passaram. |
| Perfis recebidos pela rede | Perfil remoto aparece na tela inicial; nome muda durante uma sessão; exclusão remota encerra a sessão e atualiza a lista. |
| Protocolo serial | Mensagens fragmentadas, repetidas, R0/R1, resultados órfãos e associação à jogada continuam cobertos. A FPGA física não foi conectada. |
| Diagnóstico gráfico local | Tkinter, 24 imagens, filtros, gráficos, CSV e falha de rede passaram. |
| Emulador oficial Firestore 1.19.8 | Regras reais carregadas; duas instalações compartilham perfil, sessões, acerto e erro, produzindo taxa de 50%. |
| Trabalhador automático | Envia pendências e recebe alterações de outra instalação sem pedido manual; retoma após indisponibilidade. |
| Concorrência | Conflitos de versão preservam pendências; resposta perdida após commit não duplica registros; alterações feitas durante o envio não são apagadas pela confirmação anterior. |
| Exclusões | Propagação, filhos criados por outro computador e proteção contra recriação de perfil excluído passaram. |
| Segurança das regras | Acesso sem autenticação e de outro operador negado; tentativa de restaurar perfil excluído negada. |
| Migração | Histórico com fila antiga vazia é recuperado; nome remoto atual prevalece sobre cache antigo sem edição local; backup anterior à recuperação é criado. |
| Privacidade do repositório | Configurações, pacote privado, executáveis e backups ignorados; nenhum arquivo publicável contém a chave, UID, email ou token reais verificados. Isso não é uma auditoria completa de segurança. |
| Windows | Verificação adicional concluída: 89 testes, interface em 12 combinações de tamanho/escala, compilação e diagnóstico do `.exe` fora da pasta de origem. Veja abaixo. |
| Firebase de produção | O responsável confirmou a publicação das regras v2. O ensaio nativo no Windows passou usando dois bancos temporários e apenas um perfil fictício, sem migrar históricos reais. |

O emulador usa exclusivamente projeto, token e dados fictícios. Os perfis do ensaio são removidos ao final; os marcadores de exclusão não contêm nomes ou históricos. Os comandos para repetir os testes e os passos de ativação estão em [SINCRONIZACAO_COMPARTILHADA.md](SINCRONIZACAO_COMPARTILHADA.md).

## Verificação adicional no Windows

Código da aplicação baseado no commit `b071cae`, recebido do Linux. O roteiro de
diagnóstico foi ajustado para limitar as escritas ao perfil fictício do ensaio e
ignorar a migração de históricos reais. Três testes adicionais verificam esse
isolamento, incluindo rejeição de lotes que contenham registros fora do ensaio.

Resultados observados no Windows:

- Os **89 testes** passaram, incluindo fila offline, concorrência, conflito de
  versão, resposta perdida, exclusão remota e migração com dados fictícios.
- `tools/check_layout.py` passou em três tamanhos e quatro escalas. Confirmou
  perfil remoto na tela inicial, renomeação durante a sessão e encerramento
  seguro quando o perfil ativo é excluído remotamente. A recepção fragmentada
  de R1/R0 permanece coberta.
- `tools/check_performance.py` passou em três tamanhos, incluindo filtros,
  estatísticas, gráfico, CSV, nomes remotos e preservação do painel após falha.
- A inspeção visual confirmou a tela inicial organizada e o estado visível da
  sincronização. As tabelas de acompanhamento continuam largas: usam rolagem
  horizontal e colunas redimensionáveis; nomes longos podem exigir ampliar a
  primeira coluna. Capturas com perfis fictícios ficam em `build/`.
- `tools/build_windows.py` gerou `dist/FabulaTEA.exe` com os recursos gráficos,
  configuração e autorização privada incorporados.
- O **próprio executável** foi copiado para uma pasta isolada e executado com
  `--check-installation`, sem configuração externa nem acesso ao cofre. Saiu com
  **código 0**. Verificou Tkinter, 24 imagens, painel e bootstrap incorporado.
- No Firebase real, dois bancos SQLite temporários simularam duas instalações:
  jogador, sessão e acerto criados em A chegaram a B; renomeação, nova sessão e
  erro em B voltaram a A, reunindo o histórico com taxa de **50%**.
- O trabalhador enviou uma sessão em segundo plano e uma instalação ociosa
  recebeu alteração de outra **sem consulta manual**. Esse ensaio usa intervalo
  de 5 segundos apenas no trabalhador temporário; o JSON do usuário não muda.
- A exclusão propagou para a outra instalação e permaneceu após reiniciar o
  sincronizador. Os dados fictícios foram removidos, restando os marcadores
  mínimos de exclusão sem nomes previstos pelo protocolo.

O log final está em `build/exe-check-shared-final/diagnostico.txt`, ignorado pelo
Git. A migração do banco real do usuário não foi executada pelo diagnóstico;
ela permanece no fluxo normal da aplicação, com backup anterior à migração.
A FPGA física não foi conectada nesta verificação. O `.exe` contém autorização
privada e continua fora do Git.
