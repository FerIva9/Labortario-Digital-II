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
