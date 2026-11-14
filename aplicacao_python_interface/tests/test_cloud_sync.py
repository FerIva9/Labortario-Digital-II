"""Testes locais com transporte substituído. Não acessam Firebase."""
import json
import io
from urllib.error import HTTPError, URLError
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import Mock, patch
from cloud_firebase import CloudConfig, FirebaseError, FirestoreClient, firestore_value, request_json, sync_once, SyncWorker
from player_store import PlayerStore
from protocol import Event

CONFIG = CloudConfig('fabula-teste', 'web-api-key-ficticia', 'operador123')


class OutboxTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.path = Path(self.folder.name) / 'players.db'
        self.store = PlayerStore(self.path)

    def tearDown(self):
        self.store.close()
        self.folder.cleanup()

    def test_snapshots_coalesce_and_include_player_name_only_in_profile(self):
        player = self.store.add_player('Nome privado')
        session = self.store.session(player)
        a = self.store.move(session, Event(2, 3))
        self.store.result(a, True)
        b = self.store.move(session, Event(2, 3))
        self.store.result(b, False)
        self.store.move(session, Event(1, 0))
        pending = self.store.outbox.pending()
        self.assertEqual(len(pending), 5)
        data = json.loads(next(r['payload'] for r in pending if r['entity'] == 'players'))
        self.assertEqual((data['presentations_count'], data['evaluated_count'], data['accuracy_percent']), (3, 2, 50.0))
        self.assertEqual(data['label'], 'Nome privado')
        self.assertTrue(all('Nome privado' not in r['payload'] for r in pending if r['entity'] != 'players'))
        self.assertNotIn('name', data)

    def test_failed_send_is_retried_with_same_ids(self):
        self.store.add_player('Teste')
        before = self.store.outbox.pending()
        client = Mock()
        client.commit.side_effect = FirebaseError('Sem rede', retryable=True)
        with self.assertRaises(FirebaseError):
            sync_once(self.store, client)
        self.assertEqual(self.store.outbox.pending(), before)
        client.commit.side_effect = None
        self.assertEqual(sync_once(self.store, client), 1)
        self.assertEqual(self.store.outbox.count(), 0)
        self.assertEqual(client.commit.call_args_list[0], client.commit.call_args_list[1])

    def test_quota_pauses_worker_and_preserves_outbox(self):
        self.store.add_player('Teste de cota')
        before = self.store.outbox.pending()
        client = Mock()
        client.commit.side_effect = FirebaseError('Limite de cota atingido', status=429)
        worker = SyncWorker(self.path, CONFIG, 'email-ficticio', 'senha-ficticia')
        with patch('cloud_firebase.FirestoreClient', return_value=client):
            worker.run()
        self.assertEqual(client.commit.call_count, 1)
        self.assertEqual(self.store.outbox.pending(), before)
        messages = []
        while not worker.events.empty():
            messages.append(worker.events.get_nowait())
        self.assertTrue(any('Sincronização pausada' in message for message in messages))
        self.assertIsNone(worker._password)

    def test_old_ack_preserves_newer_revision(self):
        player = self.store.add_player('Antes')
        old = self.store.outbox.pending()
        self.store.rename_player(player, 'Depois')
        self.store.outbox.acknowledge(old)
        self.assertEqual(self.store.outbox.count(), 1)
        self.assertGreater(self.store.outbox.pending()[0]['revision'], old[0]['revision'])

    def test_deletions_persist_and_isolate_other_players(self):
        first, second = self.store.add_player('A'), self.store.add_player('B')
        session = self.store.session(first)
        move = self.store.move(session, Event(0, 1))
        self.store.outbox.acknowledge(self.store.outbox.pending())
        installation = self.store.outbox.installation_id
        self.store.delete_player(first)
        self.store.close()
        self.store = PlayerStore(self.path)
        self.assertEqual(self.store.outbox.installation_id, installation)
        deletes = self.store.outbox.pending()
        self.assertEqual({(r['entity'], r['record_id']) for r in deletes},
                         {('players', first), ('sessions', session), ('moves', str(move))})
        self.assertTrue(all(r['operation'] == 'delete' for r in deletes))
        self.assertEqual([r['id'] for r in self.store.players()], [second])

    def test_queue_error_rolls_back_local_change(self):
        with patch.object(self.store.outbox, 'player', side_effect=sqlite3.OperationalError('Falha fictícia')):
            with self.assertRaises(sqlite3.OperationalError):
                self.store.add_player('Não deve persistir')
        self.assertEqual(self.store.players(), [])
        self.assertEqual(self.store.outbox.count(), 0)

    def test_old_database_seeds_once(self):
        self.store.close()
        db = sqlite3.connect(self.path)
        db.execute("DELETE FROM cloud_meta WHERE key='seeded'")
        db.execute("INSERT INTO players VALUES ('legado','Paciente legado')")
        db.execute("INSERT INTO sessions VALUES ('sessao','legado','2026-11-01T10:00:00-03:00')")
        db.execute("INSERT INTO moves(session,time,story,character) VALUES ('sessao','2026-11-01T10:01:00-03:00',2,3)")
        db.commit()
        db.close()
        self.store = PlayerStore(self.path)
        self.assertEqual(self.store.outbox.count(), 3)
        self.store.outbox.acknowledge(self.store.outbox.pending())
        self.store.close()
        self.store = PlayerStore(self.path)
        self.assertEqual(self.store.outbox.count(), 0)

    def test_existing_profiles_requeue_names_once_without_losing_history_or_deletes(self):
        player = self.store.add_player('Ana — paciente fictício')
        session = self.store.session(player)
        move = self.store.move(session, Event(0, 1))
        self.store.result(move, True)
        removed = self.store.add_player('Excluído')
        self.store.outbox.acknowledge(self.store.outbox.pending())
        self.store.delete_player(removed)
        with self.store.db:
            self.store.db.execute("DELETE FROM cloud_meta WHERE key='player_names_v1'")
        installation = self.store.outbox.installation_id
        self.store.close()
        self.store = PlayerStore(self.path)
        pending = self.store.outbox.pending()
        self.assertEqual(len(pending), 2)
        profile = next(r for r in pending if r['record_id'] == player)
        self.assertEqual(json.loads(profile['payload'])['label'], 'Ana — paciente fictício')
        self.assertEqual(next(r for r in pending if r['record_id'] == removed)['operation'], 'delete')
        self.assertEqual(self.store.outbox.installation_id, installation)
        self.assertEqual(self.store.history(player)[0]['id'], move)
        self.assertEqual(self.store.history(player)[0]['session_id'], session)
        self.store.outbox.acknowledge(pending)
        self.store.close()
        self.store = PlayerStore(self.path)
        self.assertEqual(self.store.outbox.count(), 0)
        self.store.rename_player(player, 'Ana atualizado')
        self.assertEqual(json.loads(self.store.outbox.pending()[0]['payload'])['label'], 'Ana atualizado')
        self.assertEqual(self.store.history(player)[0]['result'], 1)

    def test_destination_is_bound(self):
        self.store.outbox.bind('fabula-teste', 'operador123')
        self.store.outbox.bind('fabula-teste', 'operador123')
        with self.assertRaises(ValueError):
            self.store.outbox.bind('outro-projeto', 'outro-uid')


class FirebaseClientTests(unittest.TestCase):
    def transport(self):
        transport = Mock()
        transport.side_effect = [
            {'localId': 'operador123', 'idToken': 'token-ficticio', 'refreshToken': 'refresh-ficticio', 'expiresIn': '3600'},
            {'fields': {'enabled': {'booleanValue': True}}}]
        return transport

    def test_commit_uses_stable_ids_and_server_time(self):
        transport = self.transport()
        client = FirestoreClient(CONFIG, transport)
        client.sign_in('operador@exemplo.test', 'senha-ficticia')
        transport.side_effect = None
        row = {'entity': 'moves', 'record_id': '1', 'operation': 'upsert',
               'payload': json.dumps({'result': 1, 'result_at': '2026-11-13T10:00:00-03:00'})}
        client.commit('instalacao1', [row])
        args, kwargs = transport.call_args
        self.assertTrue(args[1].endswith('/documents:commit'))
        write = args[2]['writes'][0]
        self.assertTrue(write['update']['name'].endswith('/operators/operador123/installations/instalacao1/moves/1'))
        self.assertEqual(write['update']['fields']['result'], {'integerValue': '1'})
        self.assertIn('timestampValue', write['update']['fields']['result_at'])
        self.assertEqual(write['updateTransforms'][0]['setToServerValue'], 'REQUEST_TIME')
        self.assertEqual(kwargs['token'], 'token-ficticio')

    def test_denied_login_identifies_authentication_stage(self):
        transport = Mock(side_effect=FirebaseError('Acesso negado', status=403))
        client = FirestoreClient(CONFIG, transport)
        with self.assertRaises(FirebaseError) as raised:
            client.sign_in('email', 'senha-nao-exibir')
        self.assertIn('Login Firebase', str(raised.exception))
        self.assertIn('HTTP 403', str(raised.exception))
        self.assertNotIn('senha-nao-exibir', str(raised.exception))

    def test_denied_operator_read_identifies_document(self):
        transport = Mock(side_effect=[
            {'localId': CONFIG.operator_uid, 'idToken': 'token-nao-exibir', 'refreshToken': 'refresh-nao-exibir', 'expiresIn': '3600'},
            FirebaseError('Acesso negado', status=403)])
        client = FirestoreClient(CONFIG, transport)
        with self.assertRaises(FirebaseError) as raised:
            client.sign_in('email', 'senha')
        self.assertIn('Autorização do operador: operators/operador123', str(raised.exception))
        self.assertNotIn('token-nao-exibir', str(raised.exception))
        self.assertEqual(transport.call_count, 2)

    def test_wrong_uid_stops_before_data_access(self):
        transport = Mock(return_value={'localId': 'outro'})
        client = FirestoreClient(CONFIG, transport)
        with self.assertRaises(FirebaseError):
            client.sign_in('email', 'senha')
        self.assertEqual(transport.call_count, 1)

    def test_expired_token_refresh(self):
        transport = self.transport()
        client = FirestoreClient(CONFIG, transport)
        client.sign_in('email', 'senha')
        client._expires_at = 0
        transport.side_effect = None
        transport.return_value = {'user_id': 'operador123', 'id_token': 'renovado', 'refresh_token': 'novo', 'expires_in': '3600'}
        self.assertEqual(client.token(), 'renovado')
        self.assertTrue(transport.call_args.kwargs['form'])

    def test_delete_and_path_validation(self):
        transport = self.transport()
        client = FirestoreClient(CONFIG, transport)
        client.sign_in('email', 'senha')
        transport.side_effect = None
        client.commit('instalacao1', [{'entity': 'players', 'record_id': 'abc', 'operation': 'delete'}])
        self.assertIn('delete', transport.call_args.args[2]['writes'][0])
        with self.assertRaises(ValueError):
            client.document_path('instalacao1', 'players', '../outro')

    def test_config_excludes_credentials(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'config.json'
            CONFIG.save(path)
            self.assertEqual(CloudConfig.load(path), CONFIG)
            self.assertNotIn('password', path.read_text())
            self.assertNotIn('token', path.read_text())
            path.write_text('{"password":"nao-permitido"}')
            with self.assertRaises(ValueError):
                CloudConfig.load(path)
        with self.assertRaises(ValueError):
            CloudConfig('projeto/invalido', 'key', 'uid').validate()
        self.assertEqual(firestore_value(None), {'nullValue': None})


class QuotaHandlingTests(unittest.TestCase):
    def test_default_interval_groups_updates_for_one_minute(self):
        self.assertEqual(CONFIG.sync_interval_seconds, 60)

    def test_quota_stops_retries_without_leaking_response(self):
        for status, code in [(429, 'RESOURCE_EXHAUSTED'), (403, 'RESOURCE_EXHAUSTED')]:
            body = io.BytesIO(json.dumps({'error': {'status': code, 'message': 'mensagem-interna-nao-exibir'}}).encode())
            error = HTTPError('https://exemplo.test', status, 'Quota', {}, body)
            with self.subTest(status=status), patch('cloud_firebase.urlopen', side_effect=error):
                with self.assertRaises(FirebaseError) as raised:
                    request_json('POST', 'https://exemplo.test', {})
                self.assertFalse(raised.exception.retryable)
                self.assertIn('cota', str(raised.exception))
                self.assertNotIn('mensagem-interna', str(raised.exception))

    def test_transient_network_and_server_errors_still_retry(self):
        errors = [URLError('falha ficticia'), HTTPError('https://exemplo.test', 503, 'Indisponível', {}, io.BytesIO(b'{}'))]
        for error in errors:
            with self.subTest(error=type(error).__name__), patch('cloud_firebase.urlopen', side_effect=error):
                with self.assertRaises(FirebaseError) as raised:
                    request_json('GET', 'https://exemplo.test')
                self.assertTrue(raised.exception.retryable)


class FirebaseDiagnosticTests(unittest.TestCase):
    def test_api_restriction_has_specific_message_without_raw_response(self):
        body = io.BytesIO(json.dumps({'error': {
            'status': 'PERMISSION_DENIED', 'message': 'informacao-interna-nao-exibir',
            'details': [{'@type': 'type.googleapis.com/google.rpc.ErrorInfo', 'reason': 'API_KEY_SERVICE_BLOCKED'}]
        }}).encode())
        error = HTTPError('https://exemplo.test', 403, 'Forbidden', {}, body)
        with patch('cloud_firebase.urlopen', side_effect=error):
            with self.assertRaises(FirebaseError) as raised:
                request_json('GET', 'https://exemplo.test')
        self.assertIn('restrição da Web API Key', str(raised.exception))
        self.assertNotIn('informacao-interna', str(raised.exception))
