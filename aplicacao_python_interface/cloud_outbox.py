"""Fila SQLite transacional de snapshots destinados à nuvem, sem acesso à rede."""
import json
from uuid import uuid4


class CloudOutbox:
    def __init__(self, db):
        self.db = db
        db.executescript('''
            CREATE TABLE IF NOT EXISTS cloud_meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS cloud_outbox(
                entity TEXT NOT NULL, record_id TEXT NOT NULL, operation TEXT NOT NULL,
                payload TEXT, revision INTEGER NOT NULL,
                PRIMARY KEY(entity, record_id)
            );
        ''')
        with db:
            db.execute("INSERT OR IGNORE INTO cloud_meta VALUES ('installation_id',?)", (uuid4().hex,))
            if not db.execute("SELECT 1 FROM cloud_meta WHERE key='seeded'").fetchone():
                for player in db.execute('SELECT id FROM players').fetchall():
                    self.player(player['id'])
                for session in db.execute('SELECT id FROM sessions').fetchall():
                    self.session(session['id'])
                for move in db.execute('SELECT id FROM moves').fetchall():
                    self.move(move['id'])
                db.execute("INSERT INTO cloud_meta VALUES ('seeded','1')")
            # Reenvia os perfis já sincronizados uma única vez com seus nomes.
            # IDs, sessões, jogadas e exclusões pendentes são preservados.
            if not db.execute("SELECT 1 FROM cloud_meta WHERE key='player_names_v1'").fetchone():
                for player in db.execute('SELECT id FROM players').fetchall():
                    self.player(player['id'])
                db.execute("INSERT INTO cloud_meta VALUES ('player_names_v1','1')")

    @property
    def installation_id(self):
        return self.db.execute("SELECT value FROM cloud_meta WHERE key='installation_id'").fetchone()[0]

    def bind(self, project, uid, *, allow_change=False):
        destination = f'{project}/{uid}'
        with self.db:
            previous = self.db.execute("SELECT value FROM cloud_meta WHERE key='destination'").fetchone()
            if previous and previous[0] != destination and not allow_change:
                raise ValueError('Este banco local já está vinculado a outro projeto/operador. Use a configuração original ou planeje uma migração.')
            if previous and previous[0] != destination:
                if self.db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='cloud_records'").fetchone():
                    self.db.execute('UPDATE cloud_records SET version=NULL,base=NULL,seed_only=0')
                self.db.execute("DELETE FROM cloud_meta WHERE key='legacy_imported_shared_v2'")
                for row in self.db.execute('SELECT id FROM players').fetchall():
                    self.player(row['id'])
                for row in self.db.execute('SELECT id FROM sessions').fetchall():
                    self.session(row['id'])
                for row in self.db.execute('SELECT id FROM moves').fetchall():
                    self.move(row['id'])
            self.db.execute("INSERT INTO cloud_meta VALUES ('destination',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", (destination,))

    def put(self, entity, record_id, payload=None):
        # Chamado dentro da MESMA transação que altera os dados locais.
        self.db.execute('''INSERT INTO cloud_outbox VALUES (?,?,?,?,1)
            ON CONFLICT(entity,record_id) DO UPDATE SET
            operation=excluded.operation,payload=excluded.payload,revision=cloud_outbox.revision+1''',
            (entity, str(record_id), 'delete' if payload is None else 'upsert',
             json.dumps(payload, ensure_ascii=False, allow_nan=False) if payload is not None else None))

    @staticmethod
    def stats(rows):
        evaluated = [r for r in rows if r['result'] is not None]
        correct = sum(r['result'] for r in evaluated)
        total = len(evaluated)
        return {'presentations_count': len(rows), 'evaluated_count': total, 'correct_count': correct,
                'error_count': total - correct, 'accuracy_percent': 100 * correct / total if total else None}

    def player(self, player):
        profile = self.db.execute('SELECT name FROM players WHERE id=?', (player,)).fetchone()
        rows = self.db.execute('''SELECT m.result FROM moves m JOIN sessions s ON s.id=m.session
            WHERE s.player=?''', (player,)).fetchall()
        self.put('players', player, {'schema_version': 1, 'player_id': player,
                                    'label': profile['name'], **self.stats(rows)})

    def session(self, session):
        row = self.db.execute('SELECT * FROM sessions WHERE id=?', (session,)).fetchone()
        rows = self.db.execute('SELECT story,result FROM moves WHERE session=?', (session,)).fetchall()
        self.put('sessions', session, {'schema_version': 1, 'session_id': session, 'player_id': row['player'],
                                     'started_at': row['started'], **self.stats(rows),
                                     'by_story': {str(i): self.stats([r for r in rows if r['story'] == i]) for i in range(4)}})

    def move(self, move):
        row = self.db.execute('''SELECT m.*,s.player FROM moves m JOIN sessions s ON s.id=m.session
            WHERE m.id=?''', (move,)).fetchone()
        self.put('moves', move, {'schema_version': 1, 'move_id': str(move), 'session_id': row['session'],
                                'player_id': row['player'], 'occurred_at': row['time'],
                                'story': row['story'], 'character': row['character'],
                                'result': row['result'], 'result_at': row['result_time']})
        return row['session'], row['player']

    def changed_move(self, move):
        session, player = self.move(move)
        self.session(session)
        self.player(player)

    def pending(self, limit=100):
        return [dict(r) for r in self.db.execute('SELECT * FROM cloud_outbox ORDER BY entity,record_id LIMIT ?', (limit,))]

    def count(self):
        return self.db.execute('SELECT COUNT(*) FROM cloud_outbox').fetchone()[0]

    def acknowledge(self, items):
        with self.db:
            for item in items:
                self.db.execute('DELETE FROM cloud_outbox WHERE entity=? AND record_id=? AND revision=?',
                                (item['entity'], item['record_id'], item['revision']))
