"""Histórico local persistente; somente resultados serial entram nas estatísticas."""
import sqlite3
from datetime import datetime
from uuid import uuid4


def timestamp():
    return datetime.now().astimezone().isoformat()


class PlayerStore:
    def __init__(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(path)
        self.db.row_factory = sqlite3.Row
        self.db.executescript('''
            PRAGMA foreign_keys=ON;
            CREATE TABLE IF NOT EXISTS players(id TEXT PRIMARY KEY, name TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS sessions(id TEXT PRIMARY KEY, player TEXT NOT NULL REFERENCES players(id), started TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS moves(id INTEGER PRIMARY KEY, session TEXT NOT NULL REFERENCES sessions(id), time TEXT NOT NULL, story INTEGER NOT NULL, character INTEGER NOT NULL, result INTEGER CHECK(result IN (0,1)), result_time TEXT);
        ''')

    def players(self):
        return self.db.execute('SELECT * FROM players ORDER BY name, id').fetchall()

    def add_player(self, name):
        name = name.strip()
        if not name or len(name) > 80:
            raise ValueError('Use um nome ou apelido de 1 a 80 caracteres.')
        key = uuid4().hex
        with self.db:
            self.db.execute('INSERT INTO players VALUES (?,?)', (key, name))
        return key

    def rename_player(self, player, name):
        name = name.strip()
        if not name or len(name) > 80:
            raise ValueError('Use um nome ou apelido de 1 a 80 caracteres.')
        with self.db:
            if self.db.execute('UPDATE players SET name=? WHERE id=?', (name, player)).rowcount != 1:
                raise ValueError('Jogador não encontrado.')

    def delete_player(self, player):
        # Uma transação remove somente o perfil escolhido e seus dados relacionados.
        with self.db:
            self.db.execute('DELETE FROM moves WHERE session IN (SELECT id FROM sessions WHERE player=?)', (player,))
            self.db.execute('DELETE FROM sessions WHERE player=?', (player,))
            self.db.execute('DELETE FROM players WHERE id=?', (player,))

    def session(self, player):
        key = uuid4().hex
        with self.db:
            self.db.execute('INSERT INTO sessions VALUES (?,?,?)', (key, player, timestamp()))
        return key

    def move(self, session, event):
        with self.db:
            return self.db.execute('INSERT INTO moves(session,time,story,character) VALUES (?,?,?,?)',
                                   (session, timestamp(), event.story, event.character)).lastrowid

    def result(self, move, correct):
        with self.db:
            cursor = self.db.execute('UPDATE moves SET result=?, result_time=? WHERE id=? AND result IS NULL',
                                    (int(correct), timestamp(), move))
        return cursor.rowcount == 1

    def history(self, player):
        return self.db.execute('''SELECT m.*, s.started, s.id AS session_id FROM moves m
            JOIN sessions s ON s.id=m.session WHERE s.player=? ORDER BY m.id''', (player,)).fetchall()

    def close(self):
        self.db.close()


def summarize(rows):
    evaluated = [row for row in rows if row['result'] is not None]
    correct = sum(row['result'] for row in evaluated)
    return len(evaluated), correct, (100 * correct / len(evaluated) if evaluated else None)
