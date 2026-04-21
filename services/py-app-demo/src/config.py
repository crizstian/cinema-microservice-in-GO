"""
Configuration file - Contains hardcoded secrets for Snyk detection demo.

WARNING: This file intentionally contains secrets for demo purposes.
"""

import os

# =============================================================================
# DATABASE CONFIGURATION
# =============================================================================
DATABASE_CONFIG = {
    "host": "prod-db.company.internal",
    "port": 5432,
    "database": "production",
    "user": "db_admin",
    "password": "Pr0duct10n_P@ssw0rd_2024!",  # VULNERABLE: Hardcoded password
}

MONGODB_CONFIG = {
    "uri": "mongodb://admin:MongoDBPassword123@mongodb.company.com:27017/admin",  # VULNERABLE
    "database": "customers",
}

REDIS_CONFIG = {
    "host": "redis.company.internal",
    "port": 6379,
    "password": "RedisSecretPassword!",  # VULNERABLE
}

# =============================================================================
# API KEYS AND TOKENS
# =============================================================================

# Payment providers
STRIPE_SECRET_KEY = "xxx"
STRIPE_PUBLISHABLE_KEY = "xxx"
PAYPAL_CLIENT_SECRET = "EKj9KLmNOPqRsTuVwXyZ0123456789AbCdEfGhIjKlMn"
SQUARE_ACCESS_TOKEN = "EAAAECXxyz123456789abcdefghijklmnopqrstuvwxyzABCDEF"

# Email services
SENDGRID_API_KEY = "SG.abcdefghijklmnopqrstuvwxyz.1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZ"
MAILGUN_API_KEY = "key-1234567890abcdefghijklmnopqrstuv"
POSTMARK_SERVER_TOKEN = "12345678-1234-1234-1234-123456789012"

# Communication
TWILIO_ACCOUNT_SID = "xxx"
TWILIO_AUTH_TOKEN = "xxxx"
SLACK_BOT_TOKEN = "xoxb-1234567890123-1234567890123-AbCdEfGhIjKlMnOpQrStUvWx"
SLACK_SIGNING_SECRET = "1234567890abcdef1234567890abcdef"
DISCORD_BOT_TOKEN = "MTIzNDU2Nzg5MDEyMzQ1Njc4OQ.AbCdEf.GhIjKlMnOpQrStUvWxYz1234567890"

# Cloud providers
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "xx/x/x"
AWS_SESSION_TOKEN = "xxx"

AZURE_CLIENT_ID = "12345678-1234-1234-1234-123456789012"
AZURE_CLIENT_SECRET = "abcdefghijklmnopqrstuvwxyz123456~-"
AZURE_TENANT_ID = "12345678-1234-1234-1234-123456789012"
AZURE_SUBSCRIPTION_ID = "12345678-1234-1234-1234-123456789012"

GCP_API_KEY = "AIzaSyDaGmWKa4JsXZ-HjGw7ISLn_3namBGewQe"
GCP_SERVICE_ACCOUNT = """{
  "type": "service_account",
  "project_id": "my-project-123456",
  "private_key_id": "abc123def456ghi789jkl012mno345pqr678stu901",
  "private_key": "-----BEGIN PRIVATE KEY-----\\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7...\\n-----END PRIVATE KEY-----\\n",
  "client_email": "service-account@my-project-123456.iam.gserviceaccount.com",
  "client_id": "123456789012345678901",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}"""

DIGITALOCEAN_TOKEN = "dop_v1_1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
HEROKU_API_KEY = "12345678-1234-1234-1234-123456789012"

# Source control
GITHUB_TOKEN = "ghp_1234567890abcdefghijklmnopqrstuvwxyz"
GITHUB_APP_PRIVATE_KEY = """-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA0Z3VS5JJcds3xfn/ygWyF8PbnGy...
-----END RSA PRIVATE KEY-----"""
GITLAB_TOKEN = "glpat-xxxxxxxxxxxxxxxxxxxx"
BITBUCKET_APP_PASSWORD = "ATBBxxxxxxxxxxxxxxxxxxxxxxxxxx"

# CI/CD
CIRCLECI_TOKEN = "1234567890abcdef1234567890abcdef12345678"
TRAVIS_TOKEN = "1234567890abcdefghij"
JENKINS_API_TOKEN = "1234567890abcdef1234567890abcdef"

# Monitoring
DATADOG_API_KEY = "1234567890abcdef1234567890abcdef"
DATADOG_APP_KEY = "1234567890abcdef1234567890abcdef12345678"
NEW_RELIC_LICENSE_KEY = "1234567890abcdef1234567890abcdef12345678NRAL"
SENTRY_DSN = "https://1234567890abcdef@o123456.ingest.sentry.io/1234567"
PAGERDUTY_API_KEY = "u+1234567890abcdefghij"

# =============================================================================
# ENCRYPTION KEYS
# =============================================================================
JWT_SECRET_KEY = "super-secret-jwt-key-that-should-be-in-env-vars"
ENCRYPTION_KEY = "ThisIsAHardcodedEncryptionKey123!"
SIGNING_KEY = "MySigningKeyForHMAC256Operations"
FERNET_KEY = "ZmVybmV0X2tleV8xMjM0NTY3ODkwYWJjZGVm"

# =============================================================================
# OAUTH SECRETS
# =============================================================================
GOOGLE_CLIENT_SECRET = "GOCSPX-1234567890abcdefghijklmnop"
FACEBOOK_APP_SECRET = "1234567890abcdef1234567890abcdef"
TWITTER_API_SECRET = "1234567890ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"
LINKEDIN_CLIENT_SECRET = "1234567890AbCdEf"

# =============================================================================
# WEBHOOK SECRETS
# =============================================================================
GITHUB_WEBHOOK_SECRET = "webhook_secret_1234567890"
STRIPE_WEBHOOK_SECRET = "whsec_1234567890abcdefghijklmnopqrstuvwxyz"
SHOPIFY_WEBHOOK_SECRET = "shpss_1234567890abcdef"

# =============================================================================
# INTERNAL SERVICES
# =============================================================================
INTERNAL_API_KEY = "internal-api-key-for-service-to-service"
SERVICE_AUTH_TOKEN = "service-auth-token-1234567890"
ADMIN_PASSWORD = "AdminP@ssword123!"

# =============================================================================
# CONFIGURATION (INSECURE SETTINGS)
# =============================================================================
class Config:
    SECRET_KEY = "you-will-never-guess-this-secret-key"  # VULNERABLE
    DEBUG = True  # VULNERABLE: Debug in production
    TESTING = False

    # Database
    SQLALCHEMY_DATABASE_URI = f"postgresql://admin:password123@db.example.com/prod"  # VULNERABLE
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Session
    SESSION_COOKIE_SECURE = False  # VULNERABLE: Cookies over HTTP
    SESSION_COOKIE_HTTPONLY = False  # VULNERABLE: XSS can steal cookies
    SESSION_COOKIE_SAMESITE = None  # VULNERABLE: CSRF
    PERMANENT_SESSION_LIFETIME = 86400 * 365  # VULNERABLE: 1 year session

    # Security
    WTF_CSRF_ENABLED = False  # VULNERABLE: CSRF disabled

    # CORS
    CORS_ORIGINS = "*"  # VULNERABLE: Allow all origins
    CORS_SUPPORTS_CREDENTIALS = True  # VULNERABLE with wildcard origin


class ProductionConfig(Config):
    """Production config that's actually insecure"""
    DEBUG = True  # VULNERABLE: Debug enabled in production
    SQLALCHEMY_DATABASE_URI = DATABASE_CONFIG
