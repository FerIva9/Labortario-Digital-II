"""Acesso portátil privado: pacote privado de origem e bootstrap incorporado pelo gerador Windows."""
import json
import os
from pathlib import Path

from cloud_credentials import CredentialUnavailable, CredentialVault
from runtime_paths import APP_DIR, BUNDLE_DIR, FROZEN, records_dir


def private_dir():
    return (records_dir().parent if FROZEN else APP_DIR) / '.firebase-private'


def read_access(directory=None):
    from cryptography.fernet import Fernet, InvalidToken
    if directory is None:
        directory = private_dir()
        if not directory.exists() and FROZEN:
            directory = BUNDLE_DIR / '.firebase-bootstrap'
    directory = Path(directory)
    if not directory.exists():
        return None
    try:
        payload = Fernet((directory / 'access.key').read_bytes()).decrypt(
            (directory / 'access.enc').read_bytes())
        data = json.loads(payload)
        from cloud_firebase import CloudConfig
        CloudConfig(**data['config']).validate()
        if not isinstance(data['refresh_token'], str) or not data['refresh_token']:
            raise ValueError()
        return data
    except (OSError, ValueError, KeyError, TypeError, InvalidToken):
        raise CredentialUnavailable('Acesso portátil inválido ou chave privada ausente.') from None


def write_access(config, token, directory=None):
    from cryptography.fernet import Fernet
    from dataclasses import asdict
    directory = Path(directory) if directory is not None else private_dir()
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    key_path = directory / 'access.key'
    if not key_path.exists():
        fd = os.open(key_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(Fernet.generate_key())
    encrypted = Fernet(key_path.read_bytes()).encrypt(json.dumps(
        {'config': asdict(config), 'refresh_token': token}).encode())
    temp = directory / 'access.tmp'
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'wb') as stream:
        stream.write(encrypted)
    temp.replace(directory / 'access.enc')


class PortableVault:
    """Prioriza o cofre; permite bootstrap privado sem armazenar a senha."""
    def __init__(self):
        self.vault = CredentialVault()

    def load(self, config):
        try:
            token = self.vault.load(config)
            if token:
                return token
        except CredentialUnavailable:
            pass
        data = read_access()
        if data is None:
            return None
        if data['config']['project_id'] != config.project_id or data['config']['operator_uid'] != config.operator_uid:
            return None
        return data['refresh_token']

    def save(self, config, token):
        saved = False
        try:
            self.vault.save(config, token)
            saved = True
        except CredentialUnavailable:
            pass
        try:
            data = read_access()
            if data and data['config']['project_id'] == config.project_id and data['config']['operator_uid'] == config.operator_uid:
                write_access(config, token)
                saved = True
        except (CredentialUnavailable, OSError):
            pass
        if not saved:
            raise CredentialUnavailable('Não foi possível salvar a autorização no cofre ou no pacote privado.')

    def delete(self, config):
        data = read_access()
        if private_dir().is_dir() and data and data['config']['project_id'] == config.project_id and data['config']['operator_uid'] == config.operator_uid:
            (private_dir() / 'access.enc').unlink()
            (private_dir() / 'access.key').unlink()
            if not any(private_dir().iterdir()):
                private_dir().rmdir()
            # O bootstrap embutido é imutável; a preferência de lembrar controla seu uso.
        try:
            self.vault.delete(config)
        except CredentialUnavailable:
            if not data:
                raise
