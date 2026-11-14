"""Promove a configuração local atual para o padrão privado da instalação."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from cloud_firebase import CloudConfig
from runtime_paths import cloud_defaults_path


def main():
    config = CloudConfig.load_active()
    config.save(cloud_defaults_path())
    print(f'Padrão atualizado para o projeto {config.project_id}.')
    print('Transfira firebase_defaults.json por meio privado; não versione este arquivo.')
    print('Somente projeto, Web API Key, UID e intervalo foram incluídos; sem senha ou token.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError) as error:
        raise SystemExit(str(error))
