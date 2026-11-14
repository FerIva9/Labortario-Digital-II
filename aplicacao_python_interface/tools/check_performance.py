"""Verifica filtros, gráficos, exportação e atualização assíncrona com dados fictícios."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def main():
    import csv
    import json
    import tempfile
    import time
    import tkinter as tk
    from types import SimpleNamespace
    from unittest.mock import patch
    from player_store import PlayerStore
    from protocol import Event
    from performance_view import PerformanceWindow
    from cloud_firebase import CloudConfig, firestore_value
    from runtime_paths import CATALOG_PATH
    from performance_data import local_snapshot

    with tempfile.TemporaryDirectory() as folder:
        store = PlayerStore(Path(folder) / 'check.sqlite3')
        root = tk.Tk()
        root.withdraw()
        window = None
        try:
            player = store.add_player('=Paciente fictício')
            session = store.session(player)
            store.result(store.move(session, Event(0, 1)), True)
            store.result(store.move(session, Event(0, 1)), False)
            store.move(session, Event(1, 0))
            app = SimpleNamespace(root=root, store=store, catalog=json.loads(CATALOG_PATH.read_text(encoding='utf-8')))
            window = PerformanceWindow(app)
            for width, height in ((1180, 760), (1024, 650), (800, 600)):
                window.window.geometry(f'{width}x{height}')
                root.update()
                assert len(window.tables['Jogadas'].get_children()) == 3
                assert window.current['totals']['accuracy'] == 50
                assert window.current['totals']['missing'] == 1
            first_player = window.tables['Jogadores'].get_children()[0]
            window.tables['Jogadores'].selection_set(first_player)
            window.open_player()
            assert window.player_keys[window.player.get()] == (store.outbox.installation_id, player)
            assert len(window.tables['Sessões'].get_children()) == 1
            window.story.set(window.combos[2]['values'][1])
            window.apply()
            assert len(window.tables['Jogadas'].get_children()) == 2
            path = Path(folder) / 'export.csv'
            with patch('performance_view.filedialog.asksaveasfilename', return_value=str(path)):
                window.export()
            with path.open(encoding='utf-8-sig', newline='') as stream:
                exported = list(csv.reader(stream))
            assert len(exported) == 3
            assert exported[1][0].startswith("'=")
            window.reset()
            snapshot = local_snapshot(store)
            docs = {key: [{'fields': {k: firestore_value(v, k) for k, v in dict(row, schema_version=1).items()}}
                          for row in rows] for key, rows in snapshot.items()}
            fake_client = SimpleNamespace(restore=lambda token: None, _refresh_token='fake-refresh', performance_documents=lambda: docs)
            fake_vault = SimpleNamespace(load=lambda cfg: 'fake-token', save=lambda cfg, token: None)
            with patch('performance_view.CloudConfig.load_active', return_value=CloudConfig('projeto-teste', 'key', 'operator')), \
                 patch('performance_view.PortableVault', return_value=fake_vault), \
                 patch('performance_view.FirestoreClient', return_value=fake_client):
                window.load_remote()
                deadline = time.monotonic() + 5
                while window.loading and time.monotonic() < deadline:
                    root.update()
                    time.sleep(.01)
                assert not window.loading
                assert window.source == 'Firebase'
                assert window.current['totals']['accuracy'] == 50
                assert window.tables['Jogadores'].item(window.tables['Jogadores'].get_children()[0], 'values')[0] == '=Paciente fictício'
                assert window.tables['Sessões'].item(window.tables['Sessões'].get_children()[0], 'values')[0] == '=Paciente fictício'
                assert window.tables['Jogadas'].item(window.tables['Jogadas'].get_children()[0], 'values')[0] == '=Paciente fictício'
            previous = window.snapshot
            window.events.put(('error', 'Sem acesso HTTPS ao Firebase.'))
            deadline = time.monotonic() + 5
            while 'dados anteriores mantidos' not in window.status.get() and time.monotonic() < deadline:
                root.update()
                time.sleep(.01)
            assert window.snapshot is previous
            assert 'dados anteriores mantidos' in window.status.get()
            print('OK: painel em três tamanhos, filtros, sessões, gráfico, CSV, atualização assíncrona e falha de rede.')
            return 0
        finally:
            if window:
                window.close()
            store.close()
            root.destroy()


if __name__ == '__main__':
    raise SystemExit(main())
