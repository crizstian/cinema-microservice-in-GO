"""
Utils module - Additional vulnerabilities for Snyk detection demo.
These are intentional security issues for demonstration purposes.
"""

import os
import ssl
import hmac
import base64
import hashlib
import tempfile
import subprocess
from typing import Any


# =============================================================================
# HARDCODED CREDENTIALS - SAST detectable patterns (CWE-798)
# =============================================================================

# Database credentials - hardcoded
DB_HOST = "production-db.internal.company.com"
DB_USER = "admin"
DB_PASSWORD = "SuperSecretP@ssw0rd!"  # Hardcoded password
DB_NAME = "customers"

# API Keys - various formats (using X placeholders to avoid GitHub detection)
PAYMENT_KEY = "pk_test_XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
EMAIL_KEY = "SG.XXXXXXXXXXXXXXXX.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
SMS_TOKEN = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# Cloud provider credentials (example format)
CLOUD_ACCESS_KEY = "AKIAXXXXXXXXXXEXAMPLE"
CLOUD_SECRET_KEY = "wJalrXXXXXXXXXXXXXXXXXXXXXXXXXXEXAMPLE"

# Connection strings with embedded credentials
DATABASE_URL = "postgresql://admin:password123@localhost:5432/production_db"
REDIS_URL = "redis://:secretpassword@redis.example.com:6379/0"

# Private keys (truncated for demo)
RSA_PRIVATE_KEY = """-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEA0Z3VS5JJcXXXXXXXXXXXXXXXXX...
-----END RSA PRIVATE KEY-----"""

SSH_PRIVATE_KEY = """-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUXXXXXXXXXXX...
-----END OPENSSH PRIVATE KEY-----"""


# =============================================================================
# WEAK CRYPTOGRAPHY (CWE-327, CWE-328)
# =============================================================================

def encrypt_data_weak(data: str, key: str) -> bytes:
    """VULNERABLE: Using DES which is cryptographically broken"""
    # Simulated DES encryption - weak algorithm
    from hashlib import md5
    return md5((data + key).encode()).digest()


def weak_hash(data: str) -> str:
    """VULNERABLE: MD5 is cryptographically broken"""
    return hashlib.md5(data.encode()).hexdigest()


def weak_hash_sha1(data: str) -> str:
    """VULNERABLE: SHA1 is also weak for security"""
    return hashlib.sha1(data.encode()).hexdigest()


def weak_hmac(message: str, key: str) -> str:
    """VULNERABLE: Using MD5 for HMAC"""
    return hmac.new(key.encode(), message.encode(), hashlib.md5).hexdigest()


def insecure_compare(a: str, b: str) -> bool:
    """VULNERABLE: Non-constant-time comparison - timing attack"""
    return a == b  # Should use hmac.compare_digest


# =============================================================================
# UNSAFE FILE OPERATIONS (CWE-377, CWE-379)
# =============================================================================

def write_temp_file_insecure(data: str) -> str:
    """VULNERABLE: Insecure temp file creation"""
    # Predictable temp file name - race condition
    filename = f"/tmp/data_{os.getpid()}.txt"
    with open(filename, 'w') as f:
        f.write(data)
    return filename


def create_temp_insecure():
    """VULNERABLE: Using deprecated mktemp"""
    # Race condition vulnerability
    return tempfile.mktemp()


def execute_script(script_path: str) -> int:
    """VULNERABLE: Executing scripts without validation"""
    # Arbitrary file execution
    return os.system(f"bash {script_path}")


# =============================================================================
# INSECURE NETWORK (CWE-295)
# =============================================================================

def fetch_url_insecure(url: str) -> str:
    """VULNERABLE: No SSL verification"""
    import urllib.request

    # Disabling SSL verification - MITM attack possible
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE

    with urllib.request.urlopen(url, context=context) as response:
        return response.read().decode()


def connect_insecure_socket(host: str, port: int):
    """VULNERABLE: Unencrypted socket connection"""
    import socket
    # Plain socket without TLS for sensitive data
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.connect((host, port))
    return sock


# =============================================================================
# UNSAFE DESERIALIZATION (CWE-502)
# =============================================================================

def load_pickle_insecure(data: bytes) -> Any:
    """VULNERABLE: Deserializing untrusted pickle"""
    import pickle
    # Arbitrary code execution via pickle
    return pickle.loads(data)


def load_yaml_insecure(data: str) -> Any:
    """VULNERABLE: Unsafe YAML loading"""
    import yaml
    # yaml.load can execute arbitrary code
    return yaml.load(data, Loader=yaml.Loader)


def load_marshal_insecure(data: bytes) -> Any:
    """VULNERABLE: Deserializing marshal data"""
    import marshal
    # marshal can execute code
    return marshal.loads(data)


# =============================================================================
# COMMAND INJECTION (CWE-78)
# =============================================================================

def run_command(cmd: str) -> str:
    """VULNERABLE: Shell command with user input"""
    # Direct shell execution
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout


def backup_file(filename: str, dest: str) -> int:
    """VULNERABLE: Command injection in backup"""
    # User input in command
    return os.system(f"cp {filename} {dest}")


def search_files(pattern: str) -> str:
    """VULNERABLE: Command injection in search"""
    # User input in command
    result = subprocess.check_output(f"find /app -name '{pattern}'", shell=True)
    return result.decode()


def ping_host(host: str) -> str:
    """VULNERABLE: Command injection in ping"""
    # User input directly in shell command
    result = subprocess.run(f"ping -c 1 {host}", shell=True, capture_output=True, text=True)
    return result.stdout


# =============================================================================
# SQL HELPERS - Injection patterns (CWE-89)
# =============================================================================

def build_query(table: str, columns: list, where: str) -> str:
    """VULNERABLE: SQL query building without parameterization"""
    cols = ', '.join(columns)
    # String formatting in SQL
    return f"SELECT {cols} FROM {table} WHERE {where}"


def insert_record(table: str, data: dict) -> str:
    """VULNERABLE: SQL injection in INSERT"""
    cols = ', '.join(data.keys())
    vals = ', '.join([f"'{v}'" for v in data.values()])
    # Direct string interpolation
    return f"INSERT INTO {table} ({cols}) VALUES ({vals})"


def delete_record(table: str, condition: str) -> str:
    """VULNERABLE: SQL injection in DELETE"""
    # User input in DELETE statement
    return f"DELETE FROM {table} WHERE {condition}"


# =============================================================================
# AUTHENTICATION ISSUES (CWE-330, CWE-916)
# =============================================================================

def verify_password_insecure(stored_hash: str, password: str) -> bool:
    """VULNERABLE: Timing attack in password comparison"""
    computed = hashlib.md5(password.encode()).hexdigest()
    # Non-constant-time comparison
    return computed == stored_hash


def generate_session_id() -> str:
    """VULNERABLE: Predictable session ID"""
    import random
    # Using random instead of secrets
    return ''.join([chr(random.randint(65, 90)) for _ in range(32)])


def generate_token() -> str:
    """VULNERABLE: Weak random for security token"""
    import random
    # Predictable token generation
    return ''.join([str(random.randint(0, 9)) for _ in range(32)])


def encode_jwt_insecure(payload: dict, secret: str) -> str:
    """VULNERABLE: Custom JWT with weak signature"""
    import json
    header = base64.b64encode(b'{"alg":"HS256","typ":"JWT"}').decode()
    payload_b64 = base64.b64encode(json.dumps(payload).encode()).decode()
    # MD5 for signature - weak
    signature = hashlib.md5(f"{header}.{payload_b64}.{secret}".encode()).hexdigest()
    return f"{header}.{payload_b64}.{signature}"


# =============================================================================
# LOGGING ISSUES (CWE-117, CWE-532)
# =============================================================================

def log_user_action(username: str, action: str):
    """VULNERABLE: Log injection"""
    import logging
    logger = logging.getLogger(__name__)
    # User input directly in log message
    logger.info(f"User {username} performed: {action}")


def log_sensitive_data(data: dict):
    """VULNERABLE: Logging sensitive information"""
    import logging
    logger = logging.getLogger(__name__)
    # Logging passwords/tokens - sensitive data exposure
    logger.debug(f"Processing data: {data}")


# =============================================================================
# CODE INJECTION (CWE-94)
# =============================================================================

def evaluate_expression(expr: str) -> Any:
    """VULNERABLE: eval with user input"""
    # Arbitrary code execution
    return eval(expr)


def execute_code(code: str):
    """VULNERABLE: exec with user input"""
    # Arbitrary code execution
    exec(code)


def compile_and_run(code: str):
    """VULNERABLE: compile and exec"""
    compiled = compile(code, '<string>', 'exec')
    exec(compiled)


# =============================================================================
# CONFIGURATION ISSUES
# =============================================================================

# Debug mode in production
DEBUG_MODE = True
TESTING = True

# Weak session configuration
SESSION_COOKIE_SECURE = False
SESSION_COOKIE_HTTPONLY = False
SESSION_COOKIE_SAMESITE = None

# CORS misconfiguration
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True
