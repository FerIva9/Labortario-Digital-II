"""Defaults portáveis, credenciais locais e reconexão, sem acesso à rede/cofre real."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from cloud_credentials import CredentialUnavailable, CredentialVault
from cloud_firebase import CloudConfig, FirestoreClient, SyncWorker, FirebaseError
from cloud_preferences import CloudPreferences
from player_store import PlayerStore
from protocol import Event
import runtime_paths

CONFIG = CloudConfig('fabula-teste', 'chave-publica-ficticia', 'operador123')


class MemoryVaultBackend:
    def __init__(self):
        self.values = {}

    def get_password(self, service, account):
        return self.values.get((service, account))

    def set_password(self, service, account, value):
        self.values[service, account] = value

    def delete_password(self, service, account):
        del self.values[service, account]


class PortableSettingsTests(unittest.TestCase):
    def test_new_windows_installation_loads_bundled_defaults_and_keeps_override(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            bundle = base / 'bundle'
            bundle.mkdir()
            CONFIG.save(bundle / 'firebase_defaults.json')
            with patch.object(runtime_paths, 'FROZEN', True), patch.object(runtime_paths, 'BUNDLE_DIR', bundle), patch.dict('os.environ', {'LOCALAPPDATA': str(base / 'user'), 'FABULA_FIREBASE_CONFIG': ''}):
                local = runtime_paths.cloud_config_path()
                self.assertEqual(local, base/'user/FabulaTEA/firebase_config.json')
                self.assertEqual(CloudConfig.load_active(), CONFIG)
                changed = CloudConfig('outro-projeto', 'outra-chave', 'operador123', 120)
                changed.save(local)
                self.assertEqual(CloudConfig.load_active(), changed)
                CONFIG.save(bundle / 'firebase_defaults.json')
                self.assertEqual(CloudConfig.load_active(), changed)

    def test_invalid_local_config_is_not_silently_replaced_by_default(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            CONFIG.save(base/'default.json')
            (base/'local.json').write_text('{"password":"nao-permitido"}')
            with self.assertRaises(ValueError):
                CloudConfig.load_active(base/'local.json', base/'default.json')

    def test_pause_and_account_preferences_survive_restart_without_secrets(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'preferences.json'
            self.assertTrue(CloudPreferences.load(path).automatic)
            prefs = CloudPreferences(False, True, 'responsavel@exemplo.test')
            prefs.save(path)
            self.assertEqual(CloudPreferences.load(path), prefs)
            self.assertNotIn('password', path.read_text())
            self.assertNotIn('token', path.read_text())

    def test_explicit_destination_change_requeues_existing_data(self):
        with tempfile.TemporaryDirectory() as directory:
            store = PlayerStore(Path(directory)/'store.db')
            player = store.add_player('Teste')
            store.move(store.session(player), Event(2, 3))
            store.outbox.bind('fabula-teste', 'operador123')
            store.outbox.acknowledge(store.outbox.pending())
            self.assertEqual(store.outbox.count(), 0)
            store.outbox.bind('novo-projeto', 'operador123', allow_change=True)
            self.assertEqual({r['entity'] for r in store.outbox.pending()}, {'players','sessions','moves'})
            with self.assertRaises(ValueError):
                store.outbox.bind('terceiro-projeto', 'operador123')
            store.close()


class SavedSessionTests(unittest.TestCase):
    def setUp(self):
        self.backend = MemoryVaultBackend()
        self.vault = CredentialVault(self.backend)

    def test_token_survives_new_vault_instance_and_is_scoped_to_account(self):
        self.vault.save(CONFIG, 'refresh-ficticio')
        other = CredentialVault(self.backend)
        self.assertEqual(other.load(CONFIG), 'refresh-ficticio')
        self.assertIsNone(other.load(CloudConfig('outro-projeto', 'key', 'outro')))
        other.delete(CONFIG)
        self.assertIsNone(other.load(CONFIG))

    def test_plaintext_backend_is_rejected(self):
        backend = type('PlaintextKeyring', (), {'__module__': 'keyrings.alt.file', 'priority': 1})()
        with patch('keyring.get_keyring', return_value=backend):
            with self.assertRaises(CredentialUnavailable):
                CredentialVault().load(CONFIG)

    def test_automatic_login_uses_refresh_token_without_password(self):
        self.vault.save(CONFIG, 'refresh-ficticio')
        worker = SyncWorker('unused.db', CONFIG, remember=True, vault=self.vault)
        client = Mock()
        client._refresh_token = 'refresh-renovado'
        self.assertTrue(worker._authenticate(client))
        client.restore.assert_called_once_with('refresh-ficticio')
        client.sign_in.assert_not_called()
        self.assertEqual(self.vault.load(CONFIG), 'refresh-renovado')
        self.assertIsNone(worker._password)

    def test_unchecking_remember_removes_saved_session_after_login(self):
        self.vault.save(CONFIG, 'acesso-anterior')
        worker = SyncWorker('unused.db', CONFIG, 'email', 'senha', remember=False,
                            forget_saved=True, vault=self.vault)
        self.assertTrue(worker._authenticate(Mock()))
        self.assertIsNone(self.vault.load(CONFIG))

    def test_no_saved_session_falls_back_locally_without_network(self):
        worker = SyncWorker('unused.db', CONFIG, remember=True, vault=self.vault)
        client = Mock()
        self.assertFalse(worker._authenticate(client))
        client.restore.assert_not_called()
        client.sign_in.assert_not_called()

    def test_initial_offline_login_recovers_automatically(self):
        self.vault.save(CONFIG, 'refresh-ficticio')
        worker = SyncWorker('unused.db', CONFIG, remember=True, vault=self.vault)
        worker._stop.wait = Mock(return_value=False)
        client = Mock()
        client._refresh_token = 'refresh-renovado'
        client.restore.side_effect = [FirebaseError('Sem internet', retryable=True), None]
        self.assertTrue(worker._authenticate(client))
        self.assertEqual(client.restore.call_count, 2)
        worker._stop.wait.assert_called_once_with(3)

    def test_missing_secure_store_does_not_break_current_connection(self):
        unavailable = Mock()
        unavailable.save.side_effect = CredentialUnavailable('Sem cofre')
        worker = SyncWorker('unused.db', CONFIG, 'email', 'senha', remember=True, vault=unavailable)
        client = Mock()
        client._refresh_token = 'refresh-ficticio'
        self.assertTrue(worker._authenticate(client))
        self.assertIn('cofre indisponível', worker._credential_notice)
        self.assertIsNone(worker._password)

    def test_restored_token_validates_uid_and_checks_operator(self):
        transport = Mock(side_effect=[
            {'user_id': CONFIG.operator_uid, 'id_token': 'id-ficticio', 'refresh_token': 'refresh-renovado', 'expires_in': '3600'},
            {'fields': {'enabled': {'booleanValue': True}}}])
        client = FirestoreClient(CONFIG, transport)
        client.restore('refresh-ficticio')
        self.assertEqual(client.token(), 'id-ficticio')
        self.assertEqual(transport.call_count, 2)
        self.assertIn('/operators/operador123', transport.call_args.args[1])


class AutomaticStartupTests(unittest.TestCase):
    def app(self):
        from app import App
        app = App.__new__(App)
        app.cloud_worker = app.cloud_dialog = None
        app.db_path = 'unused.db'
        app.cloud_active = False
        app.cloud_preferences = CloudPreferences()
        app.root = Mock()
        app.store = Mock()
        app.cloud_menu = Mock()
        app.cloud_automatic_var = Mock()
        return app

    def test_enable_automatic_also_remembers_login_and_survives_restart(self):
        app = self.app()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'prefs.json'
            CloudPreferences(False, False).save(path)
            with patch('app.cloud_preferences_path', return_value=path), patch('app.CloudConfig.load_active', return_value=CONFIG), patch('app.SyncWorker') as worker:
                app.pause_cloud()
                self.assertFalse(CloudPreferences.load(path).automatic)
                app.resume_cloud()
            self.assertTrue(CloudPreferences.load(path).automatic)
            self.assertTrue(CloudPreferences.load(path).remember_login)
            worker.return_value.start.assert_called_once()

    def test_pause_then_enable_waits_for_old_worker_and_restarts_once(self):
        app = self.app()
        old = app.cloud_worker = Mock()
        old.stopping = True
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'prefs.json'
            with patch('app.cloud_preferences_path', return_value=path), patch('app.CloudConfig.load_active', return_value=CONFIG), patch('app.SyncWorker') as worker:
                app.resume_cloud()
                worker.assert_not_called()
                app.root.after.assert_called_once_with(100, app.finish_cloud_resume)
                old.thread.is_alive.return_value = False
                app.finish_cloud_resume()
                worker.assert_called_once()
                worker.return_value.start.assert_called_once()

    def test_pause_cancels_a_pending_resume(self):
        app = self.app()
        app.cloud_preferences.automatic = False
        with patch('app.SyncWorker') as worker:
            app.finish_cloud_resume()
        worker.assert_not_called()

    def test_duplicate_resume_callback_does_not_wait_for_a_healthy_worker(self):
        app = self.app()
        app.cloud_worker = Mock()
        app.cloud_worker.stopping = False
        with patch('app.SyncWorker') as worker:
            app.finish_cloud_resume()
        worker.assert_not_called()
        app.root.after.assert_not_called()

    def test_enable_running_worker_persists_access_without_parallel_worker(self):
        app = self.app()
        app.cloud_worker = Mock()
        app.cloud_worker.stopping = False
        with tempfile.TemporaryDirectory() as directory:
            with patch('app.cloud_preferences_path', return_value=Path(directory)/'prefs.json'), patch('app.SyncWorker') as worker:
                app.resume_cloud()
            worker.assert_not_called()
        app.cloud_worker.request_sync.assert_called_once_with(remember=True)
        self.assertTrue(app.cloud_active)

    def test_pending_data_wakes_worker_without_waiting_for_periodic_interval(self):
        import queue
        app = self.app()
        app.cloud_active = True
        app.cloud_worker = Mock()
        app.cloud_worker.stopping = False
        app.cloud_worker.events = queue.Queue()
        app.store.outbox.count.return_value = 3
        app.poll_cloud()
        app.cloud_worker.request_sync.assert_called_once_with()
        self.assertIn('3 documentos pendentes', app.cloud_status)
        app.root.after.assert_called_once_with(500, app.poll_cloud)

    def test_startup_launches_saved_session_without_opening_dialog(self):
        app = self.app()
        with patch('app.CloudPreferences.load', return_value=CloudPreferences()), patch('app.CloudConfig.load_active', return_value=CONFIG), patch('app.SyncWorker') as worker:
            app.start_auto_sync()
        worker.assert_called_once_with('unused.db', CONFIG, remember=True)
        worker.return_value.start.assert_called_once()
        self.assertTrue(app.cloud_active)
        self.assertIsNone(app.cloud_dialog)

    def test_paused_or_unremembered_login_stays_local(self):
        for prefs in [CloudPreferences(False), CloudPreferences(True, False)]:
            app = self.app()
            with patch('app.CloudPreferences.load', return_value=prefs), patch('app.SyncWorker') as worker:
                app.start_auto_sync()
            worker.assert_not_called()
            self.assertIn('local', app.cloud_status)

    def test_configuration_dialog_prevents_parallel_auto_worker(self):
        app = self.app()
        app.cloud_dialog = Mock()
        app.cloud_dialog.winfo_exists.return_value = True
        with patch('app.SyncWorker') as worker:
            app.start_auto_sync()
        worker.assert_not_called()
