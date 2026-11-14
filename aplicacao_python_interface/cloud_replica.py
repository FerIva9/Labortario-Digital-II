"""Cache compartilhado transacional, migração legada e resolução de pendências offline."""
import hashlib
import json
import sqlite3
from pathlib import Path

from performance_data import decode_value, remote_snapshot

ENTITIES = ('players', 'sessions', 'moves')
ID_FIELD = {'players': 'player_id', 'sessions': 'session_id', 'moves': 'move_id'}


def global_id(installation, entity, identifier):
    return hashlib.sha256(f'{installation}/{entity}/{identifier}'.encode()).hexdigest()


def initialize(db):
    db.execute('''CREATE TABLE IF NOT EXISTS cloud_records(
        entity TEXT NOT NULL, local_id TEXT NOT NULL, remote_id TEXT NOT NULL,
        version TEXT, base TEXT, seed_only INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(entity,local_id), UNIQUE(entity,remote_id))''')
    if 'seed_only' not in {row[1] for row in db.execute('PRAGMA table_info(cloud_records)')}:
        db.execute('ALTER TABLE cloud_records ADD COLUMN seed_only INTEGER NOT NULL DEFAULT 0')


def mapping(store, entity, identifier):
    row = store.db.execute('SELECT * FROM cloud_records WHERE entity=? AND local_id=?',
                           (entity, str(identifier))).fetchone()
    if row:
        return dict(row)
    remote = global_id(store.outbox.installation_id, entity, identifier)
    store.db.execute('INSERT INTO cloud_records(entity,local_id,remote_id) VALUES (?,?,?)',
                     (entity, str(identifier), remote))
    return dict(entity=entity, local_id=str(identifier), remote_id=remote, version=None, base=None)


def seed_local(store):
    """Uma única migração recupera inclusive históricos antigos com fila vazia."""
    if store.db.execute("SELECT 1 FROM cloud_meta WHERE key='shared_seed_v2'").fetchone():
        return
    filename = store.db.execute('PRAGMA database_list').fetchone()['file']
    if filename:
        backup = Path(filename).with_suffix('.pre-compartilhado.sqlite3')
        if not backup.exists():
            target = sqlite3.connect(backup)
            try:
                store.db.backup(target)
            finally:
                target.close()
    with store.db:
        for entity in ENTITIES:
            for row in store.db.execute(f'SELECT id FROM {entity}').fetchall():
                pending = store.db.execute('SELECT 1 FROM cloud_outbox WHERE entity=? AND record_id=?', (entity,str(row['id']))).fetchone()
                mapping(store, entity, row['id'])
                if not pending:
                    store.db.execute('UPDATE cloud_records SET seed_only=1 WHERE entity=? AND local_id=?', (entity,str(row['id'])))
                {'players': store.outbox.player, 'sessions': store.outbox.session,
                 'moves': store.outbox.move}[entity](row['id'])
        store.db.execute("INSERT INTO cloud_meta VALUES ('shared_seed_v2','1')")


def convert_legacy(entity, data):
    origin = data['installation_id']
    value = dict(data, schema_version=2, deleted=False)
    for group, field in (('players', 'player_id'), ('sessions', 'session_id'), ('moves', 'move_id')):
        if field in value:
            value[field] = global_id(origin, group, value[field])
    value.pop('received_at', None)
    value.pop('updated_at', None)
    return value


def decode_documents(documents):
    result = {}
    for entity in ENTITIES:
        result[entity] = {}
        for doc in documents.get(entity, []):
            data = {k: decode_value(v) for k, v in doc['fields'].items()}
            remote = doc['name'].rsplit('/', 1)[-1]
            if data.get('schema_version') != 2 or type(data.get('deleted')) is not bool:
                raise ValueError('Registro compartilhado incompatível; cache anterior preservado.')
            if data.get(ID_FIELD[entity]) != remote or not doc.get('updateTime'):
                raise ValueError('Identidade ou versão remota inválida.')
            if not data['deleted']:
                remote_snapshot({entity: [{'fields': {k: v for k, v in doc['fields'].items() if k != 'schema_version'} |
                                                        {'schema_version': {'integerValue': '1'}}}]})
            result[entity][remote] = (data, doc['updateTime'])
    return result


def tombstone(entity, identifier):
    return {'schema_version': 2, ID_FIELD[entity]: identifier, 'deleted': True}


def _local_id(store, entity, remote):
    row = store.db.execute('SELECT local_id FROM cloud_records WHERE entity=? AND remote_id=?', (entity, remote)).fetchone()
    if row:
        return row['local_id']
    if entity == 'moves':
        # IDs inteiros da interface nunca são reutilizados, mesmo depois de uma exclusão.
        identifier = str(next_move_id(store.db))
    else:
        identifier = remote
    store.db.execute('INSERT INTO cloud_records(entity,local_id,remote_id) VALUES (?,?,?)', (entity, identifier, remote))
    return identifier


def next_move_id(db):
    actual = db.execute('SELECT COALESCE(MAX(id),0) FROM moves').fetchone()[0]
    mapped = db.execute("SELECT COALESCE(MAX(CAST(local_id AS INTEGER)),0) FROM cloud_records WHERE entity='moves'").fetchone()[0]
    return max(actual, mapped) + 1


def _drop(store, entity, identifier):
    db = store.db
    if entity == 'players':
        for row in db.execute('SELECT id FROM sessions WHERE player=?', (identifier,)).fetchall():
            _drop(store, 'sessions', row['id'])
    elif entity == 'sessions':
        for row in db.execute('SELECT id FROM moves WHERE session=?', (identifier,)).fetchall():
            _drop(store, 'moves', row['id'])
    db.execute(f'DELETE FROM {entity} WHERE id=?', (identifier,))
    db.execute('DELETE FROM cloud_outbox WHERE entity=? AND record_id=?', (entity, str(identifier)))


def apply_snapshot(store, snapshot):
    """Aplica uma leitura completa em uma transação e protege edições não confirmadas."""
    db = store.db
    before = db.total_changes
    with db:
        # Exclusão do pai prevalece sobre sessões/jogadas criadas em um cache antigo.
        for entity in ENTITIES:
            for remote, (data, version) in snapshot[entity].items():
                if not data['deleted']:
                    continue
                row = db.execute('SELECT local_id,version FROM cloud_records WHERE entity=? AND remote_id=?', (entity, remote)).fetchone()
                if row and row['version'] != version:
                    _drop(store, entity, row['local_id'])
                    db.execute('UPDATE cloud_records SET version=?,base=? WHERE entity=? AND remote_id=?',
                               (version, json.dumps(data), entity, remote))
        for entity in ENTITIES:
            for remote, (data, version) in snapshot[entity].items():
                if data['deleted']:
                    continue
                identifier = _local_id(store, entity, remote)
                old = db.execute('SELECT * FROM cloud_records WHERE entity=? AND local_id=?', (entity, identifier)).fetchone()
                pending = db.execute('SELECT operation FROM cloud_outbox WHERE entity=? AND record_id=?', (entity, identifier)).fetchone()
                if old['version'] == version and not pending:
                    continue
                if pending and pending['operation'] == 'delete':
                    db.execute('UPDATE cloud_records SET version=?,base=? WHERE entity=? AND local_id=?',
                               (version, json.dumps(data), entity, identifier))
                    continue
                if entity == 'players':
                    local = db.execute('SELECT name FROM players WHERE id=?', (identifier,)).fetchone()
                    baseline = json.loads(old['base']) if old['base'] else {}
                    keep_name = pending and not old['seed_only'] and local and local['name'] != baseline.get('label')
                    name = local['name'] if keep_name else data['label']
                    if not local or local['name'] != name:
                        db.execute('INSERT INTO players VALUES (?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name', (identifier, name))
                elif entity == 'sessions':
                    parent = _local_id(store, 'players', data['player_id'])
                    if not db.execute('SELECT 1 FROM players WHERE id=?', (parent,)).fetchone():
                        continue
                    if not pending or old['seed_only']:
                        db.execute('INSERT INTO sessions VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET player=excluded.player,started=excluded.started',
                                   (identifier, parent, data['started_at']))
                else:
                    parent = _local_id(store, 'sessions', data['session_id'])
                    if not db.execute('SELECT 1 FROM sessions WHERE id=?', (parent,)).fetchone():
                        continue
                    if not pending or old['seed_only']:
                        db.execute('''INSERT INTO moves VALUES (?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET
                            session=excluded.session,time=excluded.time,story=excluded.story,character=excluded.character,
                            result=excluded.result,result_time=excluded.result_time''',
                                   (int(identifier), parent, data['occurred_at'], data['story'], data['character'], data['result'], data['result_at']))
                if old['version'] != version or old['base'] is None:
                    db.execute('UPDATE cloud_records SET version=?,base=? WHERE entity=? AND local_id=?',
                               (version, json.dumps(data), entity, identifier))
        # Recalcula os resumos pendentes com todas as sessões agora disponíveis.
        for row in db.execute("SELECT entity,record_id FROM cloud_outbox WHERE operation='upsert'").fetchall():
            if row['entity'] in ('players', 'sessions') and db.execute(f"SELECT 1 FROM {row['entity']} WHERE id=?", (row['record_id'],)).fetchone():
                {'players': store.outbox.player, 'sessions': store.outbox.session}[row['entity']](row['record_id'])
    return db.total_changes != before


def pending_shared(store, limit=100):
    items = store.outbox.pending(limit)
    result = []
    with store.db:
        for item in items:
            entity, identifier = item['entity'], item['record_id']
            record = mapping(store, entity, identifier)
            if item['operation'] == 'delete':
                data = tombstone(entity, record['remote_id'])
            else:
                data = json.loads(item['payload'])
                data.update(schema_version=2, deleted=False, installation_id=store.outbox.installation_id)
                for group, field in (('players', 'player_id'), ('sessions', 'session_id'), ('moves', 'move_id')):
                    if field in data:
                        data[field] = mapping(store, group, data[field])['remote_id']
            result.append(dict(entity=entity, remote_id=record['remote_id'], data=data,
                               version=record['version'], queued=item))
    return result


class SharedSync:
    def __init__(self, store, client):
        self.store, self.client = store, client
        self.snapshot = {entity: {} for entity in ENTITIES}
        self.cursors = {}
        self.migrated = False
        seed_local(store)

    def pull(self):
        documents, cursors = self.client.shared_changes(self.cursors)
        changes = decode_documents(documents)  # Valida antes de avançar o cursor/cache.
        for entity in ENTITIES:
            self.snapshot[entity].update(changes[entity])
        self.cursors = cursors

    def migrate(self):
        if self.store.db.execute("SELECT 1 FROM cloud_meta WHERE key='legacy_imported_shared_v2'").fetchone():
            self.migrated = True
            return
        # As versões antigas permanecem somente como arquivo histórico de origem.
        documents = self.client.performance_documents(legacy_only=True)
        legacy = remote_snapshot(documents)
        own = remote_snapshot(self.client.performance_documents(self.store.outbox.installation_id, legacy_only=True))
        writes = []
        for entity in ENTITIES:
            for data in legacy[entity] + own[entity]:
                value = convert_legacy(entity, data)
                remote = value[ID_FIELD[entity]]
                if remote in self.snapshot[entity] or any(w['entity'] == entity and w['remote_id'] == remote for w in writes):
                    continue
                writes.append(dict(entity=entity, remote_id=remote, data=value, version=None))
        for offset in range(0, len(writes), 100):
            self.client.commit_shared(writes[offset:offset+100])
        if writes:
            self.pull()
        with self.store.db:
            self.store.db.execute("INSERT OR IGNORE INTO cloud_meta VALUES ('legacy_imported_shared_v2','1')")
        self.migrated = True

    def cycle(self):
        self.pull()
        if not self.migrated:
            self.migrate()
        # Propaga a exclusão de perfis a filhos que outro computador criou offline.
        cascades = []
        deleted = {entity: {key for key, (data, _) in self.snapshot[entity].items() if data['deleted']} for entity in ENTITIES}
        for entity, parent_entity, field in (('sessions', 'players', 'player_id'), ('moves', 'sessions', 'session_id')):
            for remote, (data, version) in list(self.snapshot[entity].items()):
                if not data['deleted'] and data.get(field) in deleted[parent_entity]:
                    value = tombstone(entity, remote)
                    cascades.append(dict(entity=entity, remote_id=remote, data=value, version=version))
                    deleted[entity].add(remote)
        for offset in range(0, len(cascades), 100):
            self.client.commit_shared(cascades[offset:offset+100])
        if cascades:
            self.pull()
        changed = apply_snapshot(self.store, self.snapshot)
        items = pending_shared(self.store)
        if not items:
            return 0, changed
        versions = self.client.commit_shared(items)
        with self.store.db:
            for item, version in zip(items, versions):
                queued = item['queued']
                self.store.db.execute('DELETE FROM cloud_outbox WHERE entity=? AND record_id=? AND revision=?',
                                      (queued['entity'], queued['record_id'], queued['revision']))
                self.store.db.execute('UPDATE cloud_records SET version=?,base=?,seed_only=0 WHERE entity=? AND remote_id=?',
                                      (version, json.dumps(item['data']), item['entity'], item['remote_id']))
                self.snapshot[item['entity']][item['remote_id']] = (item['data'], version)
        return len(items), True
