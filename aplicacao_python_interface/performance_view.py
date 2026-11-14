"""Janela de acompanhamento local e remoto, com consultas HTTPS fora do loop Tk."""
import csv
from datetime import datetime
import queue
import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

from cloud_firebase import CloudConfig, FirestoreClient, FirebaseError
from cloud_credentials import CredentialUnavailable
from cloud_portable import PortableVault
from performance_data import local_snapshot, remote_snapshot, identity, report, metrics, rate


class PerformanceWindow:
    def __init__(self, app):
        self.app = app
        self.window = tk.Toplevel(app.root)
        self.window.title('Acompanhamento · jogadores e sessões')
        self.window.geometry(f'{min(1180, int(app.root.winfo_screenwidth() * .94))}x{min(760, int(app.root.winfo_screenheight() * .9))}')
        self.window.minsize(720, 520)
        self.window.protocol('WM_DELETE_WINDOW', self.close)
        self.events = queue.Queue()
        self.closed = False
        self.loading = False
        self.source = 'Histórico sincronizado / offline'
        self.snapshot = local_snapshot(app.store)
        self.current = None
        self.status = tk.StringVar(value='Histórico disponível neste computador · atualizado pela sincronização automática')
        toolbar = ttk.Frame(self.window, padding=10)
        toolbar.pack(fill='x')
        ttk.Button(toolbar, text='Atualizar histórico disponível', command=self.load_local).pack(side='left')
        self.remote_button = ttk.Button(toolbar, text='Consultar nuvem agora', command=self.load_remote)
        self.remote_button.pack(side='left', padx=8)
        ttk.Button(toolbar, text='Exportar jogadas filtradas (CSV)', command=self.export).pack(side='right')
        filters = ttk.Frame(self.window, padding=(10, 0))
        filters.pack(fill='x')
        for col in (0, 1):
            filters.columnconfigure(col, weight=1)
        self.player = tk.StringVar(value='Todos')
        self.session = tk.StringVar(value='Todas')
        self.story = tk.StringVar(value='Todos')
        self.start = tk.StringVar()
        self.end = tk.StringVar()
        fields = [('Jogador / código', self.player), ('Sessão', self.session), ('Tema', self.story)]
        self.combos = []
        for col, (label, variable) in enumerate(fields):
            ttk.Label(filters, text=label).grid(row=0, column=col, sticky='w')
            combo = ttk.Combobox(filters, textvariable=variable, state='readonly', width=24)
            combo.grid(row=1, column=col, sticky='ew', padx=(0, 8))
            self.combos.append(combo)
        self.combos[0].bind('<<ComboboxSelected>>', self.player_changed)
        self.combos[1].bind('<<ComboboxSelected>>', lambda _: self.apply())
        self.combos[2]['values'] = ['Todos'] + [f'{i} · {app.catalog[str(i)]["nome"]}' for i in range(4)]
        self.combos[2].bind('<<ComboboxSelected>>', lambda _: self.apply())
        for col, (label, variable) in enumerate([('De (AAAA-MM-DD, UTC)', self.start), ('Até (AAAA-MM-DD, UTC)', self.end)]):
            ttk.Label(filters, text=label).grid(row=2, column=col, sticky='w', pady=(8, 0))
            ttk.Entry(filters, textvariable=variable).grid(row=3, column=col, sticky='ew', padx=(0, 8))
        actions = ttk.Frame(filters)
        actions.grid(row=3, column=2, sticky='w')
        ttk.Button(actions, text='Aplicar', command=self.apply).pack(side='left')
        ttk.Button(actions, text='Limpar filtros', command=self.reset).pack(side='left', padx=5)
        self.summary = tk.StringVar()
        summary_label = ttk.Label(self.window, textvariable=self.summary, padding=10, wraplength=1050)
        summary_label.pack(fill='x')
        self.tabs = ttk.Notebook(self.window)
        self.tabs.pack(fill='both', expand=True, padx=10)
        self.tables = {}
        common = ['Apresentações', 'Avaliadas', 'Acertos', 'Erros', 'Sem resultado', 'Acerto %', 'Cobertura %']
        self.add_table('Jogadores', ['Jogador / código', 'Instalação', 'ID do jogador', 'Sessões'] + common + ['Evolução (p.p.)'])
        self.add_table('Sessões', ['Jogador / código', 'Instalação', 'ID da sessão', 'Início', 'Última apresentação'] + common)
        self.add_table('Temas', ['Tema'] + common)
        self.add_table('Personagens', ['Tema', 'Personagem'] + common)
        self.add_table('Por dia', ['Data (UTC)'] + common)
        self.add_table('Jogadas', ['Jogador / código', 'Instalação', 'Sessão', 'Jogada', 'Horário', 'Tema', 'Personagem', 'Resultado', 'Horário do resultado'])
        chart_frame = ttk.Frame(self.tabs)
        self.tabs.add(chart_frame, text='Evolução')
        self.chart = tk.Canvas(chart_frame, background='white', highlightthickness=0, height=200)
        self.chart.pack(fill='both', expand=True)
        self.chart.bind('<Configure>', lambda _: self.draw_chart())
        self.tables['Jogadores'].bind('<Double-1>', self.open_player)
        status_label = ttk.Label(self.window, textvariable=self.status, padding=(10, 6), wraplength=1050)
        status_label.pack(fill='x')
        footnote = ttk.Label(self.window, text='Taxa = acertos ÷ avaliadas. Cobertura = avaliadas ÷ apresentações. '
                  'Evolução = última − primeira sessão avaliada, em pontos percentuais. '
                  'Sessões são iniciadas manualmente; estes dados descrevem o jogo e não fornecem diagnóstico. '
                  'Semana4 sem R0/R1: sem resultados disponíveis.', wraplength=1050, padding=(10, 0, 10, 8))
        footnote.pack(fill='x')
        def resize(event):
            if event.widget == self.window:
                for label in (summary_label, status_label, footnote):
                    label.configure(wraplength=max(300, event.width - 30))
        self.window.bind('<Configure>', resize, add='+')
        self.refresh_options()
        self.apply()
        self.poll_job = self.window.after(100, self.poll)

    def add_table(self, title, columns):
        frame = ttk.Frame(self.tabs)
        self.tabs.add(frame, text=title)
        frame.rowconfigure(0, weight=1)
        frame.columnconfigure(0, weight=1)
        tree = ttk.Treeview(frame, columns=list(range(len(columns))), show='headings', selectmode='browse')
        for i, label in enumerate(columns):
            tree.heading(i, text=label)
            tree.column(i, width=155 if i == 0 else 130, minwidth=65, stretch=False)
        tree.grid(row=0, column=0, sticky='nsew')
        vertical = ttk.Scrollbar(frame, orient='vertical', command=tree.yview)
        vertical.grid(row=0, column=1, sticky='ns')
        horizontal = ttk.Scrollbar(frame, orient='horizontal', command=tree.xview)
        horizontal.grid(row=1, column=0, sticky='ew')
        tree.configure(yscrollcommand=vertical.set, xscrollcommand=horizontal.set)
        self.tables[title] = tree

    def refresh_options(self):
        self.player_keys = {'Todos': None}
        for p in sorted(self.snapshot['players'], key=lambda p: (p['label'], identity(p))):
            self.player_keys[f'{p["label"]} · {p["player_id"][:8]}'] = identity(p)
        self.combos[0]['values'] = list(self.player_keys)
        if self.player.get() not in self.player_keys:
            self.player.set('Todos')
        self.refresh_sessions()

    def refresh_sessions(self):
        player = self.player_keys[self.player.get()]
        self.session_keys = {'Todas': None}
        for s in sorted(self.snapshot['sessions'], key=lambda s: s['started_at'], reverse=True):
            if player is None or identity(s) == player:
                self.session_keys[f'{datetime.fromisoformat(s["started_at"].replace("Z", "+00:00")).astimezone().strftime("%d/%m/%Y %H:%M")} · {s["session_id"][:8]}'] = identity(s, 'session_id')
        self.combos[1]['values'] = list(self.session_keys)
        if self.session.get() not in self.session_keys:
            self.session.set('Todas')

    def player_changed(self, _=None):
        self.session.set('Todas')
        self.refresh_sessions()
        self.apply()

    def reset(self):
        self.player.set('Todos')
        self.session.set('Todas')
        self.story.set('Todos')
        self.start.set('')
        self.end.set('')
        self.refresh_sessions()
        self.apply()

    def load_local(self):
        if self.loading:
            return
        self.snapshot = local_snapshot(self.app.store)
        self.source = 'Histórico sincronizado / offline'
        self.refresh_options()
        self.apply()
        self.status.set(f'Dados locais atualizados · {self.app.store.outbox.count()} documentos pendentes de envio')

    def load_remote(self):
        if self.loading:
            return
        self.loading = True
        self.remote_button.configure(state='disabled')
        self.status.set('Consultando instalações, jogadores, sessões e jogadas no Firebase…')
        def fetch():
            try:
                config = CloudConfig.load_active()
                vault = PortableVault()
                token = vault.load(config)
                if not token:
                    raise ValueError('Conecte em Nuvem e marque Manter conectado para consultar o Firebase.')
                client = FirestoreClient(config)
                client.restore(token)
                vault.save(config, client._refresh_token)
                data = remote_snapshot(client.performance_documents())
                self.events.put(('ok', data))
            except (FirebaseError, CredentialUnavailable, ValueError, OSError) as error:
                self.events.put(('error', str(error)))
            except Exception:
                self.events.put(('error', 'Resposta remota incompatível; os dados anteriores foram preservados.'))
        threading.Thread(target=fetch, name='PerformanceRead', daemon=True).start()

    def poll(self):
        if self.closed:
            return
        try:
            kind, value = self.events.get_nowait()
        except queue.Empty:
            pass
        else:
            self.loading = False
            self.remote_button.configure(state='normal')
            if kind == 'ok':
                self.snapshot = value
                self.source = 'Firebase'
                self.refresh_options()
                self.apply()
                self.status.set('Firebase consultado em ' + datetime.now().astimezone().isoformat(timespec='seconds') +
                                ' · somente dados já enviados · nomes vinculados pelo ID do jogador e da instalação · '
                                'a consulta de várias coleções pode refletir sincronização em andamento')
            else:
                self.status.set('Consulta não concluída; dados anteriores mantidos. ' + value +
                                ' Se a listagem de instalações for negada, publique firebase/firestore.rules.')
        self.poll_job = self.window.after(100, self.poll)

    @staticmethod
    def values(m):
        return [m['presentations'], m['evaluated'], m['correct'], m['errors'], m['missing'], rate(m['accuracy']), rate(m['coverage'])]

    def story_name(self, number):
        return self.app.catalog[str(number)]['nome']

    def character_name(self, story, character):
        return self.app.catalog[str(story)]['personagens'][character]['nome']

    def apply(self):
        try:
            data = report(self.snapshot, player=self.player_keys[self.player.get()],
                          session=self.session_keys[self.session.get()], start=self.start.get().strip(),
                          end=self.end.get().strip(), story=None if self.story.get() == 'Todos' else int(self.story.get()[0]))
        except ValueError as error:
            messagebox.showerror('Filtro inválido', str(error), parent=self.window)
            return
        self.current = data
        for tree in self.tables.values():
            tree.delete(*tree.get_children())
        m = data['totals']
        self.summary.set(f'{self.source} · {len(data["players"])} jogadores · {len(data["sessions"])} sessões · '
                         f'{m["presentations"]} apresentações · {m["evaluated"]} avaliadas · {m["correct"]} acertos · '
                         f'{m["errors"]} erros · {m["missing"]} sem resultado · Acerto: {rate(m["accuracy"])} · '
                         f'Cobertura: {rate(m["coverage"])}')
        self.labels = {identity(p): p['label'] for p in self.snapshot['players']}
        self.overview_keys = {}
        for p, stats, count, delta in data['players']:
            item = self.tables['Jogadores'].insert('', 'end', values=[p['label'], p['installation_id'], p['player_id'], count] +
                                                     self.values(stats) + ['—' if delta is None else f'{delta:+.1f}'])
            self.overview_keys[item] = identity(p)
        for s in sorted(data['sessions'], key=lambda s: s['started_at'], reverse=True):
            moves = [r for r in data['moves'] if identity(r, 'session_id') == identity(s, 'session_id')]
            self.tables['Sessões'].insert('', 'end', values=[self.labels.get(identity(s), s['player_id']), s['installation_id'],
                s['session_id'], s['started_at'], moves[-1]['occurred_at'] if moves else '—'] + self.values(metrics(moves)))
        for story, stats in data['stories']:
            self.tables['Temas'].insert('', 'end', values=[self.story_name(story)] + self.values(stats))
        for (story, character), stats in data['characters']:
            self.tables['Personagens'].insert('', 'end', values=[self.story_name(story), self.character_name(story, character)] + self.values(stats))
        for day, stats in data['daily']:
            self.tables['Por dia'].insert('', 'end', values=[day] + self.values(stats))
        for row in data['moves']:
            self.tables['Jogadas'].insert('', 'end', values=self.move_values(row))
        self.draw_chart()

    def move_values(self, row):
        return [self.labels.get(identity(row), row['player_id']), row['installation_id'], row['session_id'], row['move_id'],
                row['occurred_at'], self.story_name(row['story']), self.character_name(row['story'], row['character']),
                'Sem resultado' if row['result'] is None else ('Acerto' if row['result'] == 1 else 'Erro'), row['result_at'] or '']

    def open_player(self, _=None):
        selected = self.tables['Jogadores'].selection()
        if selected:
            key = self.overview_keys[selected[0]]
            for label, value in self.player_keys.items():
                if value == key:
                    self.player.set(label)
                    self.player_changed()
                    self.tabs.select(self.tables['Sessões'].master)
                    break

    def draw_chart(self):
        self.chart.delete('all')
        if not self.current:
            return
        days = self.current['daily']
        width, height = max(300, self.chart.winfo_width()), max(180, self.chart.winfo_height())
        self.chart.create_text(10, 15, anchor='w', text='Acerto por dia UTC (%) · filtros aplicados · dias sem avaliação não têm ponto')
        if not any(m['evaluated'] for _, m in days):
            self.chart.create_text(width / 2, height / 2, text='Sem resultados avaliados neste período.')
            return
        for value in (0, 25, 50, 75, 100):
            y = height - 45 - (height - 90) * value / 100
            self.chart.create_line(45, y, width - 25, y, fill='#e4e9e6')
            self.chart.create_text(25, y, text=str(value))
        previous = None
        for i, (day, stats) in enumerate(days):
            x = 55 + (width - 95) * i / max(1, len(days) - 1)
            if stats['accuracy'] is None:
                previous = None
                continue
            y = height - 45 - (height - 90) * stats['accuracy'] / 100
            if previous:
                self.chart.create_line(*previous, x, y, fill='#23665e', width=2)
            self.chart.create_oval(x - 4, y - 4, x + 4, y + 4, fill='#23665e')
            if i % max(1, len(days) // 6) == 0 or i == len(days) - 1:
                self.chart.create_text(x, height - 24, text=day, angle=0)
            previous = (x, y)

    def export(self):
        if self.current is None:
            return
        destination = filedialog.asksaveasfilename(parent=self.window, defaultextension='.csv',
                                                  filetypes=[('CSV', '*.csv')], initialfile='acompanhamento.csv')
        if not destination:
            return
        try:
            with open(destination, 'w', encoding='utf-8-sig', newline='') as stream:
                writer = csv.writer(stream)
                writer.writerow(['jogador_codigo', 'instalacao', 'sessao', 'jogada', 'horario', 'tema', 'personagem', 'resultado', 'horario_resultado'])
                for row in self.current['moves']:
                    writer.writerow([("'" + value if isinstance(value, str) and value.lstrip().startswith(('=', '+', '-', '@')) else value)
                                     for value in self.move_values(row)])
            self.status.set(f'Exportadas {len(self.current["moves"])} jogadas do filtro atual.')
        except OSError as error:
            messagebox.showerror('Falha na exportação', str(error), parent=self.window)

    def close(self):
        self.closed = True
        self.window.after_cancel(self.poll_job)
        self.window.destroy()
