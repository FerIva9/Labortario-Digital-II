"""Verificação gráfica opcional: python tools/check_layout.py (abre janelas)."""
import sys
from pathlib import Path
import io
import csv
import tempfile
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import tkinter as tk
from app import App
from protocol import Event, Result

for scale in (1.33, 1.67, 2.0, 2.67):
    root = tk.Tk()
    root.tk.call('tk', 'scaling', scale)
    temporary = tempfile.TemporaryDirectory()
    with patch('app.records_dir', return_value=Path(temporary.name)):
        app = App(root)
    root.update()
    assert app.login_view.winfo_ismapped()
    assert not app.main_view.winfo_ismapped()
    assert str(app.start_session_button['state']) == 'disabled'
    for width, height in ((1240, 900), (1024, 650), (800, 600)):
        root.geometry(f'{width}x{height}+0+0')
        root.update()
        assert app.login_view.winfo_width() == root.winfo_width()
        for control in (app.login_search_entry, app.start_session_button, app.profile_options):
            assert control.winfo_x() >= 0
            assert control.winfo_x() + control.winfo_width() <= control.master.winfo_width()
    app.show_profile_editor()
    root.update()
    assert app.profile_editor.winfo_ismapped()
    app.new_player_name.set('Jogador de teste')
    app.add_player()
    assert app.session_id is None
    app.new_session()
    assert app.session_id is not None
    root.update()
    assert not app.login_view.winfo_ismapped()
    assert app.main_view.winfo_ismapped()
    app.log_file = io.StringIO()
    app.writer = csv.writer(app.log_file)
    for width, height in ((1240, 900), (1024, 650), (800, 600)):
        root.geometry(f'{width}x{height}+0+0')
        root.update()
        if not app.details.winfo_manager():
            app.toggle_details()
        app.present(Event(3, 3), 'Demonstração')
        for _ in range(8):
            root.update_idletasks()
            root.update()
        for widget in (app.demo_button, app.connect_button, app.details_button, app.name_label, app.status_label):
            parent = widget.master
            assert widget.winfo_x() >= 0, (scale, width, widget, 'left')
            assert widget.winfo_x() + widget.winfo_width() <= parent.winfo_width() + 2, (scale, width, widget, 'right', widget.winfo_width(), parent.winfo_width())
            assert widget.winfo_y() + widget.winfo_height() <= parent.winfo_height() + 2, (scale, width, widget, 'bottom')
        assert app.photo is not None
        assert app.gallery_columns >= 1
        for card in app.cards:
            assert card.winfo_x() + card.winfo_width() <= app.gallery.winfo_width() + 2, (scale, width, 'card cropped')
        app.main_view.canvas.yview_moveto(1)
        app.sidebar_view.canvas.yview_moveto(1)
        root.update()
        app.toggle_details()
        root.update()
        app.toggle_presentation()
        root.update()
        app.present(Event(1, 1), 'Serial')
        assert app.presentation_mode and app.photo is not None
        app.exit_presentation()
        root.update()
        print(f'OK escala Tk {scale}: {width}x{height}', flush=True)
    app.present(Event(2, 3), 'Serial')
    app.receive_result(Result(True))
    old_player = app.player_id
    old_session = app.session_id
    app.end_session()
    settled = tk.BooleanVar(root, False)
    root.after(250, lambda: settled.set(True))
    root.wait_variable(settled)
    root.update()
    assert app.login_view.winfo_ismapped()
    assert app.session_id is None and app.player_id is None
    assert app.current_event is None and app.pending_move is None
    assert len(app.store.history(old_player)) >= 1
    app.new_session()
    assert app.session_id != old_session
    assert app.player_id == old_player
    app.end_session()
    app.show_profile_editor(rename=True)
    app.new_player_name.set('Nome atualizado')
    app.save_profile()
    assert app.store.players()[0]['name'] == 'Nome atualizado'
    assert len(app.store.history(old_player)) >= 1
    with patch('app.messagebox.askyesno', return_value=False):
        app.delete_player()
    assert len(app.store.players()) == 1
    with patch('app.messagebox.askyesno', return_value=True):
        app.delete_player()
    assert not app.store.players()
    assert not app.store.history(old_player)
    assert str(app.start_session_button['state']) == 'disabled'
    assert str(app.profile_options['state']) == 'disabled'
    for job in root.tk.call('after', 'info'):
        root.after_cancel(job)
    app.close()
    temporary.cleanup()
