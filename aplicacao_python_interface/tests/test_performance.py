import tempfile
from pathlib import Path
import unittest

from cloud_firebase import CloudConfig, FirestoreClient, FirebaseError, firestore_value
from performance_data import local_snapshot, remote_snapshot, report, metrics
from player_store import PlayerStore
from protocol import Event


class PerformanceTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.store = PlayerStore(Path(self.folder.name) / 'players.sqlite3')
        self.addCleanup(self.store.close)
        self.player = self.store.add_player('Paciente fictício')
        self.empty_player = self.store.add_player('Sem atividade')
        self.first = self.store.session(self.player)
        self.second = self.store.session(self.player)
        self.empty_session = self.store.session(self.empty_player)
        self.store.db.execute('UPDATE sessions SET started=? WHERE id=?', ('2026-01-01T10:00:00-03:00', self.first))
        self.store.db.execute('UPDATE sessions SET started=? WHERE id=?', ('2026-02-01T10:00:00-03:00', self.second))
        for session, day, result in [(self.first, '2026-01-01', False), (self.first, '2026-01-01', None),
                                      (self.second, '2026-02-01', True), (self.second, '2026-02-01', True)]:
            move = self.store.move(session, Event(0, 1))
            if result is not None:
                self.store.result(move, result)
            self.store.db.execute('UPDATE moves SET time=? WHERE id=?', (day + 'T10:01:00-03:00', move))
        self.store.db.commit()
        self.snapshot = local_snapshot(self.store)

    def test_weighted_rates_empty_profiles_sessions_and_evolution(self):
        data = report(self.snapshot)
        self.assertEqual(len(data['players']), 2)
        self.assertEqual(len(data['sessions']), 3)
        self.assertAlmostEqual(data['totals']['accuracy'], 200 / 3)
        self.assertEqual(data['totals']['missing'], 1)
        self.assertEqual(data['totals']['coverage'], 75)
        self.assertEqual(next(p[3] for p in data['players'] if p[0]['player_id'] == self.player), 100)
        self.assertIsNone(next(p[1]['accuracy'] for p in data['players'] if p[0]['player_id'] == self.empty_player))

    def test_filters_include_boundaries_and_empty_results(self):
        selected = report(self.snapshot, start='2026-02-01', end='2026-02-01')
        self.assertEqual(selected['totals']['accuracy'], 100)
        self.assertEqual(len(selected['sessions']), 1)
        self.assertEqual(len(selected['daily']), 1)
        self.assertEqual(report(self.snapshot, story=3)['totals']['presentations'], 0)
        with self.assertRaises(ValueError):
            report(self.snapshot, start='2026-02-30')
        with self.assertRaises(ValueError):
            report(self.snapshot, start='2026-02-01', end='2026-01-01')

    def test_same_ids_from_different_installations_never_merge(self):
        import copy
        extra = copy.deepcopy(self.snapshot)
        for rows in extra.values():
            for row in rows:
                row['installation_id'] = 'another-installation'
        combined = {key: self.snapshot[key] + extra[key] for key in self.snapshot}
        self.assertEqual(len(report(combined)['players']), 4)
        selected = report(combined, player=('another-installation', self.player), session=('another-installation', self.second))
        self.assertEqual(selected['totals']['presentations'], 2)
        self.assertEqual(len(selected['sessions']), 1)

    def test_remote_roundtrip_and_invalid_document(self):
        documents = {key: [{'fields': {k: firestore_value(v, k) for k, v in dict(row, schema_version=1).items()}}
                           for row in rows] for key, rows in self.snapshot.items()}
        self.assertEqual(report(remote_snapshot(documents))['totals'], report(self.snapshot)['totals'])
        documents['moves'][0]['fields']['result'] = {'integerValue': '3'}
        with self.assertRaises(ValueError):
            remote_snapshot(documents)

    def test_remote_names_keep_same_named_players_separate_and_old_labels_readable(self):
        import copy
        snapshot = copy.deepcopy(self.snapshot)
        snapshot['players'][1]['label'] = snapshot['players'][0]['label']
        self.assertEqual(len(report(snapshot)['players']), 2)
        docs = {key: [{'fields': {k: firestore_value(v, k) for k, v in dict(row, schema_version=1).items()}}
                      for row in rows] for key, rows in snapshot.items()}
        remote = remote_snapshot(docs)
        self.assertEqual(remote['players'][0]['label'], snapshot['players'][0]['label'])
        # Documentos antigos sem migração continuam visíveis pelo rótulo anterior.
        docs['players'][0]['fields']['label'] = {'stringValue': 'Jogador a1b2c3d4'}
        self.assertEqual(remote_snapshot(docs)['players'][0]['label'], 'Jogador a1b2c3d4')

    def test_without_results_is_not_zero_percent(self):
        self.assertIsNone(metrics([dict(self.snapshot['moves'][0], result=None)])['accuracy'])

    def test_utc_boundaries_match_local_and_firestore_timestamps(self):
        import copy
        local = copy.deepcopy(self.snapshot)
        local['moves'] = [dict(local['moves'][0], occurred_at='2026-01-01T23:30:00-03:00')]
        remote = copy.deepcopy(local)
        remote['moves'][0]['occurred_at'] = '2026-01-02T02:30:00Z'
        for snapshot in (local, remote):
            selected = report(snapshot, start='2026-01-02', end='2026-01-02')
            self.assertEqual(selected['totals']['presentations'], 1)
            self.assertEqual(selected['daily'][0][0], '2026-01-02')


class RemoteListingTests(unittest.TestCase):
    def client(self, transport):
        client = FirestoreClient(CloudConfig('projeto-teste', 'fake-key', 'operator'), transport=transport)
        client._refresh_token = 'fake-refresh'
        client._id_token = 'fake-id'
        client._expires_at = float('inf')
        return client

    def test_pagination_and_registered_installation_discovery(self):
        calls = []
        def transport(method, url, **kwargs):
            calls.append(url)
            if '/installations?' in url:
                return {'documents': [{'name': 'operators/operator/installations/computer1'}]}
            if '/players?' in url and 'pageToken' not in url:
                return {'documents': [{'fields': {'player_id': {'stringValue': 'first'}}}], 'nextPageToken': 'page/2'}
            if '/players?' in url:
                return {'documents': [{'fields': {'player_id': {'stringValue': 'second'}}}]}
            return {}
        data = self.client(transport).performance_documents()
        self.assertEqual(len(data['players']), 2)
        self.assertTrue(any('pageToken=page%2F2' in url for url in calls))
        self.assertTrue(all('/operators/operator/' in url for url in calls))

    def test_registration_is_minimal_idempotent_and_can_be_removed(self):
        from unittest.mock import Mock
        transport = Mock(return_value={})
        client = self.client(transport)
        client.register_installation('computer1')
        client.register_installation('computer1')
        self.assertEqual(transport.call_count, 1)
        self.assertEqual(set(transport.call_args.args[2]['fields']), {'installation_id', 'schema_version'})
        client.delete_installation_registration('computer1')
        self.assertEqual(transport.call_args.args[0], 'DELETE')

    def test_invalid_installation_and_pagination_loop_fail(self):
        client = self.client(lambda *args, **kwargs: {'nextPageToken': 'same'})
        with self.assertRaises(ValueError):
            client.performance_documents('../foreign')
        with self.assertRaises(FirebaseError):
            client.list_documents('operators/operator/installations')
