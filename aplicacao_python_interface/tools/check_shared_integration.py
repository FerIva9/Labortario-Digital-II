"""Ensaio bidirecional: emulador local ou Firebase explícito com acesso salvo."""
import argparse
import base64
from dataclasses import replace
import json
from pathlib import Path
import sys
import tempfile
import time
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from cloud_firebase import CloudConfig, FirestoreClient, FirebaseError, request_json, SyncWorker
from cloud_credentials import CredentialUnavailable
from cloud_portable import PortableVault
from cloud_replica import SharedSync, global_id
from player_store import PlayerStore, summarize
from protocol import Event


def drain(sync):
    for _ in range(100):
        sent, _ = sync.cycle()
        if not sent:
            return
    raise RuntimeError('Fila não concluiu o envio.')


def scope_test_client(value, scope):
    """Limita o ensaio real ao perfil fictício, sem migrar históricos de produção."""
    read = value.shared_changes
    commit = value.commit_shared
    performance = value.performance_documents
    def shared_changes(cursors):
        if scope['player'] is None:
            raise RuntimeError('Perfil fictício ainda não inicializado.')
        documents, updated = read(cursors)
        filtered = {entity: [] for entity in documents}
        for entity, rows in documents.items():
            for doc in rows:
                identifier = doc['name'].rsplit('/', 1)[-1]
                parent = doc.get('fields', {}).get('player_id', {}).get('stringValue')
                if (entity == 'players' and identifier == scope['player']) or \
                   (entity != 'players' and parent == scope['player']) or identifier in scope[entity]:
                    filtered[entity].append(doc)
                    scope[entity].add(identifier)
        return filtered, updated
    def commit_shared(items):
        if scope['player'] is None:
            raise RuntimeError('Perfil fictício ainda não inicializado.')
        for item in items:
            entity, identifier, data = item['entity'], item['remote_id'], item['data']
            permitted = (identifier in scope[entity] if data['deleted'] else
                         identifier == scope['player'] if entity == 'players' else
                         data.get('player_id') == scope['player'])
            if not permitted:
                raise RuntimeError('Ensaio bloqueou uma escrita fora dos dados fictícios.')
        # Registra todos os IDs antes do envio para permitir limpar também uma resposta perdida.
        for item in items:
            scope[item['entity']].add(item['remote_id'])
        return commit(items)
    def performance_documents(*args, **kwargs):
        if kwargs.get('legacy_only'):
            return {entity: [] for entity in ('players', 'sessions', 'moves')}
        return performance(*args, **kwargs)
    value.shared_changes = shared_changes
    value.commit_shared = commit_shared
    value.performance_documents = performance_documents
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--saved-access', action='store_true', help='compatibilidade: o ensaio remoto sempre usa acesso salvo')
    parser.add_argument('--config', type=Path, help='configuração local opcional')
    parser.add_argument('--emulator', action='store_true', help='usa apenas http://127.0.0.1:8686 e projeto demo-fabula')
    parser.add_argument('--run-live', action='store_true', help='autoriza ensaio no Firebase real restrito aos dados fictícios, sem migrar históricos reais')
    args = parser.parse_args()
    if not args.emulator and not args.run_live:
        print('Sem requisições. Use --emulator ou --run-live. O ensaio remoto exige as novas regras publicadas.')
        return 0
    if args.emulator:
        config = CloudConfig('demo-fabula','chave-ficticia','testoperator')
        def encode(value):
            return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip('=')
        token = encode({'alg':'none','typ':'JWT'})+'.'+encode({'sub':config.operator_uid,'user_id':config.operator_uid,
                'aud':config.project_id,'iss':f'https://securetoken.google.com/{config.project_id}',
                'iat':int(time.time()),'exp':int(time.time())+3600,'auth_time':int(time.time()),
                'firebase':{'sign_in_provider':'password'}})+'.'
        base = f'http://127.0.0.1:8686/v1/projects/{config.project_id}/databases/(default)/documents'
        request_json('PATCH',base+f'/operators/{config.operator_uid}', {'fields':{'enabled':{'booleanValue':True}}}, token='owner')
        def client():
            value=FirestoreClient(config)
            value.base=base
            value._id_token=token
            value._refresh_token='emulator-fake'
            value._expires_at=float('inf')
            value._check_operator()
            value.restore = lambda token: value._check_operator()
            return value
    else:
        config = CloudConfig.load_active(local_path=args.config)
        vault = PortableVault()
        token = vault.load(config)
        if not token: raise ValueError('Acesso salvo ausente.')
        scope = dict(player=None, players=set(), sessions=set(), moves=set())
        def client():
            value=FirestoreClient(config)
            value.restore(token)
            vault.save(config,value._refresh_token)
            return scope_test_client(value, scope)
    with tempfile.TemporaryDirectory() as folder:
        a,b=PlayerStore(Path(folder)/'a.sqlite3'),PlayerStore(Path(folder)/'b.sqlite3')
        sa,sb=SharedSync(a,client()),SharedSync(b,client())
        player=None
        try:
            player=a.add_player('ENSAIO COMPARTILHADO FICTÍCIO')
            if not args.emulator:
                scope['player'] = global_id(a.outbox.installation_id, 'players', player)
            session=a.session(player)
            a.result(a.move(session,Event(2,3)),True)
            drain(sa); drain(sb)
            remote_id=a.db.execute("SELECT remote_id FROM cloud_records WHERE entity='players' AND local_id=?",(player,)).fetchone()[0]
            foreign=b.db.execute("SELECT local_id FROM cloud_records WHERE entity='players' AND remote_id=?",(remote_id,)).fetchone()[0]
            assert summarize(b.history(foreign))==(1,1,100.0)
            print('OK: jogador, sessão e acerto criados em A disponíveis em B.')
            initial_version=sa.snapshot['players'][remote_id][1]
            b.rename_player(foreign,'NOME FICTÍCIO ALTERADO EM B')
            b.result(b.move(b.session(foreign),Event(2,3)),False)
            drain(sb); drain(sa)
            assert a.db.execute('SELECT name FROM players WHERE id=?',(player,)).fetchone()[0]=='NOME FICTÍCIO ALTERADO EM B'
            assert summarize(a.history(player))==(2,1,50.0)
            print('OK: renomeação e sessão de B reunidas ao histórico de A, com 50% de acertos.')
            if args.emulator:
                active=dict(sa.snapshot['players'][remote_id][0])
                try: sa.client.commit_shared([dict(entity='players',remote_id=remote_id,data=active,version=initial_version)])
                except FirebaseError as error:
                    assert error.retryable, 'Conflito real de versão não foi classificado para nova tentativa.'
                else: raise AssertionError('Atualização com versão antiga foi aceita.')
                print('OK: escrita com versão antiga exige reconciliação automática.')
            if args.emulator:
                target=sa.client.base+f'/operators/{config.operator_uid}/installations/shared/players/{remote_id}'
                for label,url,auth in [('sem autenticação',target,None),('outro operador',target.replace('/testoperator/','/outro/'),sa.client.token())]:
                    try: request_json('GET',url,token=auth)
                    except FirebaseError as error: assert error.status in (401,403)
                    else: raise AssertionError('Acesso indevido permitido.')
                    print('OK: acesso negado — '+label)
            class SessionVault:
                def load(self, cfg): return token
                def save(self, cfg, value): pass
            extra=b.session(foreign)
            # Reduz somente o intervalo deste ensaio; a configuração do usuário não muda.
            worker=SyncWorker(Path(folder)/'b.sqlite3',replace(config, sync_interval_seconds=5),vault=SessionVault(),client_factory=lambda cfg: client())
            worker.start()
            try:
                deadline=time.monotonic()+45
                while b.outbox.count() and time.monotonic()<deadline:
                    if not worker.thread.is_alive(): raise RuntimeError('Trabalhador automático encerrou.')
                    time.sleep(.05)
                assert b.outbox.count()==0
                drain(sa)
                assert a.db.execute('SELECT count(*) FROM sessions WHERE player=?',(player,)).fetchone()[0]==3
                print('OK: trabalhador em segundo plano envia sessão e consulta mudanças automaticamente.')
                a.rename_player(player, 'ALTERAÇÃO AUTOMÁTICA FICTÍCIA EM A')
                drain(sa)
                deadline=time.monotonic()+45
                while time.monotonic()<deadline:
                    if not worker.thread.is_alive():
                        raise RuntimeError('Trabalhador encerrou durante a recepção automática.')
                    row=b.db.execute('SELECT name FROM players WHERE id=?',(foreign,)).fetchone()
                    if row and row['name']=='ALTERAÇÃO AUTOMÁTICA FICTÍCIA EM A':
                        break
                    time.sleep(.05)
                else:
                    raise RuntimeError('Instalação ociosa não recebeu a alteração remota automaticamente.')
                print('OK: instalação ociosa recebe alteração de outra instalação sem consulta manual.')
            finally:
                worker.stop(); worker.thread.join(15)
                assert not worker.thread.is_alive()
            active = dict(sa.snapshot['players'][remote_id][0])
            a.delete_player(player); drain(sa); drain(sb)
            assert not b.db.execute('SELECT 1 FROM players WHERE id=?',(foreign,)).fetchone()
            # Um cache antigo não deve recriar o perfil ao reconectar.
            drain(SharedSync(b,client()))
            assert not b.db.execute('SELECT 1 FROM players WHERE id=?',(foreign,)).fetchone()
            print('OK: exclusão propagada e persistente após reinício.')
            if args.emulator:
                current=sa.snapshot['players'][remote_id][1]
                try: sa.client.commit_shared([dict(entity='players',remote_id=remote_id,data=active,version=current)])
                except FirebaseError as error: assert error.status==403
                else: raise AssertionError('Recriação de perfil excluído foi aceita.')
                print('OK: regras impedem restaurar perfil excluído.')
            player=None
        finally:
            try:
                if player:
                    a.delete_player(player); drain(sa)
            finally:
                a.close(); b.close()
    print('OK: dados fictícios removidos; restam somente marcadores de exclusão sem nomes.')
    return 0


if __name__=='__main__':
    try: raise SystemExit(main())
    except (FirebaseError,CredentialUnavailable,ValueError,OSError,AssertionError,RuntimeError) as error:
        print(f'Ensaio não concluído: {error}',file=sys.stderr)
        raise SystemExit(1)
