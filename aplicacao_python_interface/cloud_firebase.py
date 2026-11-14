"""Firebase Auth + Firestore REST via HTTPS. Não usa credenciais administrativas."""
from dataclasses import asdict, dataclass
from datetime import datetime
import json
import math
from pathlib import Path
import queue
import re
import threading
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from player_store import PlayerStore
from cloud_credentials import CredentialUnavailable, CredentialVault
from runtime_paths import cloud_config_path, cloud_defaults_path


class FirebaseError(Exception):
    def __init__(self, message, *, retryable=False, status=None):
        super().__init__(message)
        self.retryable = retryable
        self.status = status


@dataclass(frozen=True)
class CloudConfig:
    project_id: str
    api_key: str
    operator_uid: str
    sync_interval_seconds: int = 60

    def validate(self):
        if not isinstance(self.project_id, str) or not re.fullmatch(r'[a-z][a-z0-9-]{4,28}[a-z0-9]', self.project_id):
            raise ValueError('Informe o ID do projeto Firebase (6 a 30 caracteres), não o nome de exibição.')
        if not isinstance(self.api_key, str) or not self.api_key.strip() or self.api_key != self.api_key.strip():
            raise ValueError('Informe a Web API Key do projeto, sem espaços nas extremidades.')
        if not isinstance(self.operator_uid, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,128}', self.operator_uid):
            raise ValueError('Informe o UID da conta responsável, copiado de Authentication > Users.')
        if type(self.sync_interval_seconds) is not int or not 5 <= self.sync_interval_seconds <= 300:
            raise ValueError('O intervalo de sincronização deve estar entre 5 e 300 segundos.')
        return self

    @classmethod
    def load(cls, path):
        data = json.loads(Path(path).read_text(encoding='utf-8'))
        if not isinstance(data, dict) or set(data) - {'project_id', 'api_key', 'operator_uid', 'sync_interval_seconds'}:
            raise ValueError('Configuração inválida. Use somente project_id, api_key, operator_uid e sync_interval_seconds.')
        try:
            return cls(**data).validate()
        except TypeError:
            raise ValueError('A configuração precisa de project_id, api_key e operator_uid.') from None

    @classmethod
    def load_active(cls, local_path=None, defaults_path=None):
        local = Path(local_path) if local_path is not None else cloud_config_path()
        default = Path(defaults_path) if defaults_path is not None else cloud_defaults_path()
        return cls.load(local if local.is_file() else default)

    def save(self, path):
        self.validate()
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix('.tmp')
        temporary.write_text(json.dumps(asdict(self), indent=2) + '\n', encoding='utf-8')
        temporary.replace(path)


def firestore_value(value, field=None):
    if value is None:
        return {'nullValue': None}
    if isinstance(value, bool):
        return {'booleanValue': value}
    if isinstance(value, int):
        return {'integerValue': str(value)}
    if isinstance(value, float):
        if not math.isfinite(value):
            raise ValueError('Número não finito na fila de sincronização.')
        return {'doubleValue': value}
    if isinstance(value, str):
        if field in {'started_at', 'occurred_at', 'result_at'}:
            datetime.fromisoformat(value)  # Valida o formato mantido pelo banco local.
            return {'timestampValue': value}
        return {'stringValue': value}
    if isinstance(value, dict):
        return {'mapValue': {'fields': {str(k): firestore_value(v, str(k)) for k, v in value.items()}}}
    raise ValueError('Tipo de dado não suportado para sincronização.')


def request_json(method, url, payload=None, token=None, *, form=False):
    headers = {'Accept': 'application/json'}
    data = None
    if payload is not None:
        data = urlencode(payload).encode() if form else json.dumps(payload, allow_nan=False).encode()
        headers['Content-Type'] = 'application/x-www-form-urlencoded' if form else 'application/json'
    if token:
        headers['Authorization'] = f'Bearer {token}'
    request = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(request, timeout=12) as response:
            return json.load(response)
    except HTTPError as error:
        # Não propaga URLs, corpo de resposta ou tokens nas mensagens da interface.
        status = error.code
        service_status = ''
        api_reason = ''
        try:
            details = json.loads(error.read()).get('error', {})
            reason = details.get('message', '').split(' : ')[0]
            service_status = details.get('status', '')
            for detail in details.get('details', []):
                if isinstance(detail, dict) and detail.get('@type', '').endswith('google.rpc.ErrorInfo'):
                    api_reason = detail.get('reason', '')
                    break
        except (ValueError, AttributeError, TypeError):
            reason = ''
        finally:
            error.close()
        # Sem diferenciar cota diária de limitação transitória, pausa para evitar
        # novas tentativas contínuas. Os dados continuam na fila local.
        if status == 429 or service_status == 'RESOURCE_EXHAUSTED':
            raise FirebaseError('Limite de cota ou de requisições atingido. Confira Usage no Firebase e reconecte após a cota ou o limite voltar a permitir operações.', status=status) from None
        messages = {
            'INVALID_LOGIN_CREDENTIALS': 'Email ou senha inválidos.',
            'EMAIL_NOT_FOUND': 'Email ou senha inválidos.',
            'INVALID_PASSWORD': 'Email ou senha inválidos.',
            'USER_DISABLED': 'A conta Firebase está desativada.',
            'OPERATION_NOT_ALLOWED': 'Habilite Email/Password em Firebase Authentication.',
            'API_KEY_INVALID': 'Web API Key inválida.',
            'TOO_MANY_ATTEMPTS_TRY_LATER': 'Muitas tentativas. Aguarde antes de conectar novamente.',
        }
        api_messages = {
            'SERVICE_DISABLED': 'API necessária desabilitada. Confira Identity Toolkit, Token Service e Cloud Firestore no projeto correto.',
            'API_KEY_SERVICE_BLOCKED': 'A restrição da Web API Key bloqueia a API necessária. Confira as APIs permitidas na chave.',
            'API_KEY_HTTP_REFERRER_BLOCKED': 'A Web API Key exige um site de origem. Essa restrição não é compatível com a aplicação desktop.',
            'API_KEY_IP_ADDRESS_BLOCKED': 'A Web API Key bloqueia o endereço IP desta conexão.',
            'API_KEY_INVALID': 'Web API Key inválida.',
        }
        message = api_messages.get(api_reason) or messages.get(reason)
        if message is None:
            message = {401: 'Sessão Firebase inválida. Conecte novamente.',
                       403: 'Acesso negado. Confira as regras, o UID, a autorização do operador e as APIs habilitadas.',
                       404: 'Documento ou banco não encontrado. Confira o projeto e o banco (default).' }.get(status, f'Firebase retornou HTTP {status}. Confira a configuração.')
        raise FirebaseError(message, retryable=status >= 500, status=status) from None
    except (URLError, TimeoutError, OSError):
        raise FirebaseError('Sem acesso HTTPS ao Firebase. Confira a internet, certificados e proxy.', retryable=True) from None
    except (ValueError, UnicodeError):
        raise FirebaseError('Resposta inválida do Firebase.') from None


class FirestoreClient:
    def __init__(self, config, transport=request_json):
        self.config = config.validate()
        self.transport = transport
        self._id_token = None
        self._refresh_token = None
        self._expires_at = 0
        self.on_refresh_token = None
        self._registered_installations = set()
        self.base = f'https://firestore.googleapis.com/v1/projects/{config.project_id}/databases/(default)/documents'

    def _request(self, stage, *args, **kwargs):
        try:
            return self.transport(*args, **kwargs)
        except FirebaseError as error:
            status = f'HTTP {error.status}: ' if error.status else ''
            raise FirebaseError(f'{stage} — {status}{error}',
                                retryable=error.retryable, status=error.status) from None

    def sign_in(self, email, password):
        result = self._request('Login Firebase', 'POST', 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?' + urlencode({'key': self.config.api_key}),
                                {'email': email.strip(), 'password': password, 'returnSecureToken': True})
        if result.get('localId') != self.config.operator_uid:
            raise FirebaseError('A conta autenticada não corresponde ao UID configurado. Nenhum dado foi enviado.')
        self._set_tokens(result['idToken'], result['refreshToken'], result['expiresIn'])
        self._check_operator()

    def restore(self, refresh_token):
        self._refresh_token = refresh_token
        self._expires_at = 0
        self.token()
        self._check_operator()

    def _check_operator(self):
        document = self._request(f'Autorização do operador: operators/{self.config.operator_uid}',
                                 'GET', self.base + f'/operators/{self.config.operator_uid}', token=self.token())
        if document.get('fields', {}).get('enabled', {}).get('booleanValue') is not True:
            raise FirebaseError('Operador sem autorização: crie operators/UID com enabled=true no Console.')

    def _set_tokens(self, token, refresh, expires):
        self._id_token, self._refresh_token = token, refresh
        self._expires_at = time.monotonic() + int(expires) - 60
        if self.on_refresh_token:
            self.on_refresh_token(refresh)

    def token(self):
        if not self._refresh_token:
            raise FirebaseError('Conecte à conta Firebase antes de sincronizar.')
        if time.monotonic() >= self._expires_at:
            result = self._request('Renovação da sessão Firebase', 'POST', 'https://securetoken.googleapis.com/v1/token?' + urlencode({'key': self.config.api_key}),
                                    {'grant_type': 'refresh_token', 'refresh_token': self._refresh_token}, form=True)
            if result.get('user_id') != self.config.operator_uid:
                raise FirebaseError('A renovação de sessão retornou outro UID. Conecte novamente.')
            self._set_tokens(result['id_token'], result['refresh_token'], result['expires_in'])
        return self._id_token

    def document_path(self, installation, entity, record_id):
        if entity not in {'players', 'sessions', 'moves'}:
            raise ValueError('Coleção de sincronização inválida.')
        if not all(re.fullmatch(r'[A-Za-z0-9_-]{1,128}', str(part)) for part in (installation, record_id)):
            raise ValueError('Identificador de sincronização inválido.')
        return f'operators/{self.config.operator_uid}/installations/{installation}/{entity}/{record_id}'

    def commit(self, installation, items):
        if not items:
            return
        if len(items) > 100:
            raise ValueError('Use lotes de até 100 documentos.')
        writes = []
        for item in items:
            path = self.document_path(installation, item['entity'], item['record_id'])
            name = self.base.removeprefix('https://firestore.googleapis.com/v1/') + '/' + path
            if item['operation'] == 'delete':
                writes.append({'delete': name})
            else:
                payload = json.loads(item['payload'])
                fields = {k: firestore_value(v, k) for k, v in payload.items()}
                fields['installation_id'] = firestore_value(installation)
                writes.append({'update': {'name': name, 'fields': fields},
                               'updateTransforms': [{'fieldPath': 'received_at', 'setToServerValue': 'REQUEST_TIME'}]})
        self._request('Envio de documentos ao Firestore', 'POST', self.base + ':commit', {'writes': writes}, token=self.token())

    def get_document(self, installation, entity, record_id):
        path = self.document_path(installation, entity, record_id)
        return self.transport('GET', self.base + '/' + path, token=self.token())

    def list_documents(self, path, *, show_missing=False):
        """Lê todas as páginas, sem limitar silenciosamente o histórico."""
        documents = []
        page = None
        seen_pages = set()
        while True:
            params = {'pageSize': 300}
            if show_missing:
                params['showMissing'] = 'true'
            if page:
                params['pageToken'] = page
            result = self._request('Consulta de acompanhamento no Firestore', 'GET',
                                   self.base + '/' + path + '?' + urlencode(params), token=self.token())
            documents.extend(result.get('documents', []))
            next_page = result.get('nextPageToken')
            if not next_page:
                return documents
            if next_page in seen_pages:
                raise FirebaseError('Paginação inválida no Firestore. A consulta não foi concluída.')
            seen_pages.add(next_page)
            page = next_page

    def register_installation(self, installation):
        """Índice mínimo para descoberta com autenticação Firebase comum."""
        self.document_path(installation, 'players', 'validation')
        if installation in self._registered_installations:
            return
        path = f'operators/{self.config.operator_uid}/installations/{installation}'
        self._request('Registro da instalação no Firestore', 'PATCH', self.base + '/' + path,
                      {'fields': {'installation_id': firestore_value(installation), 'schema_version': firestore_value(1)}},
                      token=self.token())
        self._registered_installations.add(installation)

    def delete_installation_registration(self, installation):
        """Usado exclusivamente pela limpeza da instalação fictícia de ensaio."""
        self.document_path(installation, 'players', 'validation')
        path = f'operators/{self.config.operator_uid}/installations/{installation}'
        self._request('Limpeza do registro da instalação de teste', 'DELETE', self.base + '/' + path, token=self.token())
        self._registered_installations.discard(installation)

    def performance_documents(self, installation=None):
        """Consulta apenas instalações do operador autenticado, sem importar no SQLite."""
        parent = f'operators/{self.config.operator_uid}/installations'
        if installation:
            self.document_path(installation, 'players', 'validation')
            installations = [installation]
        else:
            installations = [doc['name'].rsplit('/', 1)[-1]
                             for doc in self.list_documents(parent)]
        result = {entity: [] for entity in ('players', 'sessions', 'moves')}
        for identifier in installations:
            self.document_path(identifier, 'players', 'validation')
            for entity in result:
                result[entity].extend(self.list_documents(f'{parent}/{identifier}/{entity}'))
        return result


def sync_once(store, client):
    client.register_installation(store.outbox.installation_id)
    items = store.outbox.pending()
    if not items:
        return 0
    client.commit(store.outbox.installation_id, items)
    store.outbox.acknowledge(items)
    return len(items)


class SyncWorker:
    """Sincroniza em segundo plano com autenticação persistida no cofre do SO."""
    def __init__(self, db_path, config, email=None, password=None, *, remember=False,
                 vault=None, allow_rebind=False, forget_saved=False):
        self.db_path, self.config = db_path, config
        self._email, self._password = email, password
        self.remember = remember
        from cloud_portable import PortableVault
        self.vault = vault if vault is not None else PortableVault()
        self.allow_rebind = allow_rebind
        self.forget_saved = forget_saved
        self.events = queue.Queue()
        self._stop = threading.Event()
        self._wake = threading.Event()
        self._remember_requested = threading.Event()
        self.thread = threading.Thread(target=self.run, name='FirebaseSync', daemon=True)
        self._credential_notice = ''

    def start(self):
        self.thread.start()

    def stop(self):
        self._stop.set()
        self._wake.set()

    @property
    def stopping(self):
        return self._stop.is_set()

    def request_sync(self, *, remember=False):
        if remember:
            self.remember = True
            self._remember_requested.set()
        self._wake.set()

    def _save_token(self, token):
        try:
            self.vault.save(self.config, token)
            self._credential_notice = ''
        except CredentialUnavailable:
            self._credential_notice = ' · acesso não salvo: cofre indisponível'

    def _authenticate(self, client):
        token = None
        if not self._email or not self._password:
            try:
                token = self.vault.load(self.config)
            except CredentialUnavailable as error:
                self.events.put(f'Modo local · {error}')
                return False
            if not token:
                self.events.put('Modo local · conecte a conta uma vez em Nuvem para ativar o envio automático')
                return False
        backoff = 3
        while not self._stop.is_set():
            try:
                if token:
                    client.restore(token)
                else:
                    client.sign_in(self._email, self._password)
                self._password = self._email = None
                if self.remember:
                    self._save_token(client._refresh_token)
                    client.on_refresh_token = self._save_token
                elif self.forget_saved:
                    try:
                        self.vault.delete(self.config)
                    except CredentialUnavailable:
                        self._credential_notice = ' · acesso antigo não pôde ser removido do cofre'
                return True
            except FirebaseError as error:
                if not error.retryable:
                    raise
                self.events.put(f'Modo local · {error} Reconexão automática pendente.')
                self._stop.wait(backoff)
                backoff = min(backoff * 2, 120)
        return False

    def run(self):
        store = None
        try:
            self.events.put('Conectando automaticamente ao Firebase…')
            client = FirestoreClient(self.config)
            if not self._authenticate(client) or self._stop.is_set():
                return
            store = PlayerStore(self.db_path)
            if self.allow_rebind:
                store.outbox.bind(self.config.project_id, self.config.operator_uid, allow_change=True)
            else:
                store.outbox.bind(self.config.project_id, self.config.operator_uid)
            backoff = 3
            while not self._stop.is_set():
                try:
                    if self._remember_requested.is_set():
                        self._remember_requested.clear()
                        client.on_refresh_token = self._save_token
                        self._save_token(client._refresh_token)
                    sent = sync_once(store, client)
                    pending = store.outbox.count()
                    status = f'Sincronizando · {pending} pendências' if pending else 'Nuvem em dia · sem pendências'
                    self.events.put(status + self._credential_notice)
                    backoff = 3
                    if not sent or not pending:
                        changed = self._wake.wait(self.config.sync_interval_seconds)
                        self._wake.clear()
                        if changed:
                            # Agrupa a apresentação e seu R0/R1 sem esperar um minuto.
                            self._stop.wait(.35)
                except FirebaseError as error:
                    if not error.retryable:
                        raise
                    self.events.put(f'Modo local · {error} Reconexão automática pendente.')
                    self._stop.wait(backoff)
                    backoff = min(backoff * 2, 120)
        except (FirebaseError, ValueError, OSError, KeyError) as error:
            self.events.put(f'Sincronização pausada: coleta local ativa · {error}')
        except Exception:
            self.events.put('Sincronização pausada por falha local. Os registros continuam na fila.')
        finally:
            self._password = self._email = None
            if store:
                store.close()
