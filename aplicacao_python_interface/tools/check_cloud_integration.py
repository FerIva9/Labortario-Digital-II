"""Ensaio remoto posterior à configuração. Exige --run-live e usa banco fictício."""
import argparse
from getpass import getpass
import json
from pathlib import Path
import sys
import tempfile
import time
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from cloud_firebase import CloudConfig, FirebaseError, FirestoreClient, request_json, sync_once, SyncWorker
from player_store import PlayerStore
from protocol import Event, Result, Decoder
from runtime_paths import cloud_config_path
from cloud_portable import PortableVault
from cloud_credentials import CredentialUnavailable
from performance_data import remote_snapshot, report


def drain(store, client):
    while store.outbox.count():
        sync_once(store, client)


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def verify_automatic(store, config, refresh_token, player):
    """Trabalhador real: sessão vazia, resultado posterior, R1/R0 e reinício."""
    class SessionVault:
        def load(self, config):
            return refresh_token
        def save(self, config, token):
            pass
    worker = None
    records = []
    def wait_for_upload():
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            if not store.outbox.count():
                return
            if not worker.thread.is_alive():
                raise RuntimeError('Trabalhador automático encerrou antes de confirmar o envio.')
            time.sleep(.05)
        raise RuntimeError('Envio automático não confirmou os dados dentro do prazo.')
    def start_worker():
        return SyncWorker(Path(store.db.execute('PRAGMA database_list').fetchone()['file']), config,
                          remember=True, vault=SessionVault())
    try:
        session = store.session(player)
        records.append(('sessions', session))
        worker = start_worker()
        worker.start()
        wait_for_upload()
        reader = FirestoreClient(config)
        reader.restore(refresh_token)
        fields = reader.get_document(store.outbox.installation_id, 'sessions', session)['fields']
        require(fields['presentations_count']['integerValue'] == '0', 'Sessão vazia não sincronizada automaticamente.')
        decoder = Decoder()
        pending = None
        # Recepção fragmentada, como na UART real; o resultado pode chegar após o envio da apresentação.
        for fragment in (b'H0,P1\nR', b'1\nH0,P1\nR0\n'):
            for event in decoder.feed(fragment):
                if isinstance(event, Event):
                    pending = store.move(session, event)
                    records.append(('moves', str(pending)))
                elif isinstance(event, Result):
                    require(pending is not None, 'Resultado sem apresentação no ensaio.')
                    store.result(pending, event.correct)
                    pending = None
                else:
                    raise RuntimeError('Protocolo inválido no ensaio automático.')
            worker.request_sync()
            wait_for_upload()
        fields = reader.get_document(store.outbox.installation_id, 'sessions', session)['fields']
        require(fields['evaluated_count']['integerValue'] == '2', 'Resultados R0/R1 não sincronizados.')
        require(fields['accuracy_percent']['doubleValue'] == 50.0, 'Resumo automático divergente.')
        worker.stop()
        worker.thread.join(15)
        require(not worker.thread.is_alive(), 'Trabalhador anterior não encerrou.')
        another = store.session(player)
        records.append(('sessions', another))
        worker = start_worker()
        worker.start()
        wait_for_upload()
        reader.get_document(store.outbox.installation_id, 'sessions', another)
        print('OK: trabalhador automático, sessão vazia, atualização posterior, R1/R0 e retomada com acesso salvo.')
        return records
    finally:
        if worker:
            worker.stop()
            worker.thread.join(15)
            require(not worker.thread.is_alive(), 'Trabalhador automático ainda ativo durante a limpeza.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-live', action='store_true', help='autoriza criar e remover apenas dados fictícios da instalação temporária deste ensaio')
    parser.add_argument('--config', type=Path, default=cloud_config_path())
    parser.add_argument('--saved-access', action='store_true',
                        help='usa a autorização já preparada, sem solicitar email ou senha')
    args = parser.parse_args()
    if not args.run_live:
        print('Nenhuma requisição realizada. Após configurar o Firebase, execute com --run-live.')
        return 0
    config = CloudConfig.load_active(local_path=args.config)
    print(f'Projeto: {config.project_id} | UID configurado: {config.operator_uid}')
    client = FirestoreClient(config)
    if args.saved_access:
        vault = PortableVault()
        token = vault.load(config)
        if not token:
            raise ValueError('Acesso salvo ausente. Execute tools/prepare_private_access.py.')
        client.restore(token)
        vault.save(config, client._refresh_token)
    else:
        email = input('Email do responsável: ').strip()
        password = getpass('Senha (não será gravada nem exibida): ')
        try:
            client.sign_in(email, password)
        finally:
            password = None
    with tempfile.TemporaryDirectory() as folder:
        store = PlayerStore(Path(folder) / 'ensaio.sqlite3')
        player = None
        session = first = second = third = None
        cleanup_failed = False
        success = False
        other = None
        automatic_records = []
        installation = store.outbox.installation_id
        print(f'Instalação TEMPORÁRIA: {installation}')
        try:
            store.outbox.bind(config.project_id, config.operator_uid)
            player = store.add_player('PERFIL FICTÍCIO — ensaio IoT')
            session = store.session(player)
            first = store.move(session, Event(2, 3))
            store.result(first, True)
            second = store.move(session, Event(2, 3))
            store.result(second, False)
            third = store.move(session, Event(1, 0))
            drain(store, client)
            fields = client.get_document(installation, 'players', player)['fields']
            require(fields['evaluated_count']['integerValue'] == '2', 'Contagem de avaliações divergente.')
            require(fields['correct_count']['integerValue'] == '1', 'Contagem de acertos divergente.')
            require(fields['accuracy_percent']['doubleValue'] == 50.0, 'Taxa de acertos divergente.')
            require(fields['label']['stringValue'] == 'PERFIL FICTÍCIO — ensaio IoT', 'Nome do jogador não sincronizado.')
            raw = client.get_document(installation, 'moves', str(first))['fields']
            require(raw['result']['integerValue'] == '1', 'Resultado da jogada divergente.')
            require('timestampValue' in raw['received_at'], 'Horário do servidor ausente.')
            require(sync_once(store, client) == 0, 'Fila deveria estar vazia após confirmação.')
            print('OK: envio, consulta, estatísticas, resultado, horário do servidor e confirmação da fila.')
            performance = report(remote_snapshot(client.performance_documents(installation)))
            require(performance['totals']['accuracy'] == 50.0, 'Taxa do painel remoto divergente.')
            require(performance['totals']['missing'] == 1, 'Apresentação sem resultado ausente no painel.')
            require(len(performance['sessions']) == 1, 'Sessão ausente no painel remoto.')
            parents = client.list_documents(f'operators/{config.operator_uid}/installations')
            require(any(doc['name'].endswith('/' + installation) for doc in parents), 'Instalação não descoberta. Publique as regras atualizadas.')
            print('OK: acompanhamento remoto, sessão, taxa, ausência de resultado e descoberta de instalações.')
            other = PlayerStore(Path(folder) / 'outro-computador.sqlite3')
            other.outbox.bind(config.project_id, config.operator_uid)
            # O mesmo ID de jogador e de jogada em outro computador não pode se misturar.
            with other.db:
                other.db.execute('INSERT INTO players VALUES (?,?)', (player, 'OUTRO PERFIL FICTÍCIO'))
                other.outbox.player(player)
            other_session = other.session(player)
            other.result(other.move(other_session, Event(0, 0)), False)
            drain(other, client)
            all_data = remote_snapshot(client.performance_documents())
            own = report(all_data, player=(installation, player))
            foreign_installation = report(all_data, player=(other.outbox.installation_id, player))
            require(own['totals']['accuracy'] == 50.0, 'Instalações foram misturadas no painel.')
            require(foreign_installation['totals']['accuracy'] == 0.0, 'Outra instalação não foi lida corretamente.')
            require(own['players'][0][0]['label'] == 'PERFIL FICTÍCIO — ensaio IoT', 'Nome do primeiro computador incorreto.')
            require(foreign_installation['players'][0][0]['label'] == 'OUTRO PERFIL FICTÍCIO', 'Nomes de computadores diferentes foram misturados.')
            print('OK: consulta geral de dois computadores e isolamento de IDs repetidos.')
            store.rename_player(player, 'OUTRO NOME LOCAL FICTÍCIO')
            drain(store, client)
            renamed = client.get_document(installation, 'players', player)
            require(renamed['fields']['label']['stringValue'] == 'OUTRO NOME LOCAL FICTÍCIO', 'Renomeação não chegou à nuvem.')
            updated = report(remote_snapshot(client.performance_documents(installation)))
            require(updated['players'][0][0]['label'] == 'OUTRO NOME LOCAL FICTÍCIO', 'Nome atualizado ausente do painel remoto.')
            require(updated['totals']['accuracy'] == 50.0, 'Renomeação alterou o histórico do jogador.')
            print('OK: nome e renomeação disponíveis no painel remoto sem perder sessões ou estatísticas.')
            own_url = client.base + '/' + client.document_path(installation, 'players', player)
            foreign_url = own_url.replace('/operators/' + config.operator_uid + '/', '/operators/outro-operador-teste/')
            installations_url = client.base + f'/operators/{config.operator_uid}/installations'
            foreign_installations = client.base + '/operators/outro-operador-teste/installations'
            for label, url, token in [('sem autenticação', own_url, None), ('outro operador', foreign_url, client.token()),
                                      ('instalações sem autenticação', installations_url, None),
                                      ('instalações de outro operador', foreign_installations, client.token())]:
                try:
                    request_json('GET', url, token=token)
                except FirebaseError as error:
                    require(error.status in (401, 403), f'Falha inesperada no teste de acesso: {label}.')
                else:
                    raise RuntimeError(f'As regras permitiram acesso indevido: {label}.')
                print(f'OK: acesso negado — {label}.')
            automatic_records = verify_automatic(store, config, client._refresh_token, player)
            success = True
        finally:
            if other:
                try:
                    other.delete_player(player)
                    drain(other, client)
                    client.delete_installation_registration(other.outbox.installation_id)
                    print('OK: dados fictícios do segundo computador removidos.')
                except Exception:
                    cleanup_failed = True
                    print(f'Confira SOMENTE operators/{config.operator_uid}/installations/{other.outbox.installation_id} no Console.')
                finally:
                    other.close()
            try:
                if player:
                    store.delete_player(player)
                    drain(store, client)
                    try:
                        client.get_document(installation, 'players', player)
                    except FirebaseError as error:
                        require(error.status == 404, 'Não foi possível confirmar a exclusão remota.')
                    else:
                        raise RuntimeError('O perfil fictício continua no banco remoto.')
                    for entity, record_id in [('sessions', session), ('moves', str(first)), ('moves', str(second)), ('moves', str(third))] + automatic_records:
                        if record_id in (None, 'None'):
                            continue
                        try:
                            client.get_document(installation, entity, record_id)
                        except FirebaseError as error:
                            require(error.status == 404, 'Não foi possível confirmar remoção de dados relacionados.')
                        else:
                            raise RuntimeError('Dados relacionados ao perfil fictício continuam na nuvem.')
                    client.delete_installation_registration(installation)
                    print('OK: perfil fictício, sessão, jogadas e registro da instalação removidos da nuvem.')
            except Exception as error:
                cleanup_failed = True
                print(f'Limpeza remota não confirmada: {error}')
                print(f'Confira SOMENTE operators/{config.operator_uid}/installations/{installation} no Console.')
            finally:
                store.close()
        return 0 if success and not cleanup_failed else 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (FirebaseError, CredentialUnavailable, ValueError, OSError, RuntimeError) as error:
        print(f'Ensaio não concluído: {error}', file=sys.stderr)
        raise SystemExit(1)
