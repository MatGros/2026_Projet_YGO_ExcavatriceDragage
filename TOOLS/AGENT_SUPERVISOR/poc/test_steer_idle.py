import json
import subprocess
import time

proc = subprocess.Popen(['codex', 'app-server', '--stdio'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
proc.stdin.write(json.dumps({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {'clientInfo': {'name': 'test', 'version': '1.0'}}}) + '\n')
proc.stdin.flush()
print('Init line:', proc.stdout.readline().strip())

proc.stdin.write(json.dumps({'jsonrpc': '2.0', 'id': 2, 'method': 'thread/start', 'params': {'model': 'gpt-4o'}}) + '\n')
proc.stdin.flush()

tid = None
for _ in range(50):
    line = proc.stdout.readline().strip()
    if not line:
        continue
    try:
        data = json.loads(line)
        if data.get('id') == 2:
            tid = data['result']['thread']['id']
            break
    except Exception:
        pass

print('Thread ID:', tid)
assert tid, 'Failed to obtain thread ID'

# Tester turn/steer sur un thread idle
steer_payload = {
    'jsonrpc': '2.0',
    'id': 3,
    'method': 'turn/steer',
    'params': {
        'threadId': tid,
        'expectedTurnId': '01a1bf36-0000-0000-0000-000000000000',
        'input': [{'type': 'text', 'text': 'Instruction de test steer'}]
    }
}
proc.stdin.write(json.dumps(steer_payload) + '\n')
proc.stdin.flush()

for _ in range(50):
    line = proc.stdout.readline().strip()
    if not line:
        continue
    try:
        data = json.loads(line)
        if data.get('id') == 3:
            print('RÉSULTAT EXACT DE TURN/STEER SUR THREAD SANS TOUR ACTIF :')
            print(json.dumps(data, indent=2))
            break
    except Exception:
        pass

# Tester maintenant turn/start
start_payload = {
    'jsonrpc': '2.0',
    'id': 4,
    'method': 'turn/start',
    'params': {
        'threadId': tid,
        'input': [{'type': 'text', 'text': 'Dis juste: PRET'}]
    }
}
proc.stdin.write(json.dumps(start_payload) + '\n')
proc.stdin.flush()

for _ in range(50):
    line = proc.stdout.readline().strip()
    if not line:
        continue
    try:
        data = json.loads(line)
        if data.get('id') == 4:
            print('\nRÉSULTAT EXACT DE TURN/START SUR THREAD INACTIF :')
            print(json.dumps(data, indent=2))
            break
    except Exception:
        pass

proc.terminate()
print('\nFin du test.')
