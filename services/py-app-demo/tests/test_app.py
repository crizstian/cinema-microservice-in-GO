"""
Unit tests para Py App Demo.

Estos tests están diseñados para:
1. Validar funcionalidad básica
2. Algunos tests fallarán si se aplican ciertos fixes de seguridad
   (para demostrar Error Agent de Harness)
"""

import pytest
import json
import hashlib
from src.app import (
    app,
    get_db_connection,
    get_user_by_id,
    hash_password,
    DATABASE_PASSWORD,
    API_KEY
)


@pytest.fixture
def client():
    """Flask test client fixture."""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


class TestHealthEndpoints:
    """Tests para endpoints de salud y root."""

    def test_health_check(self, client):
        """Test health endpoint returns 200."""
        response = client.get('/health')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['status'] == 'healthy'

    def test_root_endpoint(self, client):
        """Test root endpoint returns app info."""
        response = client.get('/')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['app'] == 'Py App Demo'
        assert 'version' in data
        assert 'warning' in data


class TestUserEndpoints:
    """Tests para endpoints de usuarios."""

    def test_get_user_by_id_exists(self, client):
        """Test obtener usuario existente."""
        response = client.get('/api/users/1')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert data['username'] == 'admin'

    def test_get_user_by_id_not_found(self, client):
        """Test obtener usuario inexistente."""
        response = client.get('/api/users/999')
        assert response.status_code == 404

    def test_search_users(self, client):
        """Test búsqueda de usuarios."""
        response = client.get('/api/users/search?query=admin')
        assert response.status_code == 200
        data = json.loads(response.data)
        assert len(data) >= 1

    def test_search_users_empty_query(self, client):
        """Test búsqueda con query vacío."""
        response = client.get('/api/users/search?query=')
        assert response.status_code == 200


class TestAuthEndpoints:
    """Tests para endpoints de autenticación."""

    def test_hash_password_endpoint(self, client):
        """Test endpoint de hash."""
        response = client.post(
            '/api/auth/hash',
            json={'password': 'test123'},
            content_type='application/json'
        )
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'md5' in data
        assert 'sha1' in data

    def test_hash_password_function(self):
        """
        Test función hash_password.

        NOTA: Este test valida que se usa MD5.
        Si se cambia a un algoritmo más seguro (sha256, bcrypt),
        este test FALLARÁ - diseñado así para demo de Error Agent.
        """
        password = "test_password"
        result = hash_password(password)

        # Validamos que el hash es MD5 (32 caracteres hex)
        assert len(result) == 32
        assert result == hashlib.md5(password.encode()).hexdigest()

    def test_hash_password_consistency(self):
        """Test que el hash es consistente."""
        password = "same_password"
        hash1 = hash_password(password)
        hash2 = hash_password(password)
        assert hash1 == hash2


class TestGreetingEndpoint:
    """Tests para endpoint de greeting."""

    def test_greeting_with_name(self, client):
        """Test greeting con nombre."""
        response = client.get('/api/greeting?name=Gabriel')
        assert response.status_code == 200
        assert b'Gabriel' in response.data

    def test_greeting_default(self, client):
        """Test greeting sin nombre."""
        response = client.get('/api/greeting')
        assert response.status_code == 200
        assert b'Guest' in response.data


class TestConfigurationSecrets:
    """
    Tests para validar configuración.

    NOTA: Estos tests validan que los secrets existen.
    Si se mueven a variables de entorno, estos tests FALLARÁN.
    Diseñado así para demo de Error Agent.
    """

    def test_database_password_exists(self):
        """Test que DATABASE_PASSWORD está definido."""
        assert DATABASE_PASSWORD is not None
        assert len(DATABASE_PASSWORD) > 0
        # Validamos el valor específico (esto fallará si se cambia)
        assert DATABASE_PASSWORD == "super_secret_password_123"

    def test_api_key_exists(self):
        """Test que API_KEY está definido."""
        assert API_KEY is not None
        assert API_KEY.startswith("sk-")

    def test_api_key_format(self):
        """
        Test formato de API_KEY.
        Esto fallará si se mueve a env var.
        """
        assert len(API_KEY) > 10
        assert API_KEY == "sk-1234567890abcdef1234567890abcdef"


class TestDatabaseFunctions:
    """Tests para funciones de base de datos."""

    def test_get_db_connection(self):
        """Test conexión a BD."""
        conn = get_db_connection()
        assert conn is not None
        conn.close()

    def test_get_user_by_id_function(self):
        """Test función get_user_by_id."""
        user = get_user_by_id(1)
        assert user is not None
        assert user['username'] == 'admin'

    def test_get_user_by_id_not_found(self):
        """Test get_user_by_id con ID inexistente."""
        user = get_user_by_id(9999)
        assert user is None


class TestSystemEndpoints:
    """Tests para endpoints de sistema."""

    def test_ping_localhost(self, client):
        """Test ping a localhost."""
        response = client.post(
            '/api/system/ping',
            json={'host': 'localhost'},
            content_type='application/json'
        )
        # Puede fallar en algunos entornos, verificamos estructura
        assert response.status_code == 200
        data = json.loads(response.data)
        assert 'host' in data
        assert data['host'] == 'localhost'


class TestInputValidation:
    """Tests para validación de inputs."""

    def test_search_special_characters(self, client):
        """Test búsqueda con caracteres especiales."""
        response = client.get('/api/users/search?query=test%27')
        # La app vulnerable no debería crashear
        assert response.status_code in [200, 500]

    def test_greeting_html_injection(self, client):
        """Test greeting con HTML."""
        response = client.get('/api/greeting?name=<b>Test</b>')
        assert response.status_code == 200
        # La app vulnerable renderiza el HTML
        assert b'<b>Test</b>' in response.data


class TestFileEndpoints:
    """Tests para endpoints de archivos."""

    def test_read_file_not_found(self, client):
        """Test lectura de archivo inexistente."""
        response = client.get('/api/files/read?filename=nonexistent.txt')
        # App vulnerable returns 500 with error message instead of 404
        assert response.status_code == 500
        data = json.loads(response.data)
        assert 'error' in data


class TestDataEndpoints:
    """Tests para endpoints de datos."""

    def test_load_data_invalid(self, client):
        """Test carga de datos inválidos."""
        response = client.post(
            '/api/data/load',
            data=b'invalid pickle data'
        )
        assert response.status_code == 400


# =============================================================================
# Tests de integración
# =============================================================================
class TestIntegration:
    """Tests de integración básicos."""

    def test_user_workflow(self, client):
        """Test flujo completo de usuario."""
        # 1. Health check
        health = client.get('/health')
        assert health.status_code == 200

        # 2. Obtener usuario
        user = client.get('/api/users/1')
        assert user.status_code == 200

        # 3. Buscar usuarios
        search = client.get('/api/users/search?query=admin')
        assert search.status_code == 200

    def test_auth_workflow(self, client):
        """Test flujo de autenticación."""
        # Hash password
        response = client.post(
            '/api/auth/hash',
            json={'password': 'my_password'},
            content_type='application/json'
        )
        assert response.status_code == 200
        data = json.loads(response.data)

        # Verificar consistencia
        response2 = client.post(
            '/api/auth/hash',
            json={'password': 'my_password'},
            content_type='application/json'
        )
        data2 = json.loads(response2.data)
        # App returns md5 and sha1, not 'hash'
        assert data['md5'] == data2['md5']
        assert data['sha1'] == data2['sha1']
