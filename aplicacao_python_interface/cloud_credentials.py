"""Sessão Firebase no cofre do sistema. Nunca grava senha/token em arquivos do app."""


class CredentialUnavailable(Exception):
    pass


class CredentialVault:
    SERVICE = 'FabulaTEA.Firebase'
    TRUSTED_MODULES = {'keyring.backends.Windows', 'keyring.backends.SecretService',
                       'keyring.backends.macOS', 'keyring.backends.kwallet'}

    def __init__(self, backend=None):
        self._backend_override = backend

    def _backend(self):
        if self._backend_override is not None:
            return self._backend_override
        try:
            import keyring
            selected = keyring.get_keyring()
            candidates = getattr(selected, 'backends', [selected])
            for backend in candidates:
                if type(backend).__module__ in self.TRUSTED_MODULES and backend.priority > 0:
                    return backend
        except Exception:
            pass
        raise CredentialUnavailable('Cofre seguro indisponível. A conexão atual pode ser usada; habilite o cofre do sistema para lembrar o acesso.')

    @staticmethod
    def account(config):
        return f'{config.project_id}/{config.operator_uid}'

    def load(self, config):
        try:
            return self._backend().get_password(self.SERVICE, self.account(config))
        except CredentialUnavailable:
            raise
        except Exception:
            raise CredentialUnavailable('Não foi possível abrir o acesso salvo no cofre do sistema.') from None

    def save(self, config, refresh_token):
        try:
            self._backend().set_password(self.SERVICE, self.account(config), refresh_token)
        except CredentialUnavailable:
            raise
        except Exception:
            raise CredentialUnavailable('Não foi possível salvar o acesso no cofre do sistema.') from None

    def delete(self, config):
        try:
            backend = self._backend()
            if backend.get_password(self.SERVICE, self.account(config)) is not None:
                backend.delete_password(self.SERVICE, self.account(config))
        except CredentialUnavailable:
            raise
        except Exception:
            raise CredentialUnavailable('Não foi possível remover o acesso salvo do cofre do sistema.') from None
