"""Prepara acesso privado portátil sem gravar a senha nem modificar dados clínicos."""
from getpass import getpass
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from cloud_firebase import CloudConfig, FirestoreClient, FirebaseError
from cloud_portable import PortableVault, write_access
from cloud_preferences import CloudPreferences
from runtime_paths import cloud_preferences_path, cloud_defaults_path
from cloud_credentials import CredentialUnavailable


def main():
    config = CloudConfig.load_active()
    if '--check' in sys.argv:
        vault = PortableVault()
        token = vault.load(config)
        if not token:
            raise ValueError('Acesso ausente')
        client = FirestoreClient(config)
        client.restore(token)
        vault.save(config, client._refresh_token)
        print('Autorização persistida restaurada e operador validado. Nenhum dado de jogador enviado.')
        return
    email = input('Email do operador: ').strip()
    password = getpass('Senha (não será gravada): ')
    client = FirestoreClient(config)
    try:
        client.sign_in(email, password)
    finally:
        password = None
    write_access(config, client._refresh_token)
    config.save(cloud_defaults_path())
    PortableVault().save(config, client._refresh_token)
    preferences = CloudPreferences(automatic=True, remember_login=True, email=email)
    preferences.save(cloud_preferences_path())
    print('Acesso validado e preparado. Senha não armazenada; nenhum dado de paciente foi enviado.')
    print('Transfira .firebase-private e firebase_defaults.json por meio privado para o Windows.')
    print('Não publique esses arquivos nem compartilhe o pacote com pessoas sem autorização.')


if __name__ == '__main__':
    try:
        main()
    except (FirebaseError, CredentialUnavailable, ValueError, OSError):
        raise SystemExit('Preparação interrompida: confira conexão, configuração e autorização da conta. Nenhuma credencial foi exibida.')
