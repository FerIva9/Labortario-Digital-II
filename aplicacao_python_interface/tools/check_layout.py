"""Verificação gráfica opcional: python tools/check_layout.py (abre janelas)."""
import sys
from pathlib import Path
import io
import csv
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import tkinter as tk
from app import App
from protocol import Event

for scale in (1.33, 1.67, 2.0, 2.67):
    root = tk.Tk()
    root.tk.call('tk', 'scaling', scale)
    app = App(root)
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
    for job in root.tk.call('after', 'info'):
        root.after_cancel(job)
    app.close()
