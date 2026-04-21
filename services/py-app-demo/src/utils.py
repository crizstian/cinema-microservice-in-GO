"""
Utils module - Additional vulnerabilities for Snyk detection demo.
"""

import os
import ssl
import hmac
import base64
import hashlib
import tempfile
import subprocess
from typing import Any
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend


# =============================================================================
# HARDCODED CREDENTIALS - Snyk detects these patterns
# =============================================================================

# Database credentials
DB_HOST = "production-db.internal.company.com"
DB_USER = "admin"
DB_PASSWORD = "SuperSecretP@ssw0rd!"  # VULNERABLE
DB_NAME = "customers"

# API Keys - various formats that Snyk detects
STRIPE_API_KEY = "sk_live_51H0Abcdefghijklmnopqrstuvwxyz1234567890"
SENDGRID_API_KEY = "SG.abcdefghijklmnop.qrstuvwxyz1234567890ABCDEFGHIJ"
TWILIO_AUTH_TOKEN = "abcdef1234567890abcdef1234567890"
SLACK_WEBHOOK = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
MAILCHIMP_API_KEY = "abcdef123456789012345678901234-us1"

# Cloud provider credentials
AZURE_CLIENT_SECRET = "abc~XYZ1234567890abcdefghijklmnop"
GCP_SERVICE_ACCOUNT_KEY = """
{
  "type": "service_account",
  "project_id": "my-project-123",
  "private_key_id": "key123",
  "private_key": "-----BEGIN PRIVATE KEY-----\\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASC...\\n-----END PRIVATE KEY-----\\n",
  "client_email": "my-service@my-project-123.iam.gserviceaccount.com",
  "client_id": "123456789",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}
"""

# Private keys
RSA_PRIVATE_KEY = """-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA0Z3VS5JJcds3xfn/ygWyF8PbnGy...
-----END RSA PRIVATE KEY-----"""

SSH_PRIVATE_KEY = """-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAAB...
-----END OPENSSH PRIVATE KEY-----"""


# =============================================================================
# WEAK CRYPTOGRAPHY
# =============================================================================

def encrypt_data_weak(data: str, key: str) -> bytes:
    """VULNERABLE: Using DES which is cryptographically broken"""
    from Crypto.Cipher import DES
    # VULNERABLE: DES is weak
    cipher = DES.new(key.encode()[:8], DES.MODE_ECB)
    padded = data + ' ' * (8 - len(data) % 8)
    return cipher.encrypt(padded.encode())


def encrypt_with_ecb(data: bytes, key: bytes) -> bytes:
    """VULNERABLE: ECB mode is insecure"""
    # VULNERABLE: ECB mode doesn't hide patterns
    cipher = Cipher(algorithms.AES(key), modes.ECB(), backend=default_backend())
    encryptor = cipher.encryptor()
    return encryptor.update(data) + encryptor.finalize()


def weak_hmac(message: str, key: str) -> str:
    """VULNERABLE: Using MD5 for HMAC"""
    # VULNERABLE: MD5 should not be used for cryptographic purposes
    return hmac.new(key.encode(), message.encode(), hashlib.md5).hexdigest()


def insecure_compare(a: str, b: str) -> bool:
    """VULNERABLE: Non-constant-time comparison"""
    # VULNERABLE: Timing attack possible
    return a == b


# =============================================================================
# UNSAFE FILE OPERATIONS
# =============================================================================

def write_temp_file_insecure(data: str) -> str:
    """VULNERABLE: Insecure temp file creation"""
    # VULNERABLE: Predictable temp file name
    filename = f"/tmp/data_{os.getpid()}.txt"
    with open(filename, 'w') as f:
        f.write(data)
    return filename


def create_temp_insecure():
    """VULNERABLE: Using deprecated mktemp"""
    # VULNERABLE: Race condition with mktemp
    return tempfile.mktemp()


def execute_script(script_path: str) -> int:
    """VULNERABLE: Executing scripts without validation"""
    # VULNERABLE: Arbitrary file execution
    return os.system(f"bash {script_path}")


# =============================================================================
# INSECURE NETWORK
# =============================================================================

def fetch_url_insecure(url: str) -> str:
    """VULNERABLE: No SSL verification"""
    import urllib.request
    import ssl

    # VULNERABLE: Disabling SSL verification
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE

    with urllib.request.urlopen(url, context=context) as response:
        return response.read().decode()


def connect_insecure_socket(host: str, port: int):
    """VULNERABLE: Unencrypted socket connection"""
    import socket
    # VULNERABLE: Plain socket without TLS for sensitive data
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((host, port))
    return sock


# =============================================================================
# UNSAFE DESERIALIZATION
# =============================================================================

def load_pickle_insecure(data: bytes) -> Any:
    """VULNERABLE: Deserializing untrusted pickle"""
    import pickle
    # VULNERABLE: Arbitrary code execution via pickle
    return pickle.loads(data)


def load_yaml_insecure(data: str) -> Any:
    """VULNERABLE: Unsafe YAML loading"""
    import yaml
    # VULNERABLE: yaml.load can execute arbitrary code
    return yaml.load(data, Loader=yaml.Loader)


def load_marshal_insecure(data: bytes) -> Any:
    """VULNERABLE: Deserializing marshal data"""
    import marshal
    # VULNERABLE: marshal can execute code
    return marshal.loads(data)


# =============================================================================
# COMMAND INJECTION HELPERS
# =============================================================================

def run_command(cmd: str) -> str:
    """VULNERABLE: Shell command with user input"""
    # VULNERABLE: Direct shell execution
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout


def backup_file(filename: str, dest: str) -> int:
    """VULNERABLE: Command injection in backup"""
    # VULNERABLE: User input in command
    return os.system(f"cp {filename} {dest}")


def search_files(pattern: str) -> str:
    """VULNERABLE: Command injection in search"""
    # VULNERABLE: User input in command
    result = subprocess.check_output(f"find /app -name '{pattern}'", shell=True)
    return result.decode()


# =============================================================================
# SQL HELPERS (additional patterns)
# =============================================================================

def build_query(table: str, columns: list, where: str) -> str:
    """VULNERABLE: SQL query building without parameterization"""
    cols = ', '.join(columns)
    # VULNERABLE: String formatting in SQL
    return f"SELECT {cols} FROM {table} WHERE {where}"


def insert_record(table: str, data: dict) -> str:
    """VULNERABLE: SQL injection in INSERT"""
    cols = ', '.join(data.keys())
    vals = ', '.join([f"'{v}'" for v in data.values()])
    # VULNERABLE: Direct string interpolation
    return f"INSERT INTO {table} ({cols}) VALUES ({vals})"


# =============================================================================
# AUTHENTICATION ISSUES
# =============================================================================

def verify_password_insecure(stored_hash: str, password: str) -> bool:
    """VULNERABLE: Timing attack in password comparison"""
    computed = hashlib.md5(password.encode()).hexdigest()
    # VULNERABLE: Non-constant-time comparison
    return computed == stored_hash


def generate_session_id() -> str:
    """VULNERABLE: Predictable session ID"""
    import random
    # VULNERABLE: Using random instead of secrets
    return ''.join([chr(random.randint(65, 90)) for _ in range(32)])


def encode_jwt_insecure(payload: dict, secret: str) -> str:
    """VULNERABLE: Custom JWT with weak signature"""
    import json
    header = base64.b64encode(b'{"alg":"HS256","typ":"JWT"}').decode()
    payload_b64 = base64.b64encode(json.dumps(payload).encode()).decode()
    # VULNERABLE: MD5 for signature
    signature = hashlib.md5(f"{header}.{payload_b64}.{secret}".encode()).hexdigest()
    return f"{header}.{payload_b64}.{signature}"


# =============================================================================
# LOGGING ISSUES
# =============================================================================

def log_user_action(username: str, action: str):
    """VULNERABLE: Log injection"""
    import logging
    logger = logging.getLogger(__name__)
    # VULNERABLE: User input in log message
    logger.info(f"User {username} performed: {action}")


def log_sensitive_data(data: dict):
    """VULNERABLE: Logging sensitive information"""
    import logging
    logger = logging.getLogger(__name__)
    # VULNERABLE: Logging passwords/tokens
    logger.debug(f"Processing data: {data}")


# =============================================================================
# CONFIGURATION ISSUES
# =============================================================================

# VULNERABLE: Debug mode in production
DEBUG_MODE = True
TESTING = True

# VULNERABLE: Weak session configuration
SESSION_COOKIE_SECURE = False
SESSION_COOKIE_HTTPONLY = False
SESSION_COOKIE_SAMESITE = None

# VULNERABLE: CORS misconfiguration
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True
