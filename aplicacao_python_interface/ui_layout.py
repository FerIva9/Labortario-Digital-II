"""Área rolável que mantém controles acessíveis em janelas pequenas."""
import tkinter as tk
from tkinter import ttk


class ScrollableFrame(tk.Frame):
    def __init__(self, parent, background, *, fit_content_width=False):
        super().__init__(parent, bg=background)
        self.fit_content_width = fit_content_width
        self.sync_job = None
        self.canvas = tk.Canvas(self, bg=background, highlightthickness=0, width=1, height=1)
        self.scrollbar = ttk.Scrollbar(self, orient='vertical', command=self.canvas.yview)
        self.canvas.configure(yscrollcommand=self.scrollbar.set)
        self.canvas.grid(row=0, column=0, sticky='nsew')
        self.rowconfigure(0, weight=1)
        self.columnconfigure(0, weight=1)
        self.content = tk.Frame(self.canvas, bg=background)
        self.window = self.canvas.create_window(0, 0, anchor='nw', window=self.content)
        self.content.bind('<Configure>', self.schedule_sync)
        self.canvas.bind('<Configure>', self.schedule_sync)
        parent.winfo_toplevel().bind('<Configure>', self.schedule_sync, add='+')
        parent.winfo_toplevel().bind('<MouseWheel>', self.scroll, add='+')
        parent.winfo_toplevel().bind('<Button-4>', self.scroll, add='+')
        parent.winfo_toplevel().bind('<Button-5>', self.scroll, add='+')

    def schedule_sync(self, event):
        widget = event.widget
        while widget is not None and widget not in (self.content, self.canvas):
            widget = getattr(widget, 'master', None)
        if widget is not None and self.sync_job is None:
            self.sync_job = self.after_idle(self.sync)

    def sync(self):
        self.sync_job = None
        width = max(1, self.canvas.winfo_width())
        height = max(self.canvas.winfo_height(), self.content.winfo_reqheight())
        self.canvas.itemconfigure(self.window, width=width, height=height)
        self.canvas.configure(scrollregion=(0, 0, width, height))
        if self.fit_content_width:
            requested = self.content.winfo_reqwidth()
            if int(self.canvas.cget('width')) != requested:
                self.canvas.configure(width=requested)
        if height > self.canvas.winfo_height() + 1:
            self.scrollbar.grid(row=0, column=1, sticky='ns')
        else:
            self.scrollbar.grid_remove()
            self.canvas.yview_moveto(0)

    def scroll(self, event):
        # Respeita a rolagem própria da tabela e não afeta o outro painel.
        widget = event.widget
        if isinstance(widget, (ttk.Treeview, ttk.Combobox)):
            return
        while widget is not None and widget is not self:
            widget = getattr(widget, 'master', None)
        if widget is None or not self.scrollbar.winfo_ismapped():
            return
        if getattr(event, 'num', None) == 4:
            units = -1
        elif getattr(event, 'num', None) == 5:
            units = 1
        else:
            delta = getattr(event, 'delta', 0)
            if not delta:
                return
            units = -int(delta / 120) if abs(delta) >= 120 else (-1 if delta > 0 else 1)
        self.canvas.yview_scroll(units, 'units')
        return 'break'
