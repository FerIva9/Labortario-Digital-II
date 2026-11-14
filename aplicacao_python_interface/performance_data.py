"""Modelo de acompanhamento de jogo, independente de Tk e sem inferência clínica."""
from collections import defaultdict
from datetime import date, datetime, timezone


def parse_time(value):
    # Python 3.10 não aceita o sufixo Z diretamente em fromisoformat.
    return datetime.fromisoformat(value.replace('Z', '+00:00'))


def utc_day(value):
    return parse_time(value).astimezone(timezone.utc).date().isoformat()


def decode_value(value):
    for kind in ('stringValue', 'timestampValue', 'booleanValue'):
        if kind in value:
            return value[kind]
    if 'integerValue' in value:
        return int(value['integerValue'])
    if 'doubleValue' in value:
        return float(value['doubleValue'])
    if 'mapValue' in value:
        return {k: decode_value(v) for k, v in value['mapValue'].get('fields', {}).items()}
    if 'nullValue' in value:
        return None
    raise ValueError('Campo Firestore não suportado no acompanhamento.')


def local_snapshot(store):
    installation = store.outbox.installation_id
    return {
        'players': [dict(installation_id=installation, player_id=r['id'], label=r['name']) for r in store.players()],
        'sessions': [dict(installation_id=installation, session_id=r['id'], player_id=r['player'], started_at=r['started'])
                     for r in store.db.execute('SELECT * FROM sessions')],
        'moves': [dict(installation_id=installation, move_id=str(r['id']), session_id=r['session'],
                       player_id=r['player'], occurred_at=r['time'], story=r['story'], character=r['character'],
                       result=r['result'], result_at=r['result_time'])
                  for r in store.db.execute('SELECT m.*, s.player FROM moves m JOIN sessions s ON s.id=m.session')],
    }


def remote_snapshot(documents):
    result = {}
    for entity, rows in documents.items():
        result[entity] = []
        for document in rows:
            data = {key: decode_value(value) for key, value in document.get('fields', {}).items()}
            if data.get('schema_version') != 1 or not data.get('installation_id'):
                raise ValueError('Documento remoto incompatível; atualização não aplicada.')
            required = {'players': ('player_id', 'label'),
                        'sessions': ('player_id', 'session_id', 'started_at'),
                        'moves': ('player_id', 'session_id', 'move_id', 'occurred_at', 'story', 'character', 'result', 'result_at')}[entity]
            if any(key not in data for key in required):
                raise ValueError('Documento remoto incompleto; atualização não aplicada.')
            if entity == 'moves':
                if (type(data['story']) is not int or not 0 <= data['story'] <= 3 or
                        type(data['character']) is not int or not 0 <= data['character'] <= 5 or
                        (data['result'] is not None and (type(data['result']) is not int or data['result'] not in (0, 1)))):
                    raise ValueError('Jogada remota inválida.')
            if entity in ('sessions', 'moves'):
                dt = parse_time(data['started_at'] if entity == 'sessions' else data['occurred_at'])
                if dt.tzinfo is None:
                    raise ValueError('Horário remoto sem fuso.')
            result[entity].append(data)
    return result


def identity(row, field='player_id'):
    return row['installation_id'], row[field]


def metrics(rows):
    evaluated = [r for r in rows if r['result'] is not None]
    correct = sum(r['result'] == 1 for r in evaluated)
    errors = len(evaluated) - correct
    best = streak = 0
    for row in sorted(rows, key=lambda r: (parse_time(r['occurred_at']), str(r['move_id']))):
        # Uma apresentação sem resultado interrompe a sequência observável.
        streak = streak + 1 if row['result'] == 1 else 0
        best = max(best, streak)
    return {'presentations': len(rows), 'evaluated': len(evaluated), 'correct': correct,
            'errors': errors, 'missing': len(rows) - len(evaluated),
            'accuracy': 100 * correct / len(evaluated) if evaluated else None,
            'coverage': 100 * len(evaluated) / len(rows) if rows else None, 'best_streak': best}


def rate(value):
    return '—' if value is None else f'{value:.1f}%'


def grouped(rows, key):
    groups = defaultdict(list)
    for row in rows:
        groups[key(row)].append(row)
    return [(label, metrics(group)) for label, group in sorted(groups.items())]


def report(snapshot, *, player=None, session=None, start='', end='', story=None):
    for value in (start, end):
        if value:
            if date.fromisoformat(value).isoformat() != value:
                raise ValueError('Use datas no formato AAAA-MM-DD.')
    if start and end and start > end:
        raise ValueError('A data inicial deve ser anterior ou igual à final.')
    def period(value):
        day = utc_day(value)
        return (not start or day >= start) and (not end or day <= end)
    rows = [r for r in snapshot['moves'] if (player is None or identity(r) == player)
            and (session is None or identity(r, 'session_id') == session)
            and (story is None or r['story'] == story) and period(r['occurred_at'])]
    rows.sort(key=lambda r: (parse_time(r['occurred_at']), r['installation_id'], str(r['move_id'])))
    sessions_with_moves = {identity(r, 'session_id') for r in rows}
    sessions = [s for s in snapshot['sessions'] if (player is None or identity(s) == player)
                and (session is None or identity(s, 'session_id') == session)
                and (identity(s, 'session_id') in sessions_with_moves or
                     (story is None and period(s['started_at'])))]
    active_players = {identity(s) for s in sessions} | {identity(r) for r in rows}
    players = [p for p in snapshot['players'] if (player is None or identity(p) == player)
               and (not (start or end or session or story is not None) or identity(p) in active_players)]
    # Leituras durante sincronização parcial podem conter jogadas antes do perfil.
    known = {identity(p) for p in players}
    for key in sorted(active_players - known):
        players.append({'installation_id': key[0], 'player_id': key[1], 'label': f'Jogador {key[1][:8]} (perfil pendente)'})
    per_player = []
    for p in players:
        moves = [r for r in rows if identity(r) == identity(p)]
        player_sessions = [s for s in sessions if identity(s) == identity(p)]
        evolution = []
        for s in sorted(player_sessions, key=lambda s: parse_time(s['started_at'])):
            value = metrics([r for r in moves if identity(r, 'session_id') == identity(s, 'session_id')])['accuracy']
            if value is not None:
                evolution.append(value)
        per_player.append((p, metrics(moves), len(player_sessions),
                           evolution[-1] - evolution[0] if len(evolution) > 1 else None))
    return {'moves': rows, 'sessions': sessions, 'players': per_player, 'totals': metrics(rows),
            'daily': grouped(rows, lambda r: utc_day(r['occurred_at'])),
            'stories': grouped(rows, lambda r: r['story']),
            'characters': grouped(rows, lambda r: (r['story'], r['character']))}
