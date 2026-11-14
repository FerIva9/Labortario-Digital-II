"""Diagnóstico explícito do pacote, sem acessar o histórico local do usuário."""
import contextlib
import sys
from pathlib import Path


def main(report_path):
    with Path(report_path).open('w', encoding='utf-8') as report:
        with contextlib.redirect_stdout(report), contextlib.redirect_stderr(report):
            try:
                import json
                import tkinter as tk
                from PIL import Image, ImageTk
                from runtime_paths import CATALOG_PATH, image_path
                root = tk.Tk()
                root.withdraw()
                try:
                    catalog = json.loads(CATALOG_PATH.read_text(encoding='utf-8'))
                    count = 0
                    for story in catalog.values():
                        for character in story['personagens']:
                            with Image.open(image_path(character['imagem'])) as image:
                                photo = ImageTk.PhotoImage(image, master=root)
                                assert photo.width() > 0
                            count += 1
                    root.update()
                    print(f'OK: Tkinter, catálogo e {count} imagens do pacote.')
                finally:
                    root.destroy()
                from tools.check_performance import main as check_performance
                check_performance()
                # O teste usa instalação temporária e remove apenas seus dados fictícios.
                from tools.check_cloud_integration import main as check_cloud
                sys.argv = [sys.argv[0], '--run-live', '--saved-access']
                return check_cloud()
            except Exception as error:
                from cloud_firebase import FirebaseError
                from cloud_credentials import CredentialUnavailable
                if isinstance(error, (FirebaseError, CredentialUnavailable)):
                    print(f'Falha: {error}')
                else:
                    print(f'Falha local no diagnóstico: {type(error).__name__}.')
                return 1
