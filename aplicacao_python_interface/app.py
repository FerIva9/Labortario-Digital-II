"""Apresentador desktop Fábula TEA +. Execute: python app.py."""
import csv
import json
import queue
import sqlite3
import sys
from datetime import datetime
import tkinter as tk
from tkinter import ttk, messagebox, filedialog
from tkinter import font as tkfont
from PIL import Image, ImageTk, ImageOps

from protocol import Decoder, Event, Result
from player_store import PlayerStore, summarize
from runtime_paths import CATALOG_PATH, image_path, records_dir, cloud_config_path, cloud_preferences_path
from cloud_firebase import CloudConfig, SyncWorker
from cloud_preferences import CloudPreferences
from ui_layout import ScrollableFrame
from windows_display import configure_display

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
        self.db_path = records_dir() / 'jogadores.sqlite3'
        self.store = PlayerStore(self.db_path)
        self.cloud_worker = None
        self.cloud_dialog = None
        self.cloud_active = False
        self.cloud_status = 'Preparando sincronização automática · coleta local ativa'
        self.cloud_preferences = CloudPreferences()
        self.player_id = None
        self.session_id = None
        self.pending_move = None
        self.decoder = Decoder()
        self.photo = None
        self.log_file = None
        self.writer = None
        self.count = 0
        self.current_event = None
        self.presentation_mode = False
        self.thumbnails = []
        self.cards = []
        self.image_cache = {}
        self.resize_job = None
        root.title('Fábula TEA + • Um mundo de histórias')
        screen_width, screen_height = root.winfo_screenwidth(), root.winfo_screenheight()
        width, height = min(1240, int(screen_width * .9)), min(900, int(screen_height * .85))
        root.geometry(f'{width}x{height}')
        root.minsize(min(720, width), min(480, height))
        self.font_family = 'Segoe UI' if sys.platform == 'win32' else 'DejaVu Sans'
        root.configure(bg='#f5f4f0')
        root.protocol('WM_DELETE_WINDOW', self.close)
        root.bind('<F11>', self.toggle_presentation)
        root.bind('<Escape>', self.exit_presentation)
        style = ttk.Style()
        style.theme_use('clam')
        style.configure('TCombobox', padding=7, font=(self.font_family, 10), fieldbackground='white')
        style.configure('TButton', font=(self.font_family, 10), padding=(12, 9), background='#edf0f3', borderwidth=0)
        style.map('TButton', background=[('active', '#dce5eb')])
        style.configure('Accent.TButton', background='#23665e', foreground='white')
        style.map('Accent.TButton', background=[('active', '#174e47'), ('disabled', '#cedbd8')])
        style.configure('Treeview', background='white', fieldbackground='white', foreground='#293d48', rowheight=max(30, tkfont.Font(root=root, family=self.font_family, size=10).metrics('linespace') + 12), borderwidth=0, font=(self.font_family, 10))
        style.configure('Treeview.Heading', background='#eef2f3', foreground='#657780', font=(self.font_family, 9, 'bold'), padding=8)
        style.map('Treeview', background=[('selected', '#d8ede7')], foreground=[('selected', '#183d35')])
        style.configure('TNotebook', background='#f5f4f0', borderwidth=0)
        style.configure('TNotebook.Tab', padding=(18, 9), background='#e9ece9', font=(self.font_family, 10))
        style.map('TNotebook.Tab', background=[('selected', '#ffffff')])

        def label(parent, text='', size=10, color='#667c83', bg='#f5f4f0', bold=False, **kw):
            return tk.Label(parent, text=text, font=(self.font_family, size, 'bold' if bold else 'normal'), fg=color, bg=bg, **kw)

        root.rowconfigure(0, weight=1)
        root.columnconfigure(1, weight=1)
        self.sidebar_view = ScrollableFrame(root, '#183e3a', fit_content_width=True)
        self.sidebar_view.grid(row=0, column=0, sticky='ns')
        sidebar = self.sidebar_view.content
        label(sidebar, 'FÁBULA', 24, '#ffffff', '#183e3a', True).pack(anchor='w', padx=25, pady=(30, 0))
        label(sidebar, 'TEA +', 16, '#a9d9c8', '#183e3a', True).pack(anchor='w', padx=27)
        label(sidebar, 'Um mundo de histórias', 10, '#b7cec8', '#183e3a').pack(anchor='w', padx=27, pady=(8, 30))
        tk.Frame(sidebar, height=1, bg='#365852').pack(fill='x', padx=25)
        label(sidebar, 'SESSÃO EM ANDAMENTO', 9, '#b7cec8', '#183e3a', True).pack(anchor='w', padx=25, pady=(15, 5))
        self.active_player_label = label(sidebar, '', 15, '#ffffff', '#183e3a', True, wraplength=185, justify='left')
        self.active_player_label.pack(anchor='w', padx=25, pady=(0, 8))
        self.session_label = label(sidebar, '', 9, '#b7cec8', '#183e3a', wraplength=185)
        self.session_label.pack(fill='x', padx=25)
        ttk.Button(sidebar, text='Encerrar sessão / trocar jogador', command=self.end_session).pack(fill='x', padx=25, pady=10)
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
        label(sidebar, 'F11  Somente personagem\nEsc  Voltar à interface', 9, '#b7cec8', '#183e3a', justify='left').pack(side='bottom', anchor='w', padx=25, pady=25)

        self.main_view = ScrollableFrame(root, '#f5f4f0')
        self.main_view.grid(row=0, column=1, sticky='nsew')
        panel = self.main_view.content
        panel.configure(padx=14, pady=12)
        panel.columnconfigure(0, weight=1)
        panel.rowconfigure(1, weight=1)
        top = tk.Frame(panel, bg='#f5f4f0')
        top.grid(row=0, column=0, sticky='ew', pady=(0, 10))
        top.columnconfigure(0, weight=1)
        self.heading = label(top, 'Hora de imaginar', 23, '#243e43', bold=True, anchor='w', justify='left')
        self.heading.grid(row=0, column=0, sticky='ew')
        self.mode_label = label(top, '  EXPLORAR  ', 9, '#23665e', '#deeee7', True, padx=10, pady=7)
        ttk.Button(top, text='Tela cheia · personagem', style='Accent.TButton',
                   command=self.toggle_presentation).grid(row=1, column=0, columnspan=2, sticky='e', pady=(8, 0))
        self.mode_label.grid(row=0, column=1, padx=(10, 0))
        top.bind('<Configure>', lambda event: self.heading.configure(wraplength=max(80, event.width - self.mode_label.winfo_reqwidth() - 20)))
        stage = tk.Frame(panel, bg='white', highlightbackground='#e3e7e4', highlightthickness=1)
        stage.grid(row=1, column=0, sticky='nsew')
        stage.columnconfigure(0, weight=1)
        stage.rowconfigure(1, weight=1)
        self.story_label = label(stage, 'Escolha uma história', 11, '#637a7c', 'white', True)
        self.story_label.grid(row=0, column=0, sticky='ew', pady=(10, 0))
        self.canvas = tk.Canvas(stage, width=1, height=200, bg='white', highlightthickness=0)
        self.canvas.grid(row=1, column=0, sticky='nsew', padx=4)
        self.canvas.bind('<Configure>', self.schedule_render)
        self.name_label = label(stage, 'Toda aventura começa com uma ideia', 22, '#243e43', 'white', True)
        self.name_label.grid(row=2, column=0, sticky='ew', pady=(0, 4))
        self.code_label = label(stage, 'Escolha um cartão abaixo para começar.', 10, '#788a8d', 'white')
        self.code_label.grid(row=3, column=0, sticky='ew', pady=(0, 10))
        stage.bind('<Configure>', self.wrap_stage_labels)

        self.details = tk.Frame(panel, bg='#f5f4f0')
        tabs = ttk.Notebook(self.details)
        tabs.pack(fill='x')
        gallery = tk.Frame(tabs, bg='white', padx=10, pady=12)
        history_panel = tk.Frame(tabs, bg='white', padx=10, pady=10)
        tabs.add(gallery, text='Cartões')
        tabs.add(history_panel, text='Histórico ao vivo')
        stats_panel = tk.Frame(tabs, bg='white', padx=10, pady=10)
        tabs.add(stats_panel, text='Desempenho do jogador')
        self.stats_summary = tk.StringVar()
        ttk.Label(stats_panel, textvariable=self.stats_summary, wraplength=550).pack(anchor='w', pady=8)
        self.stats_text = tk.Text(stats_panel, height=12, width=45, wrap='word', font=(self.font_family, 10))
        self.stats_text.pack(fill='both', expand=True)
        ttk.Button(stats_panel, text='Exportar histórico do jogador (CSV)', command=self.export_player).pack(anchor='e', pady=6)
        self.refresh_stats()
        ttk.Button(sidebar, text='Ver desempenho do jogador', command=lambda: self.show_stats(tabs, stats_panel)).pack(fill='x', padx=25, pady=8)
        self.gallery = tk.Frame(gallery, bg='white')
        self.gallery.pack(fill='x')
        self.gallery_columns = None
        self.gallery.bind('<Configure>', self.layout_gallery)
        for i in range(6):
            card = tk.Button(self.gallery, bg='white', fg='#385057', activebackground='#e1eee8', relief='flat', borderwidth=0,
                             highlightthickness=2, highlightbackground='#edf0ed', font=(self.font_family, 9), compound='top',
                             cursor='hand2', command=lambda index=i: self.select_card(index), wraplength=85, pady=5)
            card.grid(row=0, column=i, padx=4, sticky='nsew')
            self.gallery.columnconfigure(i, weight=1, uniform='cards')
            self.cards.append(card)
        self.history = ttk.Treeview(history_panel, columns=('time', 'source', 'story', 'character', 'result'), show='headings', height=4)
        for key, title in [('time', 'Horário'), ('source', 'Origem'), ('story', 'História'), ('character', 'Personagem'), ('result', 'Resultado da jogada')]:
            self.history.heading(key, text=title)
            self.history.column(key, width=135, minwidth=80)
        scrollbar = ttk.Scrollbar(history_panel, orient='vertical', command=self.history.yview)
        self.history.configure(yscrollcommand=scrollbar.set)
        scrollbar.pack(side='right', fill='y')
        horizontal = ttk.Scrollbar(history_panel, orient='horizontal', command=self.history.xview)
        self.history.configure(xscrollcommand=horizontal.set)
        self.history.pack(fill='x')
        horizontal.pack(fill='x')
        ttk.Button(history_panel, text='Limpar histórico visual', command=self.clear_history).pack(anchor='e', pady=(8, 0))
        self.footer = tk.Frame(panel, bg='#f5f4f0')
        self.footer.grid(row=3, column=0, sticky='ew', pady=(10, 0))
        self.footer.columnconfigure(0, weight=1)
        self.details_button = ttk.Button(self.footer, text='Mostrar cartões e histórico', command=self.toggle_details)
        self.details_button.grid(row=1, column=0, sticky='e', pady=(8, 0))
        self.status = tk.StringVar(value='Escolha um personagem na lateral para começar.')
        self.status_label = label(self.footer, textvariable=self.status, size=9, anchor='w', justify='left')
        self.status_label.grid(row=0, column=0, sticky='ew')
        self.footer.bind('<Configure>', lambda event: self.status_label.configure(wraplength=max(80, event.width - 8)))
        self.presentation_canvas = tk.Canvas(root, bg='white', highlightthickness=0, cursor='none')
        self.presentation_canvas.bind('<Configure>', self.schedule_render)
        self.update_gallery()
        self.refresh_ports()
        self.build_cloud_menu()
        self.build_login()
        self.show_login()
        root.after(500, self.poll_cloud)
        root.after(1000, self.start_auto_sync)
        root.after(30, self.poll)

    def build_cloud_menu(self):
        bar = tk.Menu(self.root)
        self.cloud_menu = tk.Menu(bar, tearoff=False)
        self.cloud_menu.add_command(label=self.cloud_status, state='disabled')
        self.cloud_menu.add_separator()
        self.cloud_menu.add_command(label='Configurar / conectar…', command=self.connect_cloud)
        self.cloud_automatic_var = tk.BooleanVar(value=self.cloud_preferences.automatic)
        self.cloud_menu.add_checkbutton(label='Sincronização automática', variable=self.cloud_automatic_var,
                                        command=self.toggle_cloud_automatic)
        self.cloud_menu.add_command(label='Reconectar / sincronizar agora', command=self.resume_cloud)
        self.cloud_menu.add_command(label='Detalhes da sincronização', command=self.cloud_details)
        bar.add_cascade(label='Nuvem', menu=self.cloud_menu)
        bar.add_command(label='Acompanhamento', command=self.open_performance)
        self.menu_bar = bar
        self.root.configure(menu=bar)

    def open_performance(self):
        from performance_view import PerformanceWindow
        existing = getattr(self, 'performance_window', None)
        if existing and not existing.closed:
            existing.window.lift()
            return
        self.performance_window = PerformanceWindow(self)

    def toggle_cloud_automatic(self):
        if self.cloud_automatic_var.get():
            self.resume_cloud()
        else:
            self.pause_cloud()

    def cloud_details(self):
        window = tk.Toplevel(self.root)
        window.title('Situação da sincronização')
        window.transient(self.root)
        width = min(780, int(self.root.winfo_screenwidth() * .9))
        height = min(520, int(self.root.winfo_screenheight() * .85))
        window.geometry(f'{width}x{height}')
        window.rowconfigure(1, weight=1)
        window.columnconfigure(0, weight=1)
        ttk.Label(window, text='Sincronização com a nuvem', font=(self.font_family, 15, 'bold')).grid(row=0, column=0, sticky='w', padx=18, pady=16)
        panel = ttk.Frame(window)
        panel.grid(row=1, column=0, sticky='nsew', padx=18)
        panel.rowconfigure(0, weight=1)
        panel.columnconfigure(0, weight=1)
        content = tk.Text(panel, wrap='word', font=(self.font_family, 10), padx=12, pady=12,
                          bg='white', fg='#243e43', relief='flat', width=45, height=12)
        content.grid(row=0, column=0, sticky='nsew')
        scroll = ttk.Scrollbar(panel, command=content.yview)
        scroll.grid(row=0, column=1, sticky='ns')
        content.configure(yscrollcommand=scroll.set)
        def refresh():
            try:
                cfg = CloudConfig.load_active()
                destination = f'Projeto: {cfg.project_id}\nUID do responsável: {cfg.operator_uid}\n'
            except (ValueError, OSError):
                destination = 'Configuração Firebase ausente ou inválida.\n'
            text = (f'{self.cloud_status}\n\n{destination}Registros na fila: {self.store.outbox.count()}'
                    f'\nInstalação: {self.store.outbox.installation_id}'
                    f'\nConfiguração local (opcional): {cloud_config_path()}'
                    '\n\nOs registros pendentes permanecem no computador até a confirmação do envio. '
                    'A sincronização automática reutiliza a autorização salva. '
                    'O acesso é salvo no cofre ou no arquivo privado criptografado. '
                    'Nomes cadastrados, sessões e resultados são enviados ao Firebase.')
            content.configure(state='normal')
            content.delete('1.0', 'end')
            content.insert('1.0', text)
            content.configure(state='disabled')
        def copy():
            window.clipboard_clear()
            window.clipboard_append(content.get('1.0', 'end-1c'))
        buttons = ttk.Frame(window)
        buttons.grid(row=2, column=0, sticky='ew', padx=18, pady=14)
        ttk.Button(buttons, text='Atualizar', command=refresh).pack(side='left')
        ttk.Button(buttons, text='Copiar detalhes', command=copy).pack(side='left', padx=8)
        ttk.Button(buttons, text='Fechar', command=window.destroy).pack(side='right')
        refresh()

    def connect_cloud(self):
        if self.cloud_worker and self.cloud_worker.thread.is_alive():
            messagebox.showinfo('Nuvem', 'A sincronização anterior ainda está ativa. Pause e aguarde a conclusão da requisição antes de conectar novamente.', parent=self.root)
            return
        if self.cloud_dialog and self.cloud_dialog.winfo_exists():
            self.cloud_dialog.lift()
            return
        initial = {'project_id': '', 'api_key': '', 'operator_uid': ''}
        interval = 60
        try:
            self.cloud_preferences = CloudPreferences.load(cloud_preferences_path())
        except (ValueError, OSError):
            self.cloud_preferences = CloudPreferences()
        try:
            config = CloudConfig.load_active()
            initial = {'project_id': config.project_id, 'api_key': config.api_key, 'operator_uid': config.operator_uid}
            interval = config.sync_interval_seconds
        except FileNotFoundError:
            pass
        except (ValueError, OSError):
            self.cloud_status = 'Confira a configuração do Firebase antes de conectar.'
        dialog = self.cloud_dialog = tk.Toplevel(self.root)
        dialog.title('Conectar ao Firebase')
        dialog.transient(self.root)
        dialog.geometry(f'{min(600, int(self.root.winfo_screenwidth()*.85))}x{min(650, int(self.root.winfo_screenheight()*.85))}')
        dialog.rowconfigure(0, weight=1)
        dialog.columnconfigure(0, weight=1)
        view = ScrollableFrame(dialog, 'white')
        view.grid(row=0, column=0, sticky='nsew')
        body = view.content
        body.configure(padx=24, pady=20)
        tk.Label(body, text='Sincronização com a nuvem', bg='white', fg='#183e3a', font=(self.font_family, 16, 'bold'), wraplength=440, anchor='w', justify='left').pack(fill='x', pady=(0, 8))
        tk.Label(body, text='Use a conta Firebase do responsável. Os perfis dos jogadores continuam sendo escolhidos na tela inicial.', bg='white', fg='#637a7c', wraplength=440, justify='left').pack(fill='x', pady=(0, 12))
        entries = {}
        for key, title in [('project_id', 'ID do projeto'), ('api_key', 'Web API Key'), ('operator_uid', 'UID do responsável'), ('email', 'Email da conta Firebase'), ('password', 'Senha')]:
            tk.Label(body, text=title, bg='white', fg='#243e43', anchor='w').pack(fill='x', pady=(6, 3))
            entry = ttk.Entry(body, show='•' if key == 'password' else '')
            entry.insert(0, self.cloud_preferences.email if key == 'email' else initial.get(key, ''))
            entry.pack(fill='x')
            entries[key] = entry
        remember = tk.BooleanVar(value=self.cloud_preferences.remember_login)
        ttk.Checkbutton(body, text='Manter conectado neste computador', variable=remember).pack(fill='x', pady=(12, 0))
        tk.Label(body, text='A conexão será automática nas próximas aberturas com o acesso salvo no cofre ou no arquivo privado criptografado. A senha não é gravada. O histórico pendente será enviado ao projeto configurado.', bg='white', fg='#637a7c', wraplength=440, justify='left').pack(fill='x', pady=12)
        feedback = tk.StringVar()
        ttk.Label(body, textvariable=feedback, wraplength=440).pack(fill='x', pady=(0, 8))
        def start():
            if self.cloud_worker and self.cloud_worker.thread.is_alive():
                feedback.set('Aguarde a conexão anterior terminar antes de salvar a nova conexão.')
                return
            values = {key: entry.get() for key, entry in entries.items()}
            try:
                cfg = CloudConfig(values['project_id'].strip(), values['api_key'].strip(), values['operator_uid'].strip(), interval).validate()
                if not values['email'].strip() or not values['password']:
                    raise ValueError('Informe email e senha do responsável.')
                cfg.save(cloud_config_path())
                self.cloud_preferences = CloudPreferences(True, remember.get(), values['email'].strip())
                self.cloud_preferences.save(cloud_preferences_path())
                self.cloud_automatic_var.set(True)
            except (ValueError, OSError) as error:
                feedback.set(str(error))
                return
            self.cloud_active = True
            self.cloud_status = 'Conectando ao Firebase…'
            self.cloud_worker = SyncWorker(self.db_path, cfg, values['email'], values['password'],
                                           remember=remember.get(), forget_saved=not remember.get(), allow_rebind=True)
            self.cloud_worker.start()
            entries['password'].delete(0, 'end')
            dialog.destroy()
            self.cloud_dialog = None
        ttk.Button(body, text='Conectar e sincronizar', style='Accent.TButton', command=start).pack(fill='x')
        def cancel():
            dialog.destroy()
            self.cloud_dialog = None
            self.root.after(0, self.start_auto_sync)
        dialog.protocol('WM_DELETE_WINDOW', cancel)
        ttk.Button(body, text='Cancelar', command=cancel).pack(fill='x', pady=8)
        dialog.grab_set()
        entries['email'].focus_set()

    def start_auto_sync(self):
        if self.cloud_dialog and self.cloud_dialog.winfo_exists():
            return
        if self.cloud_worker and self.cloud_worker.thread.is_alive():
            return
        try:
            self.cloud_preferences = CloudPreferences.load(cloud_preferences_path())
            if getattr(self, 'cloud_automatic_var', None) is not None:
                self.cloud_automatic_var.set(self.cloud_preferences.automatic)
            if not self.cloud_preferences.automatic:
                self.cloud_status = 'Sincronização pausada por você · coleta local ativa'
                return
            if not self.cloud_preferences.remember_login:
                self.cloud_status = 'Modo local · acesso não mantido neste computador'
                return
            config = CloudConfig.load_active()
        except (ValueError, OSError) as error:
            self.cloud_status = f'Modo local · confira a configuração da nuvem: {error}'
            return
        self.cloud_active = True
        self.cloud_worker = SyncWorker(self.db_path, config, remember=True)
        self.cloud_worker.start()

    def resume_cloud(self):
        try:
            self.cloud_preferences = CloudPreferences.load(cloud_preferences_path())
            self.cloud_preferences.automatic = True
            self.cloud_preferences.remember_login = True
            self.cloud_preferences.save(cloud_preferences_path())
            if getattr(self, 'cloud_automatic_var', None) is not None:
                self.cloud_automatic_var.set(True)
        except (ValueError, OSError) as error:
            self.cloud_status = f'Modo local · não foi possível salvar a preferência: {error}'
            return
        if self.cloud_worker and self.cloud_worker.thread.is_alive():
            if self.cloud_worker.stopping:
                self.cloud_status = 'Retomando sincronização automática…'
                self.root.after(100, self.finish_cloud_resume)
            else:
                self.cloud_active = True
                self.cloud_worker.request_sync(remember=True)
                self.cloud_status = 'Sincronização automática ativada · verificando pendências'
            return
        self.start_auto_sync()

    def finish_cloud_resume(self):
        if not self.cloud_preferences.automatic:
            return
        if self.cloud_worker and self.cloud_worker.thread.is_alive():
            if self.cloud_worker.stopping:
                self.root.after(100, self.finish_cloud_resume)
            return
        self.start_auto_sync()

    def pause_cloud(self):
        self.cloud_active = False
        if self.cloud_worker:
            self.cloud_worker.stop()
        try:
            self.cloud_preferences.automatic = False
            self.cloud_preferences.save(cloud_preferences_path())
            self.cloud_automatic_var.set(False)
            self.cloud_status = 'Sincronização pausada · dados preservados localmente'
        except OSError:
            self.cloud_status = 'Pausa nesta execução · não foi possível salvar a preferência'
        self.cloud_menu.entryconfigure(0, label=self.cloud_status)

    def poll_cloud(self):
        if self.cloud_worker:
            while True:
                try:
                    status = self.cloud_worker.events.get_nowait()
                    if self.cloud_active:
                        self.cloud_status = status
                except queue.Empty:
                    break
            if self.cloud_active and self.cloud_worker.thread.is_alive() and not self.cloud_worker.stopping:
                pending = self.store.outbox.count()
                if pending:
                    if not getattr(self, 'cloud_status', '').startswith(('Modo local', 'Sincronização pausada')):
                        self.cloud_status = f'Sincronizando · {pending} documentos pendentes'
                    self.cloud_worker.request_sync()
        self.cloud_menu.entryconfigure(0, label=self.cloud_status[:110])
        self.root.after(500, self.poll_cloud)

    def show_stats(self, tabs, panel):
        if not self.details.winfo_manager():
            self.toggle_details()
        tabs.select(panel)
        self.main_view.canvas.yview_moveto(1)

    def build_login(self):
        self.login_view = ScrollableFrame(self.root, '#edf3ef')
        body = self.login_view.content
        body.columnconfigure(0, weight=1)
        body.columnconfigure(2, weight=1)
        body.columnconfigure(1, weight=3)
        card = tk.Frame(body, bg='white', padx=28, pady=24, highlightbackground='#dbe5df', highlightthickness=1)
        card.grid(row=0, column=1, sticky='nsew', padx=20, pady=24)
        def text(value, size=11, color='#637a7c', bold=False):
            widget = tk.Label(card, text=value, bg='white', fg=color,
                              font=(self.font_family, size, 'bold' if bold else 'normal'),
                              anchor='w', justify='left')
            widget.pack(fill='x', pady=(0, 8))
            card.bind('<Configure>', lambda event, label=widget: label.configure(wraplength=max(100, event.width - 60)), add='+')
            return widget
        text('FÁBULA TEA +', 12, '#23665e', True)
        text('Quem vai jogar?', 24, '#243e43', True)
        text('Escolha um perfil para iniciar a sessão.')
        ttk.Button(card, text='Acompanhamento · jogadores e sessões', command=self.open_performance).pack(fill='x', pady=(0, 12))
        text('Buscar jogador', 10)
        self.player_search = tk.StringVar()
        self.login_search_entry = ttk.Entry(card, textvariable=self.player_search, font=(self.font_family, 11))
        self.login_search_entry.pack(fill='x', pady=(0, 12))
        player_list = tk.Frame(card, bg='white')
        player_list.pack(fill='x')
        self.login_players = ttk.Treeview(player_list, columns=('name', 'activity'), show='headings', height=6, selectmode='browse')
        self.login_players.heading('name', text='Jogador')
        self.login_players.heading('activity', text='Última atividade')
        self.login_players.column('name', width=230, minwidth=100)
        self.login_players.column('activity', width=140, minwidth=100)
        player_scroll = ttk.Scrollbar(player_list, orient='vertical', command=self.login_players.yview)
        player_scroll.pack(side='right', fill='y')
        self.login_players.configure(yscrollcommand=player_scroll.set)
        self.login_players.pack(side='left', fill='x', expand=True)
        self.login_players.bind('<<TreeviewSelect>>', self.choose_player)
        self.login_players.bind('<Return>', lambda _: self.new_session())
        self.player_search.trace_add('write', lambda *_: self.reload_players())
        self.login_selection = tk.StringVar()
        selection_label = tk.Label(card, textvariable=self.login_selection, bg='white', fg='#637a7c',
                                  font=(self.font_family, 10), anchor='w', justify='left')
        selection_label.pack(fill='x', pady=12)
        card.bind('<Configure>', lambda event: selection_label.configure(wraplength=max(100, event.width - 60)), add='+')
        self.profile_editor = tk.Frame(card, bg='#edf5f0', padx=12, pady=12)
        self.editor_title = tk.Label(self.profile_editor, bg='#edf5f0', fg='#243e43', font=(self.font_family, 11, 'bold'), anchor='w')
        self.editor_title.pack(fill='x', pady=(0, 8))
        self.new_player_name = tk.StringVar()
        self.new_player_entry = ttk.Entry(self.profile_editor, textvariable=self.new_player_name, font=(self.font_family, 11))
        self.new_player_entry.pack(fill='x', pady=(0, 8))
        self.new_player_entry.bind('<Return>', lambda _: self.save_profile())
        self.new_player_entry.bind('<Escape>', lambda _: self.hide_profile_editor())
        editor_actions = tk.Frame(self.profile_editor, bg='#edf5f0')
        editor_actions.pack(fill='x')
        ttk.Button(editor_actions, text='Salvar', style='Accent.TButton', command=self.save_profile).pack(side='left')
        ttk.Button(editor_actions, text='Cancelar', command=self.hide_profile_editor).pack(side='left', padx=8)
        self.editing_player = None
        self.login_actions = tk.Frame(card, bg='white')
        self.login_actions.pack(fill='x', pady=(0, 12))
        ttk.Button(self.login_actions, text='+ Novo jogador', command=lambda: self.show_profile_editor()).pack(side='left')
        self.profile_options = ttk.Menubutton(self.login_actions, text='Opções do perfil')
        self.profile_options.pack(side='right')
        menu = tk.Menu(self.profile_options, tearoff=False)
        menu.add_command(label='Renomear', command=lambda: self.show_profile_editor(rename=True))
        menu.add_separator()
        menu.add_command(label='Excluir perfil…', command=self.delete_player)
        self.profile_options.configure(menu=menu)
        self.start_session_button = ttk.Button(card, text='Iniciar sessão', style='Accent.TButton', command=self.new_session)
        self.start_session_button.pack(fill='x')
        self.login_feedback = tk.StringVar()
        feedback = tk.Label(card, textvariable=self.login_feedback, bg='white', fg='#23665e',
                            justify='left', anchor='w', font=(self.font_family, 10))
        feedback.pack(fill='x', pady=(10, 0))
        card.bind('<Configure>', lambda event: feedback.configure(wraplength=max(100, event.width - 60)), add='+')

    def show_profile_editor(self, rename=False):
        if self.session_id is not None:
            return
        selection = self.login_players.selection()
        if rename and not selection:
            return
        self.editing_player = selection[0] if rename else None
        name = next(p['name'] for p in self.players if p['id'] == self.editing_player) if rename else ''
        self.editor_title.configure(text='Renomear jogador' if rename else 'Novo jogador · nome ou apelido')
        self.new_player_name.set(name)
        self.login_feedback.set('')
        self.profile_editor.pack(fill='x', pady=(0, 12), before=self.login_actions)
        self.new_player_entry.focus_set()
        self.new_player_entry.selection_range(0, 'end')

    def hide_profile_editor(self):
        self.profile_editor.pack_forget()
        self.editing_player = None
        self.new_player_name.set('')
        self.login_feedback.set('')
        self.login_search_entry.focus_set()

    def save_profile(self):
        if self.session_id is not None:
            return
        if self.editing_player is None:
            self.add_player()
            return
        key = self.editing_player
        try:
            self.store.rename_player(key, self.new_player_name.get())
        except (ValueError, OSError, sqlite3.Error) as error:
            self.login_feedback.set(str(error))
            self.new_player_entry.focus_set()
            return
        self.hide_profile_editor()
        self.player_search.set('')
        self.reload_players(selected=key)
        self.login_feedback.set('Nome atualizado. O histórico foi preservado.')

    def delete_player(self):
        selection = self.login_players.selection()
        if self.session_id is not None or not selection:
            return
        key = selection[0]
        name = next(p['name'] for p in self.players if p['id'] == key)
        if not messagebox.askyesno('Excluir perfil',
                f'Excluir o perfil "{name}" e todo o seu histórico de sessões e jogadas?\n\nA exclusão também será enviada à nuvem quando houver sincronização. Esta ação não pode ser desfeita.',
                parent=self.root, icon='warning', default='no'):
            return
        try:
            self.store.delete_player(key)
        except (sqlite3.Error, OSError) as error:
            self.login_feedback.set(f'Não foi possível excluir o perfil: {error}')
            return
        self.hide_profile_editor()
        self.reload_players()
        self.login_feedback.set('Perfil e histórico excluídos.')

    def show_login(self):
        self.sidebar_view.grid_forget()
        self.main_view.grid_forget()
        self.login_view.place(x=0, y=0, relwidth=1, relheight=1)
        self.login_view.lift()
        self.root.title('Fábula TEA + • Escolher jogador')
        self.reload_players()
        self.login_search_entry.focus_set()

    def reload_players(self, selected=None):
        previous = self.login_players.selection()
        selected = selected or (previous[0] if previous else None)
        self.players = self.store.players()
        self.login_players.delete(*self.login_players.get_children())
        query = self.player_search.get().strip().casefold()
        for player in self.players:
            if query not in player['name'].casefold():
                continue
            rows = self.store.history(player['id'])
            last = datetime.fromisoformat(rows[-1]['time']).strftime('%d/%m/%Y') if rows else 'Sem jogadas ainda'
            name = player['name']
            if sum(p['name'].casefold() == name.casefold() for p in self.players) > 1:
                name += f" · {player['id'][:8]}"
            self.login_players.insert('', 'end', iid=player['id'], values=(name, last))
        if selected and self.login_players.exists(selected):
            self.login_players.selection_set(selected)
            self.login_players.see(selected)
        self.choose_player()

    def choose_player(self, _event=None):
        selection = self.login_players.selection()
        self.start_session_button.configure(state='normal' if selection else 'disabled')
        self.profile_options.configure(state='normal' if selection else 'disabled')
        if not selection:
            self.login_selection.set(('Selecione um jogador.' if self.login_players.get_children() else 'Nenhum jogador encontrado.') if self.players else 'Clique em + Novo jogador para começar.')
            return
        player = next(p for p in self.players if p['id'] == selection[0])
        total, correct, rate = summarize(self.store.history(player['id']))
        detail = f'{total} jogadas avaliadas · {correct} acertos' if total else 'Pronto para a primeira sessão.'
        self.login_selection.set(detail)

    def add_player(self):
        if self.session_id is not None:
            return
        try:
            key = self.store.add_player(self.new_player_name.get())
        except (ValueError, OSError, sqlite3.Error) as error:
            self.login_feedback.set(str(error))
            self.new_player_entry.focus_set()
            return
        self.hide_profile_editor()
        self.player_search.set('')
        self.reload_players(selected=key)
        self.login_feedback.set('Jogador adicionado. Clique em Iniciar sessão quando estiver pronto.')
        self.start_session_button.focus_set()

    def new_session(self):
        selection = self.login_players.selection()
        if self.session_id is not None or not selection:
            return
        if self.profile_editor.winfo_manager():
            self.login_feedback.set('Salve ou cancele a edição antes de iniciar a sessão.')
            return
        player_id = selection[0]
        try:
            session_id = self.store.session(player_id)
        except (sqlite3.Error, OSError) as error:
            self.login_feedback.set(f'Não foi possível iniciar a sessão: {error}')
            return
        self.player_id, self.session_id = player_id, session_id
        player = next(p for p in self.players if p['id'] == player_id)
        self.pending_move = None
        self.active_player_label.configure(text=player['name'])
        self.session_label.configure(text=f"Início: {datetime.now().strftime('%d/%m/%Y às %H:%M')}")
        self.clear_history()
        self.refresh_stats()
        self.login_view.place_forget()
        self.sidebar_view.grid(row=0, column=0, sticky='ns')
        self.main_view.grid(row=0, column=1, sticky='nsew')
        self.root.title(f"Fábula TEA + • {player['name']}")
        self.status.set('Sessão iniciada. Conecte a placa ou experimente os cartões.')
        self.connect_button.focus_set()

    def end_session(self):
        self.exit_presentation()
        self.disconnect()
        self.pending_move = None
        self.player_id = self.session_id = None
        self.current_event = None
        self.photo = None
        self.count = 0
        if self.log_file:
            self.log_file.close()
            self.log_file = self.writer = None
        self.clear_history()
        self.refresh_stats()
        self.story_label.configure(text='Escolha uma história')
        self.name_label.configure(text='Toda aventura começa com uma ideia')
        self.code_label.configure(text='Escolha um cartão abaixo para começar.')
        self.heading.configure(text='Hora de imaginar')
        if self.details.winfo_manager():
            self.toggle_details()
        self.hide_profile_editor()
        self.login_feedback.set('Sessão encerrada. O histórico foi salvo.')
        self.player_search.set('')
        self.show_login()
        self.update_gallery()
        self.schedule_render()

    def receive_result(self, result):
        pending, self.pending_move = self.pending_move, None
        if pending is None:
            self.status.set('Resultado sem personagem associado; ignorado nas estatísticas.')
            return
        move, row = pending
        try:
            self.store.result(move, result.correct)
        except (sqlite3.Error, OSError) as error:
            messagebox.showerror('Falha ao salvar resultado', str(error))
            return
        outcome = 'Acerto' if result.correct else 'Erro'
        if self.history.exists(row):
            self.history.set(row, 'result', outcome)
        self.code_label.configure(text=f'{outcome} nesta jogada · modo recontar')
        self.status.set(f'{outcome} registrado para o jogador selecionado.')
        self.refresh_stats()

    def refresh_stats(self):
        rows = self.store.history(self.player_id) if self.player_id else []
        total, correct, rate = summarize(rows)
        rate_text = f'{rate:.1f}%' if rate is not None else '—'
        current = [r for r in rows if r['session_id'] == self.session_id]
        n, c, _ = summarize(current)
        self.stats_summary.set(f'{total} jogadas avaliadas · {correct} acertos · {total-correct} erros · Taxa: {rate_text}\nSessão atual: {n} avaliadas, {c} acertos. Demonstrações e apresentações sem resultado não entram no cálculo.')
        lines = ['POR TEMA']
        for story in range(4):
            n, c, rate = summarize([r for r in rows if r['story'] == story])
            lines.append(f"{self.catalog[str(story)]['nome']}: {c}/{n}" + (f' ({rate:.1f}%)' if rate is not None else ' —'))
        lines.append('\nEVOLUÇÃO POR DATA (data local registrada)')
        for day in sorted({r['time'][:10] for r in rows}):
            n, c, rate = summarize([r for r in rows if r['time'][:10] == day])
            lines.append(f'{day}: {c}/{n}' + (f' ({rate:.1f}%)' if rate is not None else ' — sem avaliações'))
        lines.append('\nSESSÕES')
        for session in dict.fromkeys(r['session_id'] for r in rows):
            group = [r for r in rows if r['session_id'] == session]
            n, c, rate = summarize(group)
            lines.append(f"{group[0]['started'][:19]} · {session[:8]}: {c}/{n}" + (f' ({rate:.1f}%)' if rate is not None else ' —'))
        lines.append('\nMede acertos nas comparações recebidas; o protocolo não informa conclusão de histórias nem duração ou início das rodadas.')
        self.stats_text.configure(state='normal')
        self.stats_text.delete('1.0', 'end')
        self.stats_text.insert('1.0', '\n'.join(lines))
        self.stats_text.configure(state='disabled')

    def export_player(self):
        if self.player_id is None:
            return
        path = filedialog.asksaveasfilename(parent=self.root, defaultextension='.csv', initialfile='historico_jogador.csv', filetypes=[('CSV', '*.csv')])
        if not path:
            return
        try:
            with open(path, 'w', newline='', encoding='utf-8-sig') as stream:
                writer = csv.writer(stream)
                writer.writerow(['jogador_id', 'sessao', 'inicio_sessao', 'data_hora', 'historia', 'personagem', 'resultado', 'data_hora_resultado'])
                for row in self.store.history(self.player_id):
                    writer.writerow([self.player_id, row['session_id'], row['started'], row['time'], row['story'], row['character'], '' if row['result'] is None else row['result'], row['result_time'] or ''])
        except OSError as error:
            messagebox.showerror('Exportação', str(error))

    def toggle_presentation(self, _event=None):
        if self.session_id is None:
            return 'break'
        if self.presentation_mode:
            return self.exit_presentation()
        self.presentation_mode = True
        self.root.configure(menu='')
        self.root.attributes('-fullscreen', True)
        self.presentation_canvas.place(x=0, y=0, relwidth=1, relheight=1)
        tk.Misc.lift(self.presentation_canvas)
        self.presentation_canvas.focus_set()
        self.schedule_render()
        return 'break'

    def exit_presentation(self, _event=None):
        if self.presentation_mode:
            self.presentation_mode = False
            self.presentation_canvas.place_forget()
            self.canvas.focus_set()
        self.root.attributes('-fullscreen', False)
        self.root.configure(menu=self.menu_bar)
        self.schedule_render()
        return 'break'

    def toggle_details(self):
        if self.details.winfo_manager():
            self.details.grid_remove()
            self.details_button.configure(text='Mostrar cartões e histórico')
        else:
            self.details.grid(row=2, column=0, sticky='ew', pady=(10, 0))
            self.details_button.configure(text='Recolher cartões e histórico')

    def wrap_stage_labels(self, event):
        for label in (self.story_label, self.name_label, self.code_label):
            label.configure(wraplength=max(80, event.width - 24))

    def layout_gallery(self, event):
        card_width = max(100, *(card.winfo_reqwidth() + 8 for card in self.cards))
        columns = max(1, min(6, event.width // card_width))
        if columns == self.gallery_columns:
            return
        self.gallery_columns = columns
        for column in range(6):
            self.gallery.columnconfigure(column, weight=1 if column < columns else 0, uniform='cards' if column < columns else '')
        for index, card in enumerate(self.cards):
            card.grid(row=index // columns, column=index % columns, padx=4, pady=4, sticky='nsew')

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
        canvas = self.presentation_canvas if self.presentation_mode else self.canvas
        canvas.delete('all')
        width, height = max(1, canvas.winfo_width()), max(1, canvas.winfo_height())
        if self.current_event is None:
            if self.presentation_mode:
                return
            canvas.create_oval(width/2-70, height/2-70, width/2+70, height/2+70, fill='#e7f2ec', outline='')
            canvas.create_text(width/2, height/2, text='Era uma\nvez…', justify='center', font=(self.font_family, 24, 'bold'), fill='#397362')
            return
        character = self.catalog[str(self.current_event.story)]['personagens'][self.current_event.character]
        try:
            if not character.get('imagem'):
                raise ValueError('Nenhuma imagem configurada')
            fitted = ImageOps.contain(self.load_image(character['imagem']), (max(1, width-8), max(1, height-4)), LANCZOS)
            self.photo = ImageTk.PhotoImage(fitted)
            canvas.create_image(width/2, height/2, image=self.photo)
        except (OSError, ValueError) as error:
            self.photo = None
            canvas.create_text(width/2, height/2, text=character.get('simbolo', '?'), font=(self.font_family, 64), fill='#397362')
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
        if self.player_id is None:
            messagebox.showinfo('Jogador', 'Adicione ou selecione um jogador antes de conectar.')
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
        self.pending_move = None
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
        self.pending_move = None
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
                    elif isinstance(result, Result):
                        self.receive_result(result)
                    else:
                        self.pending_move = None
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
        self.pending_move = None
        row = self.history.insert('', 'end', values=(now.strftime('%H:%M:%S'), source, story['nome'], character['nome'], 'Sem resultado'))
        if source == 'Serial' and self.session_id:
            try:
                self.pending_move = (self.store.move(self.session_id, event), row)
            except (sqlite3.Error, OSError) as error:
                messagebox.showerror('Falha ao salvar jogada', str(error))
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
        if self.cloud_worker:
            self.cloud_worker.stop()
        self.disconnect()
        if self.log_file:
            self.log_file.close()
        self.store.close()
        self.root.destroy()


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--check-installation':
        from installation_check import main as check_installation
        raise SystemExit(check_installation(sys.argv[2]))
    configure_display()
    root = tk.Tk()
    try:
        App(root)
    except (OSError, sqlite3.Error, ValueError, KeyError, TypeError) as error:
        messagebox.showerror('Configuração inválida', str(error))
        root.destroy()
    else:
        root.mainloop()
