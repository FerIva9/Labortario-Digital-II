"""O diagnóstico real não pode migrar nem alterar registros alheios ao ensaio."""
import unittest
from unittest.mock import Mock
from tools.check_shared_integration import scope_test_client


class LiveScopeTests(unittest.TestCase):
    def setUp(self):
        self.scope = dict(player='fixture', players=set(), sessions=set(), moves=set())
        self.client = Mock()
        self.commit = self.client.commit_shared
        self.performance = self.client.performance_documents
        self.read = self.client.shared_changes
        scope_test_client(self.client, self.scope)

    def test_reads_only_fixture_and_keeps_its_deletion_marker(self):
        self.read.return_value = ({'players': [
            {'name': 'players/fixture', 'fields': {}}, {'name': 'players/real', 'fields': {}}],
            'sessions': [{'name': 'sessions/own', 'fields': {'player_id': {'stringValue': 'fixture'}}},
                         {'name': 'sessions/other', 'fields': {'player_id': {'stringValue': 'real'}}}],
            'moves': []}, {'players': 'cursor'})
        documents, cursors = self.client.shared_changes({})
        self.assertEqual([r['name'] for r in documents['players']], ['players/fixture'])
        self.assertEqual([r['name'] for r in documents['sessions']], ['sessions/own'])
        self.assertEqual(cursors, {'players': 'cursor'})
        self.read.return_value = ({'players': [], 'sessions': [{'name': 'sessions/own', 'fields': {'deleted': {'booleanValue': True}}}], 'moves': []}, {})
        self.assertEqual(len(self.client.shared_changes({})[0]['sessions']), 1)

    def test_blocks_entire_mixed_batch_and_unknown_deletion(self):
        own = dict(entity='players', remote_id='fixture', data={'deleted': False})
        other = dict(entity='players', remote_id='real', data={'deleted': False})
        with self.assertRaises(RuntimeError):
            self.client.commit_shared([own, other])
        self.commit.assert_not_called()
        self.assertFalse(self.scope['players'])
        with self.assertRaises(RuntimeError):
            self.client.commit_shared([dict(entity='sessions', remote_id='real', data={'deleted': True})])
        self.client.commit_shared([own])
        self.client.commit_shared([dict(own, data={'deleted': True})])
        self.assertEqual(self.commit.call_count, 2)

    def test_never_loads_legacy_history_and_requires_fixture_identity(self):
        self.assertEqual(self.client.performance_documents(legacy_only=True), {'players': [], 'sessions': [], 'moves': []})
        self.performance.assert_not_called()
        self.scope['player'] = None
        with self.assertRaises(RuntimeError):
            self.client.shared_changes({})
        self.read.assert_not_called()
