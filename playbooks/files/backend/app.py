import subprocess
from flask import Flask, jsonify, request, send_file, session
from flask_cors import CORS
import redis
import os
import secrets

# Aplikacja Flask obsluguje API backendu oraz sesje uzywane przez testy CSRF.
app = Flask(__name__)
# Klucz demonstracyjny. W produkcji musi pochodzic z sekretu spoza obrazu.
app.secret_key = "dev-only-secret-key"

# CORS z credentials pozwala frontendowi korzystac z sesji backendu.
CORS(app, supports_credentials=True)

# Redis przechowuje licznik uzywany przez endpointy demonstracyjne.
r = redis.Redis(
    host=os.getenv("REDIS_HOST", "db"),
    port=6379,
    decode_responses=True
)

BASE_DIR = "/app"


# Utworz token CSRF przy pierwszym uzyciu sesji i zachowaj go do kolejnych zadan.
def get_csrf_token():
    if "csrf_token" not in session:
        session["csrf_token"] = secrets.token_hex(16)
    return session["csrf_token"]


@app.route("/api/health")
def health():
    # Healthcheck sprawdza zarowno proces API, jak i dostepnosc Redis.
    try:
        r.ping()
        return jsonify({
            "status": "healthy",
            "redis": "connected"
        }), 200
    except Exception as e:
        return jsonify({
            "status": "unhealthy",
            "redis": "disconnected",
            "error": str(e)
        }), 500

@app.route("/api/data")
def get_data():
    # Atomowe INCR pozwala bezpiecznie zwiekszac licznik po stronie Redis.
    try:
        hits = r.incr("counter")
        return jsonify({
            "hits": hits,
            "framework": "Vue.js",
            "status": "connected"
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/counter")
def get_counter():
    counter = r.get("counter") or "0"
    return jsonify({"counter": counter})


@app.route("/api/login-admin")
def login_admin():
    # Endpoint demonstracyjny ustawia role bez prawdziwego uwierzytelniania.
    session["role"] = "admin"
    get_csrf_token()
    return jsonify({"status": "logged in as admin"})


@app.route("/api/logout")
def logout():
    session.clear()
    return jsonify({"status": "logged out"})


@app.route("/api/csrf")
def csrf():
    return jsonify({"csrf_token": get_csrf_token()})


@app.route("/api/counter/reset", methods=["POST"])
def reset_counter():
    # Zmiana stanu wymaga roli admina oraz tokena CSRF z tej samej sesji.
    if session.get("role") != "admin":
        return jsonify({"error": "admin only"}), 403

    csrf_from_header = request.headers.get("X-CSRF-Token")
    csrf_from_session = session.get("csrf_token")

    if not csrf_from_header or csrf_from_header != csrf_from_session:
        return jsonify({"error": "invalid csrf token"}), 403

    r.set("counter", 0)
    return jsonify({"counter": 0, "status": "reset"})


# Celowo podatny path traversal do testow WAF i skanerow.
# Nie uzywac w produkcji bez ograniczenia sciezki do bezpiecznego katalogu.
@app.route("/api/download")
def download():
    filename = request.args.get("file", "")
    target = os.path.join(BASE_DIR, filename)
    return send_file(target)


# Celowo podatny RCE do testow WAF i skanerow.
# Nie uzywac w produkcji: shell=True wykonuje dane wejsciowe jako polecenie systemowe.
@app.route("/api/cmd")
def cmd():
    command = request.args.get("cmd", "")
    output = subprocess.check_output(
        command,
        shell=True,
        stderr=subprocess.STDOUT,
        text=True
    )
    return jsonify({"output": output})


if __name__ == "__main__":
    # Nasluch na wszystkich interfejsach jest potrzebny, aby port byl dostepny z sieci Docker.
    app.run(host="0.0.0.0", port=5000)