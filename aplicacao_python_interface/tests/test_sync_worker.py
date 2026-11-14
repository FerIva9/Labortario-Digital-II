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
from shared_fixture import SharedServer
from cloud_replica import global_id


class ContinuousSyncTests(unittest.TestCase):
    def test_sessions_results_retry_and_restart_with_sixty_second_fallback(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'players.sqlite3'
            store = PlayerStore(path)
            self.addCleanup(store.close)
            config = CloudConfig('projeto-teste', 'key', 'operator', 60)
            server = SharedServer()
            remote = {}
            client = server.client()
            original = client.commit_shared
            def commit(items):
                result = original(items)
                for item in items:
                    queued = item.get('queued')
                    if queued:
                        remote[(item['entity'], queued['record_id'])] = item['data']
                return result
            client.commit_shared = commit
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
                    server.online = False
                    failed = store.move(session, Event(0, 1))
                    store.result(failed, False)
                    worker.request_sync()
                    wait_for(lambda: any(isinstance(text,str) and 'Reconexão' in text for text in list(worker.events.queue)))
                    self.assertGreater(store.outbox.count(), 0)
                    server.online = True
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

    def test_idle_worker_receives_other_computer_changes_without_manual_request(self):
        from cloud_replica import SharedSync
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'reader.sqlite3'
            local=PlayerStore(path)
            other=PlayerStore(Path(folder)/'writer.sqlite3')
            server=SharedServer()
            worker=SyncWorker(path,CloudConfig('projeto-teste','key','operator',5),vault=Mock(load=Mock(return_value='fake-refresh')),
                              client_factory=lambda cfg:server.client())
            def wait_for(predicate):
                deadline=time.monotonic()+10
                while not predicate() and time.monotonic()<deadline: time.sleep(.02)
                self.assertTrue(predicate())
            try:
                worker.start()
                wait_for(lambda:any(isinstance(event,str) and 'Nuvem em dia' in event for event in list(worker.events.queue)))
                player=other.add_player('Criado no outro computador')
                other.session(player)
                SharedSync(other,server.client()).cycle()
                # Não acorda o leitor: o polling deve receber o perfil sozinho.
                wait_for(lambda:len(local.players())==1)
                self.assertEqual(local.players()[0]['name'],'Criado no outro computador')
                self.assertEqual(local.db.execute('SELECT count(*) FROM sessions').fetchone()[0],1)
                self.assertEqual(local.outbox.count(),0)
            finally:
                worker.stop();worker.thread.join(3)
                self.assertFalse(worker.thread.is_alive())
                local.close();other.close()
