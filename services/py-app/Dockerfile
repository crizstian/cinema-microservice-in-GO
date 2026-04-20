# =============================================================================
# Dockerfile para Yalo Demo App
# ADVERTENCIA: Contiene configuraciones vulnerables intencionales para demo
# =============================================================================

# VULNERABLE: Using old base image with known vulnerabilities
FROM python:3.9-slim-buster

# Metadata
LABEL maintainer="demo@harness.io"
LABEL description="Yalo Demo App for Harness STO Demo"
LABEL version="1.0.0"

# VULNERABLE: Running as root (should use non-root user)
# ENV USER=root

# Set working directory
WORKDIR /app

# Copy requirements first for layer caching
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY tests/ ./tests/
COPY pytest.ini .

# Create data directory
RUN mkdir -p /app/data

# VULNERABLE: Exposing debug port
EXPOSE 5000

# Environment variables
ENV FLASK_APP=src/app.py
ENV FLASK_ENV=development
ENV PYTHONPATH=/app

# VULNERABLE: Debug mode enabled
ENV FLASK_DEBUG=1

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run the application
CMD ["python", "-m", "flask", "run", "--host=0.0.0.0", "--port=5000"]
