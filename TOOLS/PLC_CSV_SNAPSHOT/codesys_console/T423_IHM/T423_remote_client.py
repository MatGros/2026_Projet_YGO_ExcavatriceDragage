# -*- coding: utf-8 -*-
"""T423_remote_client.py — Client de test externe pour piloter CODESYS en arrière-plan.

S'exécute directement depuis PowerShell / Terminal sans ouvrir le menu CODESYS à chaque fois !
Prérequis : Lancer une seule fois T423_bridge_server.py dans CODESYS.
"""

import sys
import time
import socket

HOST = "127.0.0.1"
PORT = 29035


class CodesysRemoteClient(object):
    def __init__(self, host=HOST, port=PORT, timeout=2.0):
        self.host = host
        self.port = port
        self.timeout = timeout
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.settimeout(timeout)

    def send_cmd(self, cmd_str):
        self.sock.sendto(cmd_str.encode("utf-8"), (self.host, self.port))
        try:
            data, _ = self.sock.recvfrom(8192)
            return data.decode("utf-8", "ignore").strip()
        except socket.timeout:
            return "ERR:TIMEOUT"
        except Exception as e:
            return "ERR:" + str(e)

    def ping(self):
        return self.send_cmd("PING") == "PONG"

    def read(self, var_path):
        res = self.send_cmd("READ|" + var_path)
        if res.startswith("OK|"):
            return res[3:]
        return "ERR"

    def write(self, var_path, val, force=False):
        f = "1" if force else "0"
        res = self.send_cmd("WRITE|%s|%s|%s" % (var_path, val, f))
        return res == "OK"

    def read_banner(self):
        res = self.send_cmd("READ_BANNER")
        if not res.startswith("OK|"):
            return {}
        payload = res[3:]
        banner = {}
        for item in payload.split("||"):
            if "=" in item:
                k, v = item.split("=", 1)
                banner[k] = v
        return banner

    def read_alarms(self):
        res = self.send_cmd("READ_ALARMS")
        if not res.startswith("OK|"):
            return []
        payload = res[3:]
        if not payload:
            return []
        return payload.split("||")

    def rearm(self):
        return self.send_cmd("REARM") == "OK"

    def stop_server(self):
        return self.send_cmd("STOP")


if __name__ == "__main__":
    client = CodesysRemoteClient()
    print("Test de connexion au pont CODESYS (127.0.0.1:%d)..." % PORT)
    if client.ping():
        print("[OK] CODESYS répond au PING !")
        banner = client.read_banner()
        print("Bandeau lu :", banner)
    else:
        print("[ATTENTE] Le serveur CODESYS n'est pas encore lancé. Exécuter T423_bridge_server.py dans CODESYS.")
