"""Ensaio remoto posterior à configuração. Exige --run-live e usa banco fictício."""
import argparse
from getpass import getpass
import json
from pathlib import Path
import sys
import tempfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from cloud_firebase import CloudConfig, FirebaseError, FirestoreClient, request_json, sync_once
from player_store import PlayerStore
from protocol import Event
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
            require('PERFIL FICTÍCIO' not in json.dumps(fields, ensure_ascii=False), 'Nome local apareceu na nuvem.')
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
            print('OK: consulta geral de dois computadores e isolamento de IDs repetidos.')
            store.rename_player(player, 'OUTRO NOME LOCAL FICTÍCIO')
            drain(store, client)
            renamed = client.get_document(installation, 'players', player)
            require('OUTRO NOME LOCAL' not in json.dumps(renamed), 'Nome local apareceu após renomeação.')
            print('OK: renomeação mantém o identificador codificado na nuvem.')
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
                    for entity, record_id in [('sessions', session), ('moves', str(first)), ('moves', str(second)), ('moves', str(third))]:
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
