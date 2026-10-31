# -*- coding: utf-8 -*-
"""T423_bridge_server.py — Serveur UDP pour contrôle dynamique en arrière-plan sous CODESYS.

À exécuter dans CODESYS : Tools > Scripting > Execute Script File...
Permet à l'orchestrateur externe de lire et écrire des variables sans relancer le script manuellement.
Port local UDP : 29035 (127.0.0.1)

Commandes supportées (JSON) :
  {"action": "read", "path": "GVL_IHM.Banner.GlobalContextText"}
  {"action": "write", "path": "GVL_Simulation.SimChainOk", "value": "TRUE", "force": true}
  {"action": "ping"}
  {"action": "stop"}
"""

import os
import sys
import time
import socket

try:
    _this_dir = os.path.dirname(os.path.abspath(__file__))
except Exception:
    _this_dir = r"C:\_MGS\DEV\2026_Projet_YGO_ExcavatriceDragage\TOOLS\PLC_CSV_SNAPSHOT\codesys_console\T423_IHM"

ENGINE_PATH = os.path.join(_this_dir, "T423_engine.py")
with open(ENGINE_PATH, "rb") as f:
    exec(compile(f.read(), ENGINE_PATH, "exec"), globals(), globals())

HOST = "127.0.0.1"
PORT = 29035


def run_bridge_server():
    online_app = get_online_app()
    if online_app is None:
        print("[BRIDGE] ERREUR : Application CODESYS non connectee (Login requis).")
        return

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((HOST, PORT))
    sock.settimeout(1.0)

    print("\n" + "=" * 70)
    print("  SERVEUR PONT CODESYS T423 ACTIF SUR UDP 127.0.0.1:%d" % PORT)
    print("  En attente de commandes du harnais externe (Ctrl+C ou 'stop' pour quitter)...")
    print("=" * 70)

    running = True
    while running:
        try:
            data, addr = sock.recvfrom(4096)
        except socket.timeout:
            continue
        except Exception as e:
            print("[BRIDGE] Exception socket: %s" % str(e))
            break

        msg = data.decode("utf-8", "ignore").strip()
        if not msg:
            continue

        resp = "ERR:UNKNOWN"
        try:
            # Format simple : CMD|ARG1|ARG2|ARG3
            # Ex: READ|GVL_IHM.Banner.GlobalContextText
            # Ex: WRITE|GVL_Simulation.SimChainOk|TRUE|1
            # Ex: READ_BANNER
            # Ex: READ_ALARMS
            # Ex: PING
            # Ex: STOP
            parts = msg.split("|")
            cmd = parts[0].upper()

            if cmd == "PING":
                resp = "PONG"

            elif cmd == "STOP":
                resp = "STOPPING"
                running = False

            elif cmd == "READ" and len(parts) >= 2:
                var_path = parts[1]
                val = safe_read(online_app, var_path, "N/A")
                resp = "OK|" + clean_val(val)

            elif cmd == "WRITE" and len(parts) >= 3:
                var_path = parts[1]
                val_to_write = parts[2]
                force_it = (parts[3] == "1") if len(parts) >= 4 else False
                ok = safe_write(online_app, var_path, val_to_write, force=force_it)
                resp = "OK" if ok else "ERR:WRITE_FAILED"

            elif cmd == "READ_BANNER":
                banner = read_banner(online_app)
                # Sérialisation tabulaire simple
                lines = []
                for k in sorted(banner.keys()):
                    lines.append("%s=%s" % (k, banner[k]))
                resp = "OK|" + "||".join(lines)

            elif cmd == "READ_ALARMS":
                alarms = get_active_alarms(online_app)
                resp = "OK|" + "||".join(alarms)

            elif cmd == "REARM":
                rearm_emergency(online_app)
                resp = "OK"

            else:
                resp = "ERR:SYNTAX"

        except Exception as ex:
            resp = "ERR:" + str(ex)

        try:
            sock.sendto(resp.encode("utf-8"), addr)
        except Exception:
            pass

    sock.close()
    print("\n[BRIDGE] Serveur pont arrete proprement.")


if __name__ == "__main__":
    run_bridge_server()
