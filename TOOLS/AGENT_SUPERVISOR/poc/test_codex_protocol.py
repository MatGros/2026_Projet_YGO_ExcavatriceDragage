"""Test réel empirique du protocole Codex app-server (stdio JSON-RPC).
Objectifs :
1. Envoyer 'initialize' et vérifier la réponse du serveur Codex.
2. Démarrer un thread ('thread/start').
3. Tester 'turn/steer' sans tour actif pour vérifier s'il échoue comme affirmé par la review.
4. Tester 'thread/injectItems' pour observer s'il déclenche ou non une réponse de tour.
"""
import json
import subprocess
import sys
import time

def send_rpc(proc, method, params, req_id):
    msg = {
        "jsonrpc": "2.0",
        "id": req_id,
        "method": method,
        "params": params
    }
    raw = json.dumps(msg) + "\n"
    proc.stdin.write(raw)
    proc.stdin.flush()

def read_responses(proc, timeout=5):
    start = time.time()
    responses = []
    # Lecture non-bloquante ou ligne par ligne
    import select
    while time.time() - start < timeout:
        line = proc.stdout.readline()
        if not line:
            break
        line = line.strip()
        if not line:
            continue
        try:
            data = json.loads(line)
            responses.append(data)
            # Si on a reçu une réponse avec un id de requête, on a au moins une réponse
            if "id" in data and data["id"] is not None:
                break
        except Exception:
            pass
    return responses

def main():
    print("=== DÉBUT DU TEST EMPIRIQUE CODEX APP-SERVER ===")
    cmd = ["codex", "app-server", "--stdio"]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)

    try:
        # Étape 1 : initialize
        print("\n[1] Envoi 'initialize'...")
        init_params = {
            "clientInfo": {"name": "test-client", "version": "1.0"},
            "capabilities": {}
        }
        send_rpc(proc, "initialize", init_params, 1)
        res1 = read_responses(proc, timeout=5)
        print("Réponse initialize :", json.dumps(res1, indent=2))

        # Étape 2 : thread/start
        print("\n[2] Envoi 'thread/start'...")
        start_params = {
            "model": "gpt-4o",
        }
        send_rpc(proc, "thread/start", start_params, 2)
        res2 = read_responses(proc, timeout=5)
        print("Réponse thread/start :", json.dumps(res2, indent=2))

        thread_id = None
        for r in res2:
            if r.get("id") == 2 and "result" in r:
                thread_id = r["result"].get("threadId") or r["result"].get("thread", {}).get("id")
        print(f"Thread ID obtenu : {thread_id}")

        if thread_id:
            # Étape 3 : turn/steer sans tour actif
            print(f"\n[3] Test 'turn/steer' sans tour actif sur thread {thread_id}...")
            steer_params = {
                "threadId": thread_id,
                "expectedTurnId": "dummy-turn-id",
                "instructions": "Test steer"
            }
            send_rpc(proc, "turn/steer", steer_params, 3)
            res3 = read_responses(proc, timeout=5)
            print("Réponse turn/steer :", json.dumps(res3, indent=2))

            # Étape 4 : thread/injectItems
            print(f"\n[4] Test 'thread/injectItems'...")
            inject_params = {
                "threadId": thread_id,
                "items": [{"type": "message", "role": "system", "content": "Context test"}]
            }
            send_rpc(proc, "thread/injectItems", inject_params, 4)
            res4 = read_responses(proc, timeout=5)
            print("Réponse thread/injectItems :", json.dumps(res4, indent=2))

    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except Exception:
            proc.kill()
    print("\n=== FIN DU TEST EMPIRIQUE CODEX ===")

if __name__ == "__main__":
    main()
