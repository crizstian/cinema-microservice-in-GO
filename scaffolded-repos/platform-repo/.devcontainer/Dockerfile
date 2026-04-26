# =============================================================================
# platform-repo DevContainer
# CI/CD, Docker, YAML, Security tooling
# =============================================================================
FROM alpine:3.19

USER root

# -----------------------------------------------------------------------------
# Architecture detection (works for amd64 and arm64)
# -----------------------------------------------------------------------------
ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH:-amd64}

# -----------------------------------------------------------------------------
# Base dependencies
# -----------------------------------------------------------------------------
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    git curl wget bash jq yq \
    make shellcheck \
    docker-cli docker-cli-compose docker-cli-buildx \
    nodejs npm \
    python3 py3-pip \
    ca-certificates sudo shadow \
    github-cli

# -----------------------------------------------------------------------------
# OPA (Open Policy Agent)
# -----------------------------------------------------------------------------
ARG OPA_VERSION=v0.60.0
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -L -o /usr/local/bin/opa \
    "https://openpolicyagent.org/downloads/${OPA_VERSION}/opa_linux_${ARCH}_static" && \
    chmod +x /usr/local/bin/opa

# -----------------------------------------------------------------------------
# Taskfile (task runner)
# -----------------------------------------------------------------------------
ARG TASK_VERSION=v3.35.1
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_${ARCH}.tar.gz" | \
    tar xz -C /usr/local/bin task && \
    chmod +x /usr/local/bin/task

# -----------------------------------------------------------------------------
# Non-root user
# -----------------------------------------------------------------------------
RUN adduser -D -s /bin/bash devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# -----------------------------------------------------------------------------
# CLI tools via npm
# -----------------------------------------------------------------------------
RUN npm install -g \
    @anthropic-ai/claude-code \
    harness-mcp-v2 \
    @modelcontextprotocol/server-github \
    @stoplight/spectral-cli \
    ajv-cli

# -----------------------------------------------------------------------------
# Python tools
# -----------------------------------------------------------------------------
RUN pip3 install --break-system-packages \
    yamllint \
    yq

# -----------------------------------------------------------------------------
# Workspace
# -----------------------------------------------------------------------------
RUN mkdir -p /workspace && chown -R devuser:devuser /workspace

USER devuser
WORKDIR /workspace

CMD ["bash"]
