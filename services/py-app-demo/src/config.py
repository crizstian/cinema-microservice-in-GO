"""
Configuration file - Contains hardcoded secrets for Snyk detection demo.

WARNING: This file intentionally contains secrets for demo purposes.
These are FAKE credentials that should still be detected by SAST tools.
"""

import os

# =============================================================================
# DATABASE CONFIGURATION - Hardcoded credentials (CWE-798)
# =============================================================================
DATABASE_CONFIG = {
    "host": "prod-db.company.internal",
    "port": 5432,
    "database": "production",
    "user": "db_admin",
    "password": "Pr0duct10n_P@ssw0rd_2024!",  # Hardcoded password
}

MONGODB_CONFIG = {
    "uri": "mongodb://admin:MongoDBPassword123@mongodb.company.com:27017/admin",
    "database": "customers",
}

REDIS_CONFIG = {
    "host": "redis.company.internal",
    "port": 6379,
    "password": "RedisSecretPassword!",
}

# =============================================================================
# API KEYS AND TOKENS - Patterns that SAST should detect
# =============================================================================

# Payment providers - fake but detectable patterns
PAYMENT_API_KEY = "pk_test_TYooMQauvdEDq54NiTphI7jx"  # Test key pattern
PAYMENT_SECRET_KEY = "sk_test_4eC39HqLyjWDarjtT1zdp7dc"  # Test key pattern

# Email services
EMAIL_API_KEY = "SG.XXXXXXXXXXXXXXXXXXXXXXXX.YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY"
MAIL_API_KEY = "key-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# Communication
SMS_ACCOUNT_SID = "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
SMS_AUTH_TOKEN = "your_auth_token_here_32_characters!"
CHAT_BOT_TOKEN = "xoxb-XXXXXXXXXXXX-XXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXX"
WEBHOOK_SECRET = "whsec_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# Cloud providers - Example format credentials
CLOUD_ACCESS_KEY_ID = "AKIAXXXXXXXXXXXXXXXX"  # AWS format
CLOUD_SECRET_ACCESS_KEY = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"  # 40 chars
CLOUD_SESSION_TOKEN = "FwoGZXIvYXdzEXAMPLETOKEN"

AZURE_CLIENT_ID = "00000000-0000-0000-0000-000000000000"
AZURE_CLIENT_SECRET = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX~-"
AZURE_TENANT_ID = "00000000-0000-0000-0000-000000000000"

GCP_API_KEY = "AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
GCP_SERVICE_ACCOUNT_KEY = """{
  "type": "service_account",
  "project_id": "example-project-123456",
  "private_key_id": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  "private_key": "-----BEGIN PRIVATE KEY-----\\nXXXXXXXX...\\n-----END PRIVATE KEY-----\\n",
  "client_email": "example@example-project.iam.gserviceaccount.com",
  "client_id": "000000000000000000000"
}"""

DO_TOKEN = "dop_v1_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# Source control
SCM_TOKEN = "ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
SCM_APP_PRIVATE_KEY = """-----BEGIN RSA PRIVATE KEY-----
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
-----END RSA PRIVATE KEY-----"""
GITLAB_ACCESS_TOKEN = "glpat-XXXXXXXXXXXXXXXXXXXX"

# CI/CD
CI_TOKEN = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
JENKINS_API_TOKEN = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# Monitoring
MONITORING_API_KEY = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
MONITORING_APP_KEY = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
APM_LICENSE_KEY = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXNRAL"
ERROR_DSN = "https://XXXXXXXX@o123456.ingest.example.io/1234567"

# =============================================================================
# ENCRYPTION KEYS - Hardcoded (CWE-321)
# =============================================================================
JWT_SECRET_KEY = "super-secret-jwt-key-that-should-be-in-env-vars"
ENCRYPTION_KEY = "ThisIsAHardcodedEncryptionKey123!"
SIGNING_KEY = "MySigningKeyForHMAC256Operations"
FERNET_KEY = "ZmVybmV0X2tleV8xMjM0NTY3ODkwYWJjZGVm"
AES_KEY = "0123456789ABCDEF0123456789ABCDEF"

# =============================================================================
# OAUTH SECRETS
# =============================================================================
OAUTH_CLIENT_SECRET = "GOCSPX-XXXXXXXXXXXXXXXXXXXXXXXX"
SOCIAL_APP_SECRET = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
OAUTH_API_SECRET = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

# =============================================================================
# INTERNAL SERVICES
# =============================================================================
INTERNAL_API_KEY = "internal-api-key-for-service-to-service"
SERVICE_AUTH_TOKEN = "service-auth-token-1234567890"
ADMIN_PASSWORD = "AdminP@ssword123!"
ROOT_PASSWORD = "r00t_p@ssw0rd_2024"
MASTER_KEY = "master-key-for-all-services-xyz123"

# =============================================================================
# DATABASE CONNECTION STRINGS (CWE-798)
# =============================================================================
POSTGRES_URI = "postgresql://admin:password123@db.example.com:5432/production"
MYSQL_URI = "mysql://root:mysqlpassword@mysql.example.com:3306/app"
MSSQL_URI = "mssql+pyodbc://sa:SqlServer2024!@mssql.example.com/database"

# =============================================================================
# CONFIGURATION (INSECURE SETTINGS)
# =============================================================================
class Config:
    SECRET_KEY = "you-will-never-guess-this-secret-key"  # Hardcoded
    DEBUG = True  # Debug in production
    TESTING = False

    # Database with credentials
    SQLALCHEMY_DATABASE_URI = "postgresql://admin:password123@db.example.com/prod"
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Insecure session config
    SESSION_COOKIE_SECURE = False  # Cookies over HTTP
    SESSION_COOKIE_HTTPONLY = False  # XSS can steal cookies
    SESSION_COOKIE_SAMESITE = None  # CSRF vulnerable
    PERMANENT_SESSION_LIFETIME = 86400 * 365  # 1 year session

    # CSRF disabled
    WTF_CSRF_ENABLED = False

    # Insecure CORS
    CORS_ORIGINS = "*"  # Allow all origins
    CORS_SUPPORTS_CREDENTIALS = True  # With wildcard = vulnerable


class ProductionConfig(Config):
    """Production config that's actually insecure"""
    DEBUG = True  # Debug in production!
    SQLALCHEMY_DATABASE_URI = DATABASE_CONFIG
