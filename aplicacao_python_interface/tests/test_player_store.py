import tempfile
import unittest
from pathlib import Path
from player_store import PlayerStore, summarize
from protocol import Event, Result, Decoder


class PlayerTests(unittest.TestCase):
    def test_persistence_isolation_and_denominator(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'players.db'
            store = PlayerStore(path)
            first = store.add_player('Ana')
            second = store.add_player('Ana')
            session = store.session(first)
            a = store.move(session, Event(2, 3))
            b = store.move(session, Event(2, 3))
            store.move(session, Event(1, 0))
            self.assertTrue(store.result(a, True))
            self.assertFalse(store.result(a, False))
            store.result(b, False)
            self.assertEqual(summarize(store.history(first)), (2, 1, 50.0))
            self.assertEqual(summarize(store.history(second)), (0, 0, None))
            store.close()
            store = PlayerStore(path)
            self.assertEqual(summarize(store.history(first)), (2, 1, 50.0))
            store.close()

    def test_results_fragmented_and_repeated(self):
        decoder = Decoder()
        self.assertEqual(decoder.feed(b'H2,P3\nR'), [Event(2, 3)])
        self.assertEqual(decoder.feed(b'1\nH2,P3\r\nR0\r\n'), [Result(True), Event(2, 3), Result(False)])
        self.assertIsInstance(decoder.feed(b'R2\n')[0], ValueError)

    def test_result_consumed_once_and_orphan_ignored(self):
        from unittest.mock import Mock
        from app import App
        with tempfile.TemporaryDirectory() as directory:
            store = PlayerStore(Path(directory) / 'players.db')
            player = store.add_player('Jogador')
            session = store.session(player)
            move = store.move(session, Event(2, 3))
            app = App.__new__(App)
            app.store = store
            app.pending_move = (move, 'row')
            app.history = Mock()
            app.history.exists.return_value = False
            app.code_label = Mock()
            app.status = Mock()
            app.refresh_stats = Mock()
            app.receive_result(Result(True))
            app.receive_result(Result(False))
            self.assertEqual(summarize(store.history(player)), (1, 1, 100.0))
            self.assertIsNone(app.pending_move)
            app.refresh_stats.assert_called_once()
            store.close()

    def test_rename_preserves_history_and_rejects_invalid_names(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'players.db'
            store = PlayerStore(path)
            player = store.add_player('Ana')
            move = store.move(store.session(player), Event(1, 2))
            store.result(move, True)
            store.rename_player(player, '  Ana Maria  ')
            for invalid in (' ', 'x' * 81):
                with self.assertRaises(ValueError):
                    store.rename_player(player, invalid)
            store.close()
            store = PlayerStore(path)
            self.assertEqual(store.players()[0]['name'], 'Ana Maria')
            self.assertEqual(store.players()[0]['id'], player)
            self.assertEqual(summarize(store.history(player)), (1, 1, 100.0))
            store.close()

    def test_delete_only_selected_profile_and_related_history(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'players.db'
            store = PlayerStore(path)
            first = store.add_player('Ana')
            second = store.add_player('Ana')
            for player in (first, second):
                store.move(store.session(player), Event(2, 3))
            store.delete_player(first)
            self.assertEqual(store.history(first), [])
            self.assertEqual(len(store.history(second)), 1)
            self.assertEqual(store.db.execute('SELECT COUNT(*) FROM sessions WHERE player=?', (first,)).fetchone()[0], 0)
            self.assertEqual(store.db.execute('PRAGMA foreign_key_check').fetchall(), [])
            store.close()
            store = PlayerStore(path)
            self.assertEqual([p['id'] for p in store.players()], [second])
            store.close()
