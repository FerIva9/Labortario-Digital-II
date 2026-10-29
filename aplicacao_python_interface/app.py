"""Apresentador desktop Fábula TEA +. Execute: python app.py."""
import csv
import json
from datetime import datetime
import tkinter as tk
from tkinter import ttk, messagebox
from PIL import Image, ImageTk, ImageOps

from protocol import Decoder, Event
from runtime_paths import CATALOG_PATH, image_path, records_dir

LANCZOS = getattr(Image, 'Resampling', Image).LANCZOS


class App:
    def __init__(self, root):
        self.root = root
        self.catalog = json.loads(CATALOG_PATH.read_text(encoding='utf-8'))
        for story in range(4):
            item = self.catalog[str(story)]
            if len(item['personagens']) != 6:
                raise ValueError(f'História {story}: configure exatamente seis personagens.')
        self.connection = None
        self.decoder = Decoder()
        self.photo = None
        self.log_file = None
        self.writer = None
        self.count = 0
        self.current_event = None
        self.thumbnails = []
        self.cards = []
        self.image_cache = {}
        self.resize_job = None
        root.title('Fábula TEA + • Um mundo de histórias')
        root.geometry('1240x900')
        root.minsize(1000, 780)
        root.configure(bg='#f5f4f0')
        root.protocol('WM_DELETE_WINDOW', self.close)
        root.bind('<F11>', lambda _: root.attributes('-fullscreen', not root.attributes('-fullscreen')))
        root.bind('<Escape>', lambda _: root.attributes('-fullscreen', False))
        style = ttk.Style()
        style.theme_use('clam')
        style.configure('TCombobox', padding=7, font=('DejaVu Sans', 10), fieldbackground='white')
        style.configure('TButton', font=('DejaVu Sans', 10), padding=(12, 9), background='#edf0f3', borderwidth=0)
        style.map('TButton', background=[('active', '#dce5eb')])
        style.configure('Accent.TButton', background='#23665e', foreground='white')
        style.map('Accent.TButton', background=[('active', '#174e47'), ('disabled', '#cedbd8')])
        style.configure('Treeview', background='white', fieldbackground='white', foreground='#293d48', rowheight=30, borderwidth=0, font=('DejaVu Sans', 10))
        style.configure('Treeview.Heading', background='#eef2f3', foreground='#657780', font=('DejaVu Sans', 9, 'bold'), padding=8)
        style.map('Treeview', background=[('selected', '#d8ede7')], foreground=[('selected', '#183d35')])
        style.configure('TNotebook', background='#f5f4f0', borderwidth=0)
        style.configure('TNotebook.Tab', padding=(18, 9), background='#e9ece9', font=('DejaVu Sans', 10))
        style.map('TNotebook.Tab', background=[('selected', '#ffffff')])

        def label(parent, text='', size=10, color='#667c83', bg='#f5f4f0', bold=False, **kw):
            return tk.Label(parent, text=text, font=('DejaVu Sans', size, 'bold' if bold else 'normal'), fg=color, bg=bg, **kw)

        sidebar = tk.Frame(root, bg='#183e3a', width=260)
        sidebar.pack(side='left', fill='y')
        sidebar.pack_propagate(False)
        label(sidebar, 'FÁBULA', 24, '#ffffff', '#183e3a', True).pack(anchor='w', padx=25, pady=(30, 0))
        label(sidebar, 'TEA +', 16, '#a9d9c8', '#183e3a', True).pack(anchor='w', padx=27)
        label(sidebar, 'Um mundo de histórias', 10, '#b7cec8', '#183e3a').pack(anchor='w', padx=27, pady=(8, 30))
        tk.Frame(sidebar, height=1, bg='#365852').pack(fill='x', padx=25)
        label(sidebar, 'CONEXÃO COM A PLACA', 9, '#b7cec8', '#183e3a', True).pack(anchor='w', padx=25, pady=(25, 10))
        self.port = ttk.Combobox(sidebar, width=19)
        self.port.pack(fill='x', padx=25)
        ttk.Button(sidebar, text='Atualizar portas', command=self.refresh_ports).pack(fill='x', padx=25, pady=8)
        self.connect_button = ttk.Button(sidebar, text='Conectar', style='Accent.TButton', command=self.toggle_connection)
        self.connect_button.pack(fill='x', padx=25)
        label(sidebar, '115200 baud  ·  7E1', 9, '#b7cec8', '#183e3a').pack(anchor='w', padx=25, pady=12)
        tk.Frame(sidebar, height=1, bg='#365852').pack(fill='x', padx=25, pady=12)
        label(sidebar, 'EXPERIMENTAR UMA HISTÓRIA', 9, '#b7cec8', '#183e3a', True).pack(anchor='w', padx=25, pady=(12, 10))
        self.demo_story = ttk.Combobox(sidebar, values=[f'{i} — {self.catalog[str(i)]["nome"]}' for i in range(4)], state='readonly', width=19)
        self.demo_story.current(0)
        self.demo_story.pack(fill='x', padx=25)
        self.demo_story.bind('<<ComboboxSelected>>', lambda _: self.update_gallery())
        label(sidebar, 'Personagem', 10, '#b7cec8', '#183e3a').pack(anchor='w', padx=25, pady=(14, 5))
        self.demo_character = ttk.Combobox(sidebar, values=list(range(6)), state='readonly', width=19)
        self.demo_character.current(0)
        self.demo_character.pack(fill='x', padx=25)
        self.demo_button = ttk.Button(sidebar, text='Apresentar personagem', style='Accent.TButton', command=self.demo)
        self.demo_button.pack(fill='x', padx=25, pady=12)
        label(sidebar, 'Abra a galeria em\nMostrar cartões e histórico.', 9, '#b7cec8', '#183e3a', justify='left').pack(anchor='w', padx=25)
        label(sidebar, 'F11  Tela cheia\nEsc  Voltar à janela', 9, '#b7cec8', '#183e3a', justify='left').pack(side='bottom', anchor='w', padx=25, pady=25)

        panel = tk.Frame(root, bg='#f5f4f0', padx=18, pady=14)
        panel.pack(side='left', fill='both', expand=True)
        top = tk.Frame(panel, bg='#f5f4f0')
        top.pack(fill='x', pady=(0, 10))
        label(top, 'Hora de imaginar', 23, '#243e43', bold=True).pack(side='left')
        self.mode_label = label(top, '  EXPLORAR  ', 9, '#23665e', '#deeee7', True, padx=10, pady=7)
        self.mode_label.pack(side='right')
        stage = tk.Frame(panel, bg='white', highlightbackground='#e3e7e4', highlightthickness=1)
        stage.pack(fill='both', expand=True)
        self.story_label = label(stage, 'Escolha uma história', 11, '#637a7c', 'white', True)
        self.story_label.pack(pady=(10, 0))
        self.canvas = tk.Canvas(stage, height=280, bg='white', highlightthickness=0)
        self.canvas.pack(fill='both', expand=True, padx=4)
        self.canvas.bind('<Configure>', self.schedule_render)
        self.name_label = label(stage, 'Toda aventura começa com uma ideia', 22, '#243e43', 'white', True)
        self.name_label.pack(pady=(0, 4))
        self.code_label = label(stage, 'Escolha um cartão abaixo para começar.', 10, '#788a8d', 'white')
        self.code_label.pack(pady=(0, 10))

        self.details = tk.Frame(panel, bg='#f5f4f0')
        tabs = ttk.Notebook(self.details)
        tabs.pack(fill='x')
        gallery = tk.Frame(tabs, bg='white', padx=10, pady=12)
        history_panel = tk.Frame(tabs, bg='white', padx=10, pady=10)
        tabs.add(gallery, text='Cartões da história')
        tabs.add(history_panel, text='Histórico de apresentações')
        self.gallery = tk.Frame(gallery, bg='white')
        self.gallery.pack(fill='x')
        for i in range(6):
            card = tk.Button(self.gallery, bg='white', fg='#385057', activebackground='#e1eee8', relief='flat', borderwidth=0,
                             highlightthickness=2, highlightbackground='#edf0ed', font=('DejaVu Sans', 9), compound='top',
                             cursor='hand2', command=lambda index=i: self.select_card(index), wraplength=85, pady=5)
            card.grid(row=0, column=i, padx=4, sticky='nsew')
            self.gallery.columnconfigure(i, weight=1, uniform='cards')
            self.cards.append(card)
        self.history = ttk.Treeview(history_panel, columns=('time', 'source', 'story', 'character'), show='headings', height=4)
        for key, title in [('time', 'Horário'), ('source', 'Origem'), ('story', 'História'), ('character', 'Personagem')]:
            self.history.heading(key, text=title)
            self.history.column(key, width=135, minwidth=80)
        scrollbar = ttk.Scrollbar(history_panel, orient='vertical', command=self.history.yview)
        self.history.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side='right', fill='y')
        self.history.pack(fill='x')
        ttk.Button(history_panel, text='Limpar histórico visual', command=self.clear_history).pack(anchor='e', pady=(8, 0))
        self.footer = tk.Frame(panel, bg='#f5f4f0')
        self.footer.pack(fill='x', pady=(10, 0))
        self.details_button = ttk.Button(self.footer, text='Mostrar cartões e histórico', command=self.toggle_details)
        self.details_button.pack(side='right', padx=(12, 0))
        self.status = tk.StringVar(value='Escolha um personagem na lateral para começar.')
        label(self.footer, textvariable=self.status, size=9, wraplength=470, anchor='w', justify='left').pack(side='left', fill='x', expand=True)
        self.update_gallery()
        self.refresh_ports()
        root.after(30, self.poll)

    def toggle_details(self):
        if self.details.winfo_manager():
            self.details.pack_forget()
            self.details_button.configure(text='Mostrar cartões e histórico')
        else:
            self.details.pack(fill='x', pady=(10, 0), before=self.footer)
            self.details_button.configure(text='Recolher cartões e histórico')

    def load_image(self, relative_path):
        if relative_path not in self.image_cache:
            with Image.open(image_path(relative_path)) as image:
                self.image_cache[relative_path] = image.convert('RGBA')
        return self.image_cache[relative_path]

    def update_gallery(self):
        story_id = self.demo_story.current()
        story = self.catalog[str(story_id)]
        self.thumbnails = []
        for i, character in enumerate(story['personagens']):
            photo = None
            try:
                if character.get('imagem'):
                    thumb = ImageOps.contain(self.load_image(character['imagem']), (80, 80), LANCZOS)
                    photo = ImageTk.PhotoImage(thumb)
            except (OSError, ValueError):
                pass
            self.thumbnails.append(photo)
            active = self.current_event == Event(story_id, i)
            self.cards[i].configure(text=f'{i} · {character["nome"]}', image=photo or '',
                                    bg='#e7f2ec' if active else 'white',
                                    highlightbackground='#488a73' if active else '#edf0ed',
                                    state='disabled' if self.connection else 'normal')

    def select_card(self, index):
        if self.connection is None:
            self.demo_character.current(index)
            self.demo()

    def schedule_render(self, _event=None):
        if self.resize_job:
            self.root.after_cancel(self.resize_job)
        self.resize_job = self.root.after(70, self.render_image)

    def render_image(self):
        self.resize_job = None
        self.canvas.delete('all')
        width, height = max(1, self.canvas.winfo_width()), max(1, self.canvas.winfo_height())
        if self.current_event is None:
            self.canvas.create_oval(width/2-70, height/2-70, width/2+70, height/2+70, fill='#e7f2ec', outline='')
            self.canvas.create_text(width/2, height/2, text='Era uma\nvez…', justify='center', font=('DejaVu Sans', 24, 'bold'), fill='#397362')
            return
        character = self.catalog[str(self.current_event.story)]['personagens'][self.current_event.character]
        try:
            if not character.get('imagem'):
                raise ValueError('Nenhuma imagem configurada')
            fitted = ImageOps.contain(self.load_image(character['imagem']), (max(1, width-8), max(1, height-4)), LANCZOS)
            self.photo = ImageTk.PhotoImage(fitted)
            self.canvas.create_image(width/2, height/2, image=self.photo)
        except (OSError, ValueError) as error:
            self.photo = None
            self.canvas.create_text(width/2, height/2, text=character.get('simbolo', '?'), font=('DejaVu Sans', 64), fill='#397362')
            self.status.set(f'Cartão de reserva: {error}')

    def refresh_ports(self):
        try:
            from serial.tools import list_ports
            ports = [p.device for p in list_ports.comports()]
            self.port['values'] = ports
            if ports and not self.port.get():
                self.port.set(ports[0])
        except ImportError:
            self.status.set('Modo demonstração disponível. Instale requirements.txt para usar a serial.')

    def toggle_connection(self):
        if self.connection is not None:
            self.disconnect()
            return
        try:
            import serial
            if not self.port.get().strip():
                raise ValueError('Selecione ou digite a porta serial (COM3, /dev/ttyUSB0…).')
            self.connection = serial.Serial(self.port.get().strip(), 115200, bytesize=serial.SEVENBITS,
                                            parity=serial.PARITY_EVEN, stopbits=serial.STOPBITS_ONE,
                                            timeout=0, xonxoff=False, rtscts=False, dsrdtr=False)
        except (ImportError, OSError, ValueError) as error:
            messagebox.showerror('Conexão serial', str(error))
            return
        self.decoder = Decoder()
        self.connect_button.configure(text='Desconectar')
        self.demo_button.configure(state='disabled')
        self.demo_story.configure(state='disabled')
        self.demo_character.configure(state='disabled')
        self.mode_label.configure(text='  AO VIVO  ')
        self.update_gallery()
        self.status.set(f'Conectado a {self.port.get()} • 115200, 7E1')

    def disconnect(self):
        if self.connection is not None:
            self.connection.close()
            self.connection = None
        self.decoder = Decoder()
        self.connect_button.configure(text='Conectar')
        self.demo_button.configure(state='normal')
        self.demo_story.configure(state='readonly')
        self.demo_character.configure(state='readonly')
        self.mode_label.configure(text='  EXPLORAR  ')
        self.update_gallery()
        self.status.set('Desconectado')

    def poll(self):
        try:
            if self.connection is not None:
                data = self.connection.read(min(self.connection.in_waiting, 4096))
                for result in self.decoder.feed(data):
                    if isinstance(result, Event):
                        self.present(result, 'Serial')
                    else:
                        self.status.set(str(result))
        except OSError as error:
            self.disconnect()
            self.status.set(f'Conexão interrompida: {error}')
        finally:
            self.root.after(30, self.poll)

    def demo(self):
        # Exercita o mesmo decodificador usado na recepção real.
        frame = f'H{self.demo_story.current()},P{self.demo_character.current()}\n'.encode('ascii')
        self.present(Decoder().feed(frame)[0], 'Demonstração')

    def present(self, event, source):
        story = self.catalog[str(event.story)]
        character = story['personagens'][event.character]
        self.story_label.configure(text=story['nome'])
        self.name_label.configure(text=character['nome'])
        self.code_label.configure(text=f'História {event.story} • Personagem {event.character} • {source}')
        self.current_event = event
        self.mode_label.configure(text='  AO VIVO  ' if source == 'Serial' else '  DEMONSTRAÇÃO  ')
        self.demo_story.current(event.story)
        self.update_gallery()
        now = datetime.now().astimezone()
        self.history.insert('', 'end', values=(now.strftime('%H:%M:%S'), source, story['nome'], character['nome']))
        children = self.history.get_children()
        if len(children) > 200:
            self.history.delete(children[0])
        self.history.yview_moveto(1)
        self.count += 1
        self.status.set(f'{source} • H{event.story},P{event.character} • {self.count} apresentações')
        try:
            if self.log_file is None:
                folder = records_dir()
                folder.mkdir(parents=True, exist_ok=True)
                self.log_file = (folder / f'sessao_{now.strftime("%Y%m%d_%H%M%S_%f")}.csv').open('x', newline='', encoding='utf-8')
                self.writer = csv.writer(self.log_file)
                self.writer.writerow(['data_hora', 'origem', 'historia_id', 'personagem_id', 'historia', 'personagem'])
            self.writer.writerow([now.isoformat(), source, event.story, event.character, story['nome'], character['nome']])
            self.log_file.flush()
        except OSError as error:
            self.status.set(f'Personagem exibido; falha ao salvar registro: {error}')
        self.render_image()

    def clear_history(self):
        for row in self.history.get_children():
            self.history.delete(row)

    def close(self):
        self.disconnect()
        if self.log_file:
            self.log_file.close()
        self.root.destroy()


if __name__ == '__main__':
    root = tk.Tk()
    try:
        App(root)
    except (OSError, ValueError, KeyError, TypeError) as error:
        messagebox.showerror('Configuração inválida', str(error))
        root.destroy()
    else:
        root.mainloop()
