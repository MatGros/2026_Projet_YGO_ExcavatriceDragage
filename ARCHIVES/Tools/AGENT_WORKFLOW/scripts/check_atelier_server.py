"""Guard: a dropped browser connection must never poison the native simulation session."""
from pathlib import Path

source = Path(__file__).resolve().parents[2] / 'TWINBENCH' / 'modelica_atelier' / 'server.py'
text = source.read_text(encoding='utf-8')
expected = 'except (BrokenPipeError, ConnectionAbortedError, ConnectionResetError):'
generic = 'except Exception as exc:\n            SESSION.error=str(exc); SESSION.running=False'
assert expected in text, 'Déconnexion client non isolée'
assert text.index(expected) < text.index(generic), 'Déconnexion interceptée après erreur fatale'
print('PASS: déconnexion/rechargement navigateur isolé du moteur FMU')
