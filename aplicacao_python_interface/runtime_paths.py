"""Separa recursos empacotados dos dados persistentes da aplicação."""
import os
from pathlib import Path
import sys

BUNDLE_DIR = Path(__file__).resolve().parent
FROZEN = getattr(sys, 'frozen', False)
APP_DIR = Path(sys.executable).resolve().parent if FROZEN else BUNDLE_DIR
CATALOG_PATH = APP_DIR / 'historias.json'
if not CATALOG_PATH.is_file():
    CATALOG_PATH = BUNDLE_DIR / 'historias.json'


def image_path(relative_path):
    custom = CATALOG_PATH.parent / relative_path
    return custom if custom.is_file() else BUNDLE_DIR / relative_path


def records_dir():
    if not FROZEN:
        return BUNDLE_DIR / 'registros'
    # Independente da pasta temporária do PyInstaller e da pasta de instalação.
    user_data = Path(os.environ.get('LOCALAPPDATA') or Path.home() / 'AppData' / 'Local')
    return user_data / 'FabulaTEA' / 'registros'


def cloud_config_path():
    """Configuração externa ao pacote, sem senha ou token."""
    override = os.environ.get('FABULA_FIREBASE_CONFIG')
    return Path(override).expanduser() if override else records_dir().parent / 'firebase_config.json'


def cloud_defaults_path():
    return BUNDLE_DIR / 'firebase_defaults.json'


def cloud_preferences_path():
    return records_dir().parent / 'firebase_preferences.json'
