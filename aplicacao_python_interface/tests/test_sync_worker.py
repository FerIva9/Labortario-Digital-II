"""Trabalhador real em thread: novos dados, indisponibilidade e retomada da fila."""
import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import Mock, patch

from cloud_firebase import CloudConfig, FirebaseError, SyncWorker
from player_store import PlayerStore
from protocol import Event


class ContinuousSyncTests(unittest.TestCase):
    def test_sessions_results_retry_and_restart_with_sixty_second_fallback(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'players.sqlite3'
            store = PlayerStore(path)
            self.addCleanup(store.close)
            config = CloudConfig('projeto-teste', 'key', 'operator', 60)
            remote = {}
            online = [True]
            client = Mock()
            client._refresh_token = 'refresh-ficticio'
            def commit(installation, items):
                if not online[0]:
                    raise FirebaseError('Offline fictício', retryable=True)
                for item in items:
                    remote[(item['entity'], item['record_id'])] = json.loads(item['payload'])
            client.commit.side_effect = commit
            vault = Mock()
            vault.load.return_value = 'refresh-ficticio'
            worker = SyncWorker(path, config, remember=False, vault=vault)
            def wait_for(predicate, timeout=8):
                deadline = time.monotonic() + timeout
                while not predicate() and time.monotonic() < deadline:
                    time.sleep(.01)
                self.assertTrue(predicate(), 'A sincronização não concluiu dentro do prazo.')
            with patch('cloud_firebase.FirestoreClient', return_value=client):
                try:
                    player = store.add_player('Perfil fictício')
                    worker.start()
                    wait_for(lambda: store.outbox.count() == 0)
                    self.assertFalse(vault.save.called)
                    worker.request_sync(remember=True)
                    wait_for(lambda: vault.save.called)
                    session = store.session(player)
                    worker.request_sync()
                    wait_for(lambda: store.outbox.count() == 0)
                    self.assertEqual(remote['sessions', session]['evaluated_count'], 0)
                    move = store.move(session, Event(0, 1))
                    worker.request_sync()
                    wait_for(lambda: store.outbox.count() == 0)
                    self.assertIsNone(remote['moves', str(move)]['result'])
                    store.result(move, True)
                    worker.request_sync()
                    wait_for(lambda: store.outbox.count() == 0)
                    self.assertEqual(remote['moves', str(move)]['result'], 1)
                    online[0] = False
                    failed = store.move(session, Event(0, 1))
                    store.result(failed, False)
                    worker.request_sync()
                    wait_for(lambda: any('Reconexão' in text for text in list(worker.events.queue)))
                    self.assertGreater(store.outbox.count(), 0)
                    online[0] = True
                    wait_for(lambda: store.outbox.count() == 0)
                    self.assertEqual(remote['sessions', session]['accuracy_percent'], 50)
                    self.assertEqual(len([key for key in remote if key[0] == 'moves']), 2)
                    worker.stop()
                    worker.thread.join(2)
                    self.assertFalse(worker.thread.is_alive())
                    new_session = store.session(player)
                    replacement = SyncWorker(path, config, remember=True, vault=vault)
                    worker = replacement
                    replacement.start()
                    wait_for(lambda: store.outbox.count() == 0)
                    self.assertIn(('sessions', new_session), remote)
                    self.assertTrue(vault.save.called)
                finally:
                    worker.stop()
                    worker.thread.join(3)
                    store.close()
                    # A limpeza já ocorreu antes de remover a pasta temporária no Windows.
                    self.doCleanups()
