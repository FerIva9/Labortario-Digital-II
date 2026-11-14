"""Preferências locais. Segredos pertencem exclusivamente ao cofre do SO."""
from dataclasses import asdict, dataclass
import json
from pathlib import Path


@dataclass
class CloudPreferences:
    automatic: bool = True
    remember_login: bool = True
    email: str = ''

    @classmethod
    def load(cls, path):
        path = Path(path)
        if not path.is_file():
            return cls()
        try:
            values = json.loads(path.read_text(encoding='utf-8'))
            result = cls(**values)
            if type(result.automatic) is not bool or type(result.remember_login) is not bool or not isinstance(result.email, str):
                raise ValueError()
            return result
        except (TypeError, ValueError):
            raise ValueError('Preferências da nuvem inválidas. Configure a conexão novamente.') from None

    def save(self, path):
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix('.tmp')
        temporary.write_text(json.dumps(asdict(self), indent=2) + '\n', encoding='utf-8')
        temporary.replace(path)
