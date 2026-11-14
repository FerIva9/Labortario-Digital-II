"""Compatibilidade: ensaio da sincronização compartilhada atual (v2)."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.check_shared_integration import main
from cloud_firebase import FirebaseError
from cloud_credentials import CredentialUnavailable

if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (FirebaseError, CredentialUnavailable, ValueError, OSError, RuntimeError) as error:
        print(f'Ensaio não concluído: {error}', file=sys.stderr)
        raise SystemExit(1)
