from pathlib import Path
import tempfile
import unittest
from cloud_firebase import FirebaseError, firestore_value
from cloud_replica import SharedSync, global_id
from player_store import PlayerStore, summarize
from protocol import Event
from shared_fixture import SharedServer


class SharedSyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.server = SharedServer()
        self.a = PlayerStore(Path(self.temp.name)/'a.sqlite3')
        self.b = PlayerStore(Path(self.temp.name)/'b.sqlite3')
        self.addCleanup(self.a.close)
        self.addCleanup(self.b.close)
        self.sa, self.sb = SharedSync(self.a,self.server.client()), SharedSync(self.b,self.server.client())

    def cycle(self, sync):
        while True:
            sent, _ = sync.cycle()
            if not sent: return

    def test_shared_players_sessions_results_rename_and_restart(self):
        player = self.a.add_player('Jogador A')
        first = self.a.session(player)
        self.a.result(self.a.move(first, Event(2,3)), True)
        self.cycle(self.sa); self.cycle(self.sb)
        imported = self.b.players()[0]['id']
        self.assertEqual(self.b.players()[0]['name'], 'Jogador A')
        self.assertEqual(summarize(self.b.history(imported)), (1,1,100.0))
        second = self.b.session(imported)
        self.b.result(self.b.move(second, Event(2,3)), False)
        self.b.rename_player(imported, 'Novo nome')
        self.cycle(self.sb); self.cycle(self.sa)
        self.assertEqual(len(self.a.players()),1)
        self.assertEqual(self.a.players()[0]['name'],'Novo nome')
        self.assertEqual(summarize(self.a.history(player)), (2,1,50.0))
        self.assertEqual(self.a.db.execute('SELECT count(*) FROM sessions').fetchone()[0],2)
        replacement = SharedSync(self.b,self.server.client())
        self.cycle(replacement)
        self.assertEqual(len(self.b.players()),1)
        self.assertEqual(summarize(self.b.history(imported)), (2,1,50.0))

    def test_offline_recovery_and_remote_deletion_wins_over_stale_edit(self):
        player = self.a.add_player('Offline')
        self.server.online=False
        with self.assertRaises(FirebaseError): self.sa.cycle()
        self.assertGreater(self.a.outbox.count(),0)
        self.server.online=True
        self.cycle(self.sa); self.cycle(self.sb)
        imported = self.b.players()[0]['id']
        self.b.rename_player(imported,'Edição offline antiga')
        session = self.b.session(imported)
        self.b.result(self.b.move(session,Event(0,1)),True)
        self.a.delete_player(player)
        self.cycle(self.sa); self.cycle(self.sb)
        self.assertEqual(self.b.players(),[])
        self.assertEqual(self.b.db.execute('SELECT count(*) FROM sessions').fetchone()[0],0)
        self.assertEqual(self.b.outbox.count(),0)
        self.cycle(SharedSync(self.b,self.server.client()))
        self.assertEqual(self.b.players(),[])

    def test_concurrent_sessions_and_rename_merge_without_lost_records(self):
        player=self.a.add_player('Original')
        self.cycle(self.sa); self.cycle(self.sb)
        imported=self.b.players()[0]['id']
        self.a.rename_player(player,'Alterado no computador A')
        self.a.result(self.a.move(self.a.session(player),Event(0,1)),True)
        self.b.result(self.b.move(self.b.session(imported),Event(1,1)),False)
        self.cycle(self.sa); self.cycle(self.sb); self.cycle(self.sa)
        self.assertEqual(self.b.players()[0]['name'],'Alterado no computador A')
        self.assertEqual(summarize(self.b.history(imported)),(2,1,50.0))
        self.assertEqual(summarize(self.a.history(player)),(2,1,50.0))

    def test_compare_and_swap_conflict_preserves_pending_and_reconciles(self):
        player=self.a.add_player('Primeiro')
        self.cycle(self.sa); self.cycle(self.sb)
        self.a.rename_player(player,'Edição A')
        imported=self.b.players()[0]['id']
        self.b.rename_player(imported,'Edição B')
        self.server.before_commit=lambda: self.cycle(self.sb)
        with self.assertRaises(FirebaseError): self.sa.cycle()
        self.assertGreater(self.a.outbox.count(),0)
        self.cycle(self.sa); self.cycle(self.sb)
        self.assertEqual(self.b.players()[0]['name'],'Edição A')

    def test_migration_recovers_empty_queue_and_never_revives_deleted_legacy_profile(self):
        player=self.a.add_player('Legado')
        session=self.a.session(player)
        self.a.result(self.a.move(session, Event(1,2)),True)
        own=self.a.outbox.installation_id
        for item in self.a.outbox.pending():
            import json
            data=dict(json.loads(item['payload']),installation_id=own)
            self.server.legacy[item['entity']].append({'fields':{k:firestore_value(v,k) for k,v in data.items()}})
        self.a.outbox.acknowledge(self.a.outbox.pending())
        self.a.db.execute("DELETE FROM cloud_meta WHERE key='shared_seed_v2'"); self.a.db.commit()
        self.cycle(SharedSync(self.a,self.server.client())); self.cycle(self.sb)
        self.assertEqual(len(self.b.players()),1)
        self.assertEqual(len(self.b.history(self.b.players()[0]['id'])),1)
        self.a.delete_player(player); self.cycle(self.sa)
        self.cycle(SharedSync(self.b,self.server.client()))
        self.assertEqual(self.b.players(),[])

    def test_revision_ack_does_not_erase_change_made_during_network_request(self):
        player=self.a.add_player('Antes')
        self.server.before_commit=lambda: self.a.rename_player(player,'Depois')
        self.sa.cycle()
        self.assertGreater(self.a.outbox.count(),0)
        self.cycle(self.sa); self.cycle(self.sb)
        self.assertEqual(self.b.players()[0]['name'],'Depois')

    def test_committed_response_lost_is_reconciled_without_duplicates(self):
        player=self.a.add_player('Resposta perdida')
        original=self.sa.client.commit_shared
        def lost(items):
            original(items)
            raise FirebaseError('Resposta perdida fictícia',retryable=True)
        self.sa.client.commit_shared=lost
        with self.assertRaises(FirebaseError): self.sa.cycle()
        self.assertGreater(self.a.outbox.count(),0)
        self.sa.client.commit_shared=original
        self.cycle(self.sa); self.cycle(self.sb)
        self.assertEqual(len(self.b.players()),1)
        self.assertEqual(self.a.outbox.count(),0)

    def test_failed_cascade_is_retried_and_late_sessions_are_removed(self):
        player=self.a.add_player('Pai')
        self.cycle(self.sa); self.cycle(self.sb)
        imported=self.b.players()[0]['id']
        self.b.session(imported); self.cycle(self.sb)
        # A ainda não conhece a sessão que B acabou de enviar.
        self.a.delete_player(player)
        self.sa.cycle()
        original=self.sa.client.commit_shared
        self.sa.client.commit_shared=lambda items: (_ for _ in ()).throw(FirebaseError('Rede caiu',retryable=True))
        with self.assertRaises(FirebaseError): self.sa.cycle()
        self.sa.client.commit_shared=original
        self.cycle(self.sa); self.cycle(self.sb)
        self.assertEqual(self.b.players(),[])
        self.assertEqual(self.b.db.execute('SELECT count(*) FROM sessions').fetchone()[0],0)
        self.assertTrue(all(doc['fields']['deleted']['booleanValue'] for doc in self.server.documents['sessions'].values()))

    def test_remote_name_wins_over_clean_old_cache_during_one_time_recovery(self):
        player=self.a.add_player('Nome antigo')
        self.cycle(self.sa); self.cycle(self.sb)
        imported=self.b.players()[0]['id']
        self.b.rename_player(imported,'Nome remoto atual'); self.cycle(self.sb)
        # Simula um cache legado sem alteração local pendente.
        self.a.db.execute("DELETE FROM cloud_meta WHERE key='shared_seed_v2'")
        self.a.db.commit()
        self.cycle(SharedSync(self.a,self.server.client()))
        self.assertEqual(self.a.players()[0]['name'],'Nome remoto atual')

    def test_firestore_utc_z_timestamps_survive_cache_and_payload_reencoding(self):
        player=self.a.add_player('Horários UTC')
        session=self.a.session(player)
        self.a.result(self.a.move(session,Event(2,3)),True)
        self.cycle(self.sa)
        for rows in self.server.documents.values():
            for doc in rows.values():
                for key in ('started_at','occurred_at','result_at','updated_at'):
                    value=doc['fields'].get(key)
                    if value and 'timestampValue' in value:
                        from performance_data import parse_time
                        from datetime import timezone
                        value['timestampValue']=parse_time(value['timestampValue']).astimezone(timezone.utc).isoformat().replace('+00:00','Z')
        self.cycle(self.sb)
        imported=self.b.players()[0]['id']
        self.assertTrue(self.b.history(imported)[0]['time'].endswith('Z'))
        from cloud_replica import decode_documents
        for entity, rows in decode_documents(self.sb.client.shared_changes({})[0]).items():
            for data,_ in rows.values():
                for key,value in data.items(): firestore_value(value,key)

    def test_destination_change_discards_old_remote_versions(self):
        player=self.a.add_player('Migrar projeto')
        self.cycle(self.sa)
        self.a.outbox.bind('projeto-antigo','operador')
        self.a.outbox.bind('projeto-novo','operador',allow_change=True)
        self.assertTrue(all(row['version'] is None for row in self.a.db.execute('SELECT version FROM cloud_records')))
        new_server=SharedServer()
        self.cycle(SharedSync(self.a,new_server.client()))
        self.assertEqual(len(new_server.documents['players']),1)

    def test_offline_queue_survives_database_close_and_reopen(self):
        player=self.a.add_player('Persistência offline')
        session=self.a.session(player)
        self.a.result(self.a.move(session,Event(0,0)),False)
        self.server.online=False
        with self.assertRaises(FirebaseError): self.sa.cycle()
        self.a.close()
        reopened=PlayerStore(Path(self.temp.name)/'a.sqlite3')
        try:
            self.assertGreater(reopened.outbox.count(),0)
            self.server.online=True
            self.cycle(SharedSync(reopened,self.server.client()));self.cycle(self.sb)
            self.assertEqual(summarize(self.b.history(self.b.players()[0]['id'])),(1,0,0.0))
            self.assertEqual(reopened.outbox.count(),0)
        finally: reopened.close()
