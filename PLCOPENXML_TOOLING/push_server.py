import http.server
import socketserver
import sys
import json

# Reconfigure stdout to use UTF-8 to prevent UnicodeEncodeError on Windows command prompt
sys.stdout.reconfigure(encoding='utf-8')

PORT = 9090

class PushHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        # Prevent logging requests to stdout to keep it clean for wakeup triggers
        pass

    def do_GET(self):
        if self.path == '/wake':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "woken"}).encode())
            print("\n🚨 [PUSH] Notification reçue : Réveil de Gemini demandé !\n", flush=True)
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == '/wake':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "woken"}).encode())
            print("\n🚨 [PUSH] Notification reçue : La file d'attente (QUEUE.md) a été modifiée !\n", flush=True)
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("", PORT), PushHandler) as httpd:
        print("Push Notification Server listening on port 9090...", flush=True)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("Stopping server...", flush=True)
