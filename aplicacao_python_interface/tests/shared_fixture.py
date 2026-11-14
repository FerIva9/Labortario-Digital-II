"""Servidor Firestore determinístico para testes de várias instalações e concorrência."""
import copy
from datetime import datetime, timedelta, timezone
import threading
from cloud_firebase import FirebaseError, firestore_value


class SharedServer:
    def __init__(self):
        self.documents = {entity: {} for entity in ('players', 'sessions', 'moves')}
        self.online = True
        self.lock = threading.RLock()
        self.counter = 0
        self.legacy = {entity: [] for entity in self.documents}
        self.before_commit = None

    def client(self):
        server = self
        class Client:
            _refresh_token = 'refresh-ficticio'
            on_refresh_token = None
            def restore(self, token): pass
            def sign_in(self, email, password): pass
            def register_installation(self, installation): pass
            def performance_documents(self, *args, **kwargs):
                return copy.deepcopy(server.legacy)
            def shared_changes(self, cursors):
                with server.lock:
                    if not server.online:
                        raise FirebaseError('Offline fictício', retryable=True)
                    documents = {entity: [copy.deepcopy(doc) for doc in rows.values()
                                         if not cursors.get(entity) or doc['updateTime'] >= cursors[entity]]
                                 for entity, rows in server.documents.items()}
                    return documents, {entity: server.time() for entity in documents}
            def commit_shared(self, items):
                with server.lock:
                    if not server.online:
                        raise FirebaseError('Offline fictício', retryable=True)
                    if server.before_commit:
                        hook, server.before_commit = server.before_commit, None
                        hook()
                    for item in items:
                        current = server.documents[item['entity']].get(item['remote_id'])
                        version = current['updateTime'] if current else None
                        if version != item['version']:
                            raise FirebaseError('Conflito fictício', retryable=True, status=412)
                        if current and current['fields']['deleted']['booleanValue'] and not item['data']['deleted']:
                            raise FirebaseError('Ressurreição indevida', status=403)
                    server.counter += 1
                    version = server.time()
                    for item in items:
                        data = dict(item['data'], updated_at=version)
                        fields = {k: firestore_value(v, k) for k,v in data.items()}
                        from performance_data import parse_time
                        for value in fields.values():
                            if 'timestampValue' in value:
                                value['timestampValue'] = parse_time(value['timestampValue']).astimezone(timezone.utc).isoformat().replace('+00:00', 'Z')
                        server.documents[item['entity']][item['remote_id']] = {
                            'name': f"fake/{item['entity']}/{item['remote_id']}", 'updateTime': version,
                            'fields': fields}
                    return [version for _ in items]
        return Client()

    def time(self):
        return (datetime(2026,1,1,tzinfo=timezone.utc)+timedelta(microseconds=self.counter)).isoformat()
