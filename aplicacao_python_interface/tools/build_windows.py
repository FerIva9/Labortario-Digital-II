"""Reconstrói o executável completo a partir do código atual. Execute no Windows."""
from pathlib import Path
import json
import subprocess
import sys
import venv

BASE = Path(__file__).resolve().parents[1]


def run(args):
    subprocess.run([str(arg) for arg in args], cwd=BASE, check=True)


def validate_private_access():
    """Falha antes de empacotar se o acesso privado falta, está corrompido ou diverge."""
    from cloud_firebase import CloudConfig
    from cloud_portable import read_access
    from cloud_credentials import CredentialUnavailable
    try:
        data = read_access(BASE / '.firebase-private')
        config = CloudConfig.load(BASE / 'firebase_defaults.json')
        if data is None or CloudConfig(**data['config']) != config:
            raise ValueError()
    except (CredentialUnavailable, ValueError, OSError):
        raise SystemExit('Acesso privado ausente, inválido ou diferente do padrão. Execute tools/prepare_private_access.py antes de gerar.') from None


def main():
    if sys.platform != 'win32':
        raise SystemExit('O executável Windows deve ser gerado no Windows. Copie esta pasta e execute gerar_windows.cmd.')
    if sys.version_info < (3, 10):
        raise SystemExit('Instale Python 3.10 ou superior, com Tcl/Tk e pip.')
    environment = BASE / '.venv-build'
    python = environment / 'Scripts' / 'python.exe'
    if not python.exists():
        venv.EnvBuilder(with_pip=True).create(environment)
    run([python, '-m', 'pip', 'install', '-r', BASE / 'requirements-build.txt'])
    run([python, '-m', 'unittest', 'discover', '-s', 'tests', '-v'])
    # Importar tkinter não detecta a ausência dos scripts Tcl usados pelo pacote.
    run([python, '-c', 'import tkinter; tkinter.Tcl(); import serial.tools.list_ports; from PIL import ImageTk'])
    run([python, '-c', 'from cloud_firebase import CloudConfig; CloudConfig.load("firebase_defaults.json")'])
    run([python, '-c', 'from tools.build_windows import validate_private_access; validate_private_access()'])
    datas = ['--add-data', f'{BASE / "historias.json"}:.',
             '--add-data', f'{BASE / "firebase_defaults.json"}:.']
    for name in ('access.key', 'access.enc'):
        datas += ['--add-data', f'{BASE / ".firebase-private" / name}:.firebase-bootstrap']
    catalog = json.loads((BASE / 'historias.json').read_text(encoding='utf-8'))
    images = {character['imagem'] for story in catalog.values()
              for character in story['personagens'] if character.get('imagem')}
    for relative in sorted(images):
        image = (BASE / relative).resolve()
        if not image.is_relative_to(BASE) or not image.is_file():
            raise SystemExit(f'Imagem ausente ou fora da pasta do projeto: {relative}')
        destination = image.relative_to(BASE).parent.as_posix()
        datas += ['--add-data', f'{image}:{destination}']
    run([python, '-m', 'PyInstaller', '--noconfirm', '--clean', '--onefile', '--windowed',
         '--manifest', BASE / 'windows.manifest',
         '--name', 'FabulaTEA', '--hidden-import', 'serial.tools.list_ports_windows',
         '--hidden-import', 'keyring.backends.Windows', '--collect-all', 'keyring',
         *datas, BASE / 'app.py'])
    print('Acesso incorporado: copie somente FabulaTEA.exe para outro computador autorizado.')
    print(f'\nPronto: {BASE / "dist" / "FabulaTEA.exe"}')
    print('Feche a versão anterior e substitua o executável por este arquivo.')


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(f'Geração interrompida: comando retornou código {error.returncode}. Veja o erro acima.')
