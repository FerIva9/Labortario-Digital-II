import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch

from cloud_firebase import CloudConfig
from cloud_credentials import CredentialUnavailable
from cloud_portable import read_access, write_access, PortableVault

CONFIG = CloudConfig('projeto-teste', 'chave-ficticia', 'operador')


class PortableTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name) / 'private'
        self.patcher = patch('cloud_portable.private_dir', return_value=self.directory)
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def test_encrypted_roundtrip_rotation_and_wrong_key(self):
        write_access(CONFIG, 'token-secreto-ficticio')
        self.assertNotIn(b'token-secreto-ficticio', (self.directory / 'access.enc').read_bytes())
        self.assertEqual(read_access()['refresh_token'], 'token-secreto-ficticio')
        write_access(CONFIG, 'token-novo')
        self.assertEqual(read_access()['refresh_token'], 'token-novo')
        from cryptography.fernet import Fernet
        (self.directory / 'access.key').write_bytes(Fernet.generate_key())
        with self.assertRaises(CredentialUnavailable):
            read_access()

    def test_offline_vault_fallback_scoping_rotation_and_forget(self):
        write_access(CONFIG, 'token-inicial')
        vault = PortableVault()
        with patch.object(vault.vault, '_backend', side_effect=CredentialUnavailable('indisponível')):
            self.assertEqual(vault.load(CONFIG), 'token-inicial')
            other = CloudConfig('outro-projeto', 'outra-chave', 'outro-operador')
            self.assertIsNone(vault.load(other))
            vault.save(CONFIG, 'token-renovado')
            self.assertEqual(read_access()['refresh_token'], 'token-renovado')
            vault.delete(CONFIG)
            self.assertIsNone(vault.load(CONFIG))

    def test_missing_private_package_returns_none(self):
        self.assertIsNone(read_access())

    def test_executable_without_external_folder_and_token_rotation(self):
        bundle = Path(self.temp.name) / 'bundle'
        embedded = bundle / '.firebase-bootstrap'
        write_access(CONFIG, 'token-embutido-ficticio', embedded)
        original = (embedded / 'access.enc').read_bytes()
        vault = PortableVault()
        with patch('cloud_portable.FROZEN', True), patch('cloud_portable.BUNDLE_DIR', bundle), patch.object(vault.vault, '_backend', side_effect=CredentialUnavailable('indisponível')):
            self.assertFalse(self.directory.exists())
            self.assertEqual(vault.load(CONFIG), 'token-embutido-ficticio')
            vault.save(CONFIG, 'token-renovado-local')
            self.assertEqual(vault.load(CONFIG), 'token-renovado-local')
            self.assertEqual((embedded / 'access.enc').read_bytes(), original)

    def test_builder_requires_private_package_and_matching_defaults(self):
        from tools import build_windows
        base = Path(self.temp.name) / 'build-source'
        base.mkdir()
        CONFIG.save(base / 'firebase_defaults.json')
        with patch.object(build_windows, 'BASE', base):
            with self.assertRaises(SystemExit):
                build_windows.validate_private_access()
            write_access(CONFIG, 'token-build-ficticio', base / '.firebase-private')
            build_windows.validate_private_access()
            CloudConfig('outro-projeto', 'outra-chave', 'outro-operador').save(base / 'firebase_defaults.json')
            with self.assertRaises(SystemExit):
                build_windows.validate_private_access()
