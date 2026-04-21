"""
Py App Demo - Aplicación con vulnerabilidades intencionales para demo de Harness STO.

ADVERTENCIA: Este código contiene vulnerabilidades INTENCIONALES para propósitos de demo.
NO usar en producción.
"""

import os
import sqlite3
import hashlib
import pickle
import subprocess
from flask import Flask, request, jsonify, render_template_string
from functools import wraps

app = Flask(__name__)

# =============================================================================
# VULNERABILIDAD 1: Hardcoded Secrets (SAST - CWE-798)
# Severidad: High
# =============================================================================
DATABASE_PASSWORD = "super_secret_password_123"  # VULNERABLE: Hardcoded credential
API_KEY = "sk-1234567890abcdef"  # VULNERABLE: Hardcoded API key
JWT_SECRET = "my_jwt_secret_key_do_not_share"  # VULNERABLE: Hardcoded secret

# =============================================================================
# VULNERABILIDAD 2: SQL Injection (SAST - CWE-89)
# Severidad: Critical
# =============================================================================
def get_db_connection():
    conn = sqlite3.connect(':memory:')
    conn.execute('''CREATE TABLE IF NOT EXISTS users
                    (id INTEGER PRIMARY KEY, username TEXT, email TEXT, role TEXT)''')
    conn.execute("INSERT OR IGNORE INTO users VALUES (1, 'admin', 'admin@py-app.com', 'admin')")
    conn.execute("INSERT OR IGNORE INTO users VALUES (2, 'user1', 'user1@py-app.com', 'user')")
    return conn


@app.route('/api/users/search', methods=['GET'])
def search_users():
    """
    VULNERABLE: SQL Injection
    El parámetro 'query' se concatena directamente en la consulta SQL.
    """
    query = request.args.get('query', '')
    conn = get_db_connection()

    # VULNERABLE: String concatenation in SQL query
    sql = f"SELECT * FROM users WHERE username LIKE '%{query}%' OR email LIKE '%{query}%'"

    try:
        cursor = conn.execute(sql)
        users = [{'id': row[0], 'username': row[1], 'email': row[2], 'role': row[3]}
                 for row in cursor.fetchall()]
        return jsonify(users)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


# =============================================================================
# VULNERABILIDAD 3: Command Injection (SAST - CWE-78)
# Severidad: Critical
# =============================================================================
@app.route('/api/system/ping', methods=['POST'])
def ping_host():
    """
    VULNERABLE: Command Injection
    El parámetro 'host' se pasa directamente a shell.
    """
    data = request.get_json() or {}
    host = data.get('host', 'localhost')

    # VULNERABLE: User input passed directly to shell
    result = subprocess.run(
        f"ping -c 1 {host}",  # VULNERABLE
        shell=True,
        capture_output=True,
        text=True
    )

    return jsonify({
        'host': host,
        'stdout': result.stdout,
        'stderr': result.stderr,
        'returncode': result.returncode
    })


# =============================================================================
# VULNERABILIDAD 4: Insecure Deserialization (SAST - CWE-502)
# Severidad: High
# =============================================================================
@app.route('/api/data/load', methods=['POST'])
def load_data():
    """
    VULNERABLE: Insecure Deserialization
    Deserializa datos pickle sin validación.
    """
    data = request.get_data()

    try:
        # VULNERABLE: Deserializing untrusted data
        obj = pickle.loads(data)
        return jsonify({'data': str(obj)})
    except Exception as e:
        return jsonify({'error': str(e)}), 400


# =============================================================================
# VULNERABILIDAD 5: XSS - Cross-Site Scripting (SAST - CWE-79)
# Severidad: Medium
# =============================================================================
@app.route('/api/greeting', methods=['GET'])
def greeting():
    """
    VULNERABLE: Reflected XSS
    El nombre se renderiza sin sanitización.
    """
    name = request.args.get('name', 'Guest')

    # VULNERABLE: User input rendered without escaping
    html = f"""
    <html>
        <body>
            <h1>Welcome, {name}!</h1>
        </body>
    </html>
    """
    return render_template_string(html)


# =============================================================================
# VULNERABILIDAD 6: Weak Cryptography (SAST - CWE-328)
# Severidad: Medium
# =============================================================================
def hash_password(password: str) -> str:
    """
    VULNERABLE: Using weak hash algorithm (MD5)
    """
    # VULNERABLE: MD5 is cryptographically weak
    return hashlib.md5(password.encode()).hexdigest()


@app.route('/api/auth/hash', methods=['POST'])
def create_hash():
    """Endpoint para hashear passwords (demo)."""
    data = request.get_json() or {}
    password = data.get('password', '')

    hashed = hash_password(password)
    return jsonify({'hash': hashed})


# =============================================================================
# VULNERABILIDAD 7: Path Traversal (SAST - CWE-22)
# Severidad: High
# =============================================================================
@app.route('/api/files/read', methods=['GET'])
def read_file():
    """
    VULNERABLE: Path Traversal
    El filename no se valida, permitiendo acceso a archivos arbitrarios.
    """
    filename = request.args.get('filename', '')
    base_path = '/app/data/'

    # VULNERABLE: No validation of path traversal
    file_path = base_path + filename

    try:
        with open(file_path, 'r') as f:
            content = f.read()
        return jsonify({'content': content})
    except FileNotFoundError:
        return jsonify({'error': 'File not found'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# =============================================================================
# CÓDIGO SEGURO - Para mostrar contraste y tests
# =============================================================================
def get_user_by_id(user_id: int) -> dict:
    """
    SEGURO: Usa parameterized queries
    """
    conn = get_db_connection()
    try:
        cursor = conn.execute(
            "SELECT * FROM users WHERE id = ?",  # Parameterized
            (user_id,)
        )
        row = cursor.fetchone()
        if row:
            return {'id': row[0], 'username': row[1], 'email': row[2], 'role': row[3]}
        return None
    finally:
        conn.close()


@app.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id: int):
    """Endpoint seguro para obtener usuario por ID."""
    user = get_user_by_id(user_id)
    if user:
        return jsonify(user)
    return jsonify({'error': 'User not found'}), 404


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({'status': 'healthy', 'version': '1.0.0'})


@app.route('/', methods=['GET'])
def index():
    """Root endpoint."""
    return jsonify({
        'app': 'Py App Demo',
        'version': '1.0.0',
        'endpoints': [
            '/health',
            '/api/users/<id>',
            '/api/users/search?query=<query>',
            '/api/auth/hash',
            '/api/greeting?name=<name>',
            '/api/system/ping',
            '/api/files/read?filename=<filename>',
            '/api/data/load'
        ]
    })


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
