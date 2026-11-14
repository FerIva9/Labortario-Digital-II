# Verificação da base compartilhada — 14/11/2026

Verificado no Linux, com Python 3.10, sem modificar os registros do Firebase de produção nem o SQLite real do usuário.

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
| Windows | Caminhos, bootstrap do executável e lógica possuem testes. Workflow preparado para executar testes nativos, gerar `.exe` fictício e verificar seu diagnóstico fora da pasta de origem. O workflow e o novo `.exe` não foram executados no Windows nesta sessão. |
| Firebase de produção | As regras novas não foram publicadas nesta sessão. A ativação requer o responsável publicar `firebase/firestore.rules` e atualizar as aplicações. |

O emulador usa exclusivamente projeto, token e dados fictícios. Os perfis do ensaio são removidos ao final; os marcadores de exclusão não contêm nomes ou históricos. Os comandos para repetir os testes e os passos de ativação estão em [SINCRONIZACAO_COMPARTILHADA.md](SINCRONIZACAO_COMPARTILHADA.md).
