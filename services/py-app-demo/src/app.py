"""
Py App Demo - Aplicación con vulnerabilidades intencionales para demo de Harness STO.

ADVERTENCIA: Este código contiene vulnerabilidades INTENCIONALES para propósitos de demo.
NO usar en producción.
"""

import os
import re
import ssl
import yaml
import sqlite3
import hashlib
import pickle
import subprocess
import logging
import random
import base64
from urllib.request import urlopen
from xml.etree import ElementTree as ET
from flask import Flask, request, jsonify, render_template_string, redirect, make_response

app = Flask(__name__)
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# =============================================================================
# VULNERABILIDAD 1: Hardcoded Secrets (SAST - CWE-798)
# Severidad: High - Snyk detecta estos patrones
# =============================================================================
DATABASE_PASSWORD = "super_secret_password_123"
API_KEY = "sk-1234567890abcdef1234567890abcdef"
JWT_SECRET = "my_jwt_secret_key_do_not_share_with_anyone"

# AWS Credentials hardcoded - Snyk detecta esto muy bien
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
AWS_SESSION_TOKEN = "FwoGZXIvYXdzEBYaDHVuaXQgdGVzdGluZyKDAdK"

# GitHub Token hardcoded
GITHUB_TOKEN = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Database connection string with credentials
DATABASE_URL = "postgresql://admin:password123@localhost:5432/production_db"
MONGODB_URI = "mongodb://root:secretpassword@mongodb.example.com:27017/admin"


# =============================================================================
# VULNERABILIDAD 2: SQL Injection (SAST - CWE-89)
# Severidad: Critical
# =============================================================================
def get_db_connection():
    conn = sqlite3.connect(':memory:')
    conn.execute('''CREATE TABLE IF NOT EXISTS users
                    (id INTEGER PRIMARY KEY, username TEXT, email TEXT, password TEXT, role TEXT)''')
    conn.execute("INSERT OR IGNORE INTO users VALUES (1, 'admin', 'admin@example.com', 'admin123', 'admin')")
    conn.execute("INSERT OR IGNORE INTO users VALUES (2, 'user1', 'user1@example.com', 'user123', 'user')")
    return conn


@app.route('/api/users/search', methods=['GET'])
def search_users():
    """VULNERABLE: SQL Injection via string concatenation"""
    query = request.args.get('query', '')
    conn = get_db_connection()

    # VULNERABLE: Direct string interpolation in SQL
    sql = f"SELECT * FROM users WHERE username LIKE '%{query}%' OR email LIKE '%{query}%'"

    try:
        cursor = conn.execute(sql)
        users = [{'id': row[0], 'username': row[1], 'email': row[2], 'role': row[4]}
                 for row in cursor.fetchall()]
        return jsonify(users)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        conn.close()


@app.route('/api/users/login', methods=['POST'])
def login():
    """VULNERABLE: SQL Injection in authentication"""
    data = request.get_json() or {}
    username = data.get('username', '')
    password = data.get('password', '')

    conn = get_db_connection()
    # VULNERABLE: SQL Injection - classic authentication bypass
    query = f"SELECT * FROM users WHERE username = '{username}' AND password = '{password}'"

    try:
        cursor = conn.execute(query)
        user = cursor.fetchone()
        if user:
            return jsonify({'message': 'Login successful', 'user': user[1]})
        return jsonify({'error': 'Invalid credentials'}), 401
    finally:
        conn.close()


# =============================================================================
# VULNERABILIDAD 3: Command Injection (SAST - CWE-78)
# Severidad: Critical
# =============================================================================
@app.route('/api/system/ping', methods=['POST'])
def ping_host():
    """VULNERABLE: OS Command Injection"""
    data = request.get_json() or {}
    host = data.get('host', 'localhost')

    # VULNERABLE: User input directly in shell command
    result = subprocess.run(
        f"ping -c 1 {host}",
        shell=True,
        capture_output=True,
        text=True
    )
    return jsonify({
        'host': host,
        'stdout': result.stdout,
        'returncode': result.returncode
    })


@app.route('/api/system/exec', methods=['POST'])
def execute_command():
    """VULNERABLE: Direct command execution"""
    data = request.get_json() or {}
    cmd = data.get('command', 'echo hello')

    # VULNERABLE: os.system with user input
    exit_code = os.system(cmd)
    return jsonify({'exit_code': exit_code})


@app.route('/api/system/run', methods=['POST'])
def run_script():
    """VULNERABLE: subprocess.Popen with shell=True"""
    data = request.get_json() or {}
    script = data.get('script', '')

    # VULNERABLE: Popen with shell=True and user input
    process = subprocess.Popen(
        script,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    stdout, stderr = process.communicate()
    return jsonify({
        'stdout': stdout.decode(),
        'stderr': stderr.decode()
    })


# =============================================================================
# VULNERABILIDAD 4: Code Injection - eval/exec (SAST - CWE-94)
# Severidad: Critical
# =============================================================================
@app.route('/api/calculate', methods=['POST'])
def calculate():
    """VULNERABLE: eval() with user input"""
    data = request.get_json() or {}
    expression = data.get('expression', '1+1')

    # VULNERABLE: eval with user-controlled input
    try:
        result = eval(expression)
        return jsonify({'result': result})
    except Exception as e:
        return jsonify({'error': str(e)}), 400


@app.route('/api/execute', methods=['POST'])
def execute_code():
    """VULNERABLE: exec() with user input"""
    data = request.get_json() or {}
    code = data.get('code', 'print("hello")')

    # VULNERABLE: exec with user-controlled input
    try:
        exec(code)
        return jsonify({'status': 'executed'})
    except Exception as e:
        return jsonify({'error': str(e)}), 400


# =============================================================================
# VULNERABILIDAD 5: Insecure Deserialization (SAST - CWE-502)
# Severidad: Critical
# =============================================================================
@app.route('/api/data/load', methods=['POST'])
def load_data():
    """VULNERABLE: Pickle deserialization of untrusted data"""
    data = request.get_data()

    # VULNERABLE: pickle.loads with untrusted data
    try:
        obj = pickle.loads(data)
        return jsonify({'data': str(obj)})
    except Exception as e:
        return jsonify({'error': str(e)}), 400


@app.route('/api/data/yaml', methods=['POST'])
def load_yaml():
    """VULNERABLE: Unsafe YAML loading"""
    data = request.get_data().decode('utf-8')

    # VULNERABLE: yaml.load without safe_load (allows arbitrary code execution)
    try:
        obj = yaml.load(data, Loader=yaml.Loader)  # VULNERABLE
        return jsonify({'data': str(obj)})
    except Exception as e:
        return jsonify({'error': str(e)}), 400


# =============================================================================
# VULNERABILIDAD 6: XSS - Cross-Site Scripting (SAST - CWE-79)
# Severidad: Medium
# =============================================================================
@app.route('/api/greeting', methods=['GET'])
def greeting():
    """VULNERABLE: Reflected XSS"""
    name = request.args.get('name', 'Guest')

    # VULNERABLE: User input directly in HTML without escaping
    html = f"""
    <html>
        <body>
            <h1>Welcome, {name}!</h1>
            <p>Your session ID is: {request.args.get('session', 'none')}</p>
        </body>
    </html>
    """
    return render_template_string(html)


@app.route('/api/search/results', methods=['GET'])
def search_results():
    """VULNERABLE: Stored XSS potential"""
    query = request.args.get('q', '')

    # VULNERABLE: Reflecting user input without sanitization
    response = make_response(f"<html><body><h2>Search results for: {query}</h2></body></html>")
    response.headers['Content-Type'] = 'text/html'
    return response


# =============================================================================
# VULNERABILIDAD 7: Path Traversal (SAST - CWE-22)
# Severidad: High
# =============================================================================
@app.route('/api/files/read', methods=['GET'])
def read_file():
    """VULNERABLE: Path Traversal / Directory Traversal"""
    filename = request.args.get('filename', '')
    base_path = '/app/data/'

    # VULNERABLE: No path validation - allows ../../../etc/passwd
    file_path = base_path + filename

    try:
        with open(file_path, 'r') as f:
            content = f.read()
        return jsonify({'content': content})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/files/download', methods=['GET'])
def download_file():
    """VULNERABLE: Path Traversal in file download"""
    filename = request.args.get('file', '')

    # VULNERABLE: os.path.join doesn't prevent traversal with absolute paths
    file_path = os.path.join('/uploads', filename)

    try:
        with open(file_path, 'rb') as f:
            return f.read()
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# =============================================================================
# VULNERABILIDAD 8: SSRF - Server-Side Request Forgery (SAST - CWE-918)
# Severidad: High
# =============================================================================
@app.route('/api/fetch', methods=['POST'])
def fetch_url():
    """VULNERABLE: SSRF - fetching user-controlled URLs"""
    data = request.get_json() or {}
    url = data.get('url', '')

    # VULNERABLE: No URL validation - allows access to internal services
    try:
        response = urlopen(url)
        return jsonify({'content': response.read().decode()})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/webhook', methods=['POST'])
def webhook():
    """VULNERABLE: SSRF via webhook URL"""
    data = request.get_json() or {}
    callback_url = data.get('callback_url', '')

    # VULNERABLE: Making request to user-controlled URL
    import requests as req
    try:
        resp = req.get(callback_url, timeout=5)
        return jsonify({'status': resp.status_code})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# =============================================================================
# VULNERABILIDAD 9: XXE - XML External Entity (SAST - CWE-611)
# Severidad: High
# =============================================================================
@app.route('/api/xml/parse', methods=['POST'])
def parse_xml():
    """VULNERABLE: XXE - XML External Entity Injection"""
    xml_data = request.get_data()

    # VULNERABLE: Parsing XML without disabling external entities
    try:
        tree = ET.fromstring(xml_data)
        return jsonify({'root': tree.tag, 'text': tree.text})
    except Exception as e:
        return jsonify({'error': str(e)}), 400


# =============================================================================
# VULNERABILIDAD 10: Weak Cryptography (SAST - CWE-327, CWE-328)
# Severidad: Medium
# =============================================================================
def hash_password(password: str) -> str:
    """VULNERABLE: MD5 is cryptographically broken"""
    return hashlib.md5(password.encode()).hexdigest()


def hash_password_sha1(password: str) -> str:
    """VULNERABLE: SHA1 is also weak for passwords"""
    return hashlib.sha1(password.encode()).hexdigest()


@app.route('/api/auth/hash', methods=['POST'])
def create_hash():
    """Endpoint using weak hash"""
    data = request.get_json() or {}
    password = data.get('password', '')
    return jsonify({
        'md5': hash_password(password),
        'sha1': hash_password_sha1(password)
    })


# =============================================================================
# VULNERABILIDAD 11: Insecure Randomness (SAST - CWE-330)
# Severidad: Medium
# =============================================================================
@app.route('/api/token/generate', methods=['GET'])
def generate_token():
    """VULNERABLE: Using insecure random for security tokens"""
    # VULNERABLE: random module is not cryptographically secure
    token = ''.join([str(random.randint(0, 9)) for _ in range(32)])
    return jsonify({'token': token})


@app.route('/api/session/create', methods=['GET'])
def create_session():
    """VULNERABLE: Predictable session ID"""
    # VULNERABLE: Predictable session generation
    session_id = random.randint(100000, 999999)
    return jsonify({'session_id': session_id})


# =============================================================================
# VULNERABILIDAD 12: Open Redirect (SAST - CWE-601)
# Severidad: Medium
# =============================================================================
@app.route('/api/redirect', methods=['GET'])
def open_redirect():
    """VULNERABLE: Open redirect"""
    url = request.args.get('url', '/')

    # VULNERABLE: Redirecting to user-controlled URL
    return redirect(url)


@app.route('/api/goto', methods=['GET'])
def goto_url():
    """VULNERABLE: Another open redirect pattern"""
    next_page = request.args.get('next', '/')
    return redirect(next_page)


# =============================================================================
# VULNERABILIDAD 13: Insecure SSL/TLS (SAST - CWE-295)
# Severidad: High
# =============================================================================
@app.route('/api/external/fetch', methods=['POST'])
def fetch_insecure():
    """VULNERABLE: Disabled SSL verification"""
    data = request.get_json() or {}
    url = data.get('url', '')

    import requests as req
    # VULNERABLE: SSL verification disabled
    resp = req.get(url, verify=False)
    return jsonify({'content': resp.text[:1000]})


def create_insecure_context():
    """VULNERABLE: Creating insecure SSL context"""
    # VULNERABLE: Disabling certificate verification
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    return context


# =============================================================================
# VULNERABILIDAD 14: Log Injection (SAST - CWE-117)
# Severidad: Medium
# =============================================================================
@app.route('/api/log', methods=['POST'])
def log_action():
    """VULNERABLE: Log injection"""
    data = request.get_json() or {}
    action = data.get('action', '')
    user = data.get('user', 'anonymous')

    # VULNERABLE: User input directly in logs
    logger.info(f"User {user} performed action: {action}")
    return jsonify({'logged': True})


# =============================================================================
# VULNERABILIDAD 15: Regex DoS (SAST - CWE-1333)
# Severidad: Medium
# =============================================================================
@app.route('/api/validate/email', methods=['POST'])
def validate_email():
    """VULNERABLE: ReDoS - catastrophic backtracking"""
    data = request.get_json() or {}
    email = data.get('email', '')

    # VULNERABLE: Evil regex with catastrophic backtracking
    pattern = r'^([a-zA-Z0-9]+)+@([a-zA-Z0-9]+)+\.([a-zA-Z0-9]+)+$'

    if re.match(pattern, email):
        return jsonify({'valid': True})
    return jsonify({'valid': False})


# =============================================================================
# Endpoints seguros para contraste
# =============================================================================
def get_user_by_id(user_id: int) -> dict:
    """SEGURO: Parameterized query"""
    conn = get_db_connection()
    try:
        cursor = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        row = cursor.fetchone()
        if row:
            return {'id': row[0], 'username': row[1], 'email': row[2], 'role': row[4]}
        return None
    finally:
        conn.close()


@app.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id: int):
    user = get_user_by_id(user_id)
    if user:
        return jsonify(user)
    return jsonify({'error': 'User not found'}), 404


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy', 'version': '1.0.0'})


@app.route('/', methods=['GET'])
def index():
    return jsonify({
        'app': 'Py App Demo',
        'version': '1.0.0',
        'warning': 'This app contains intentional vulnerabilities for demo purposes'
    })


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
