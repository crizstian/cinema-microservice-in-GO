# =============================================================================
# services-repo DevContainer
# Multi-language: Go, Java, Python
# =============================================================================
FROM alpine:3.19

USER root

# -----------------------------------------------------------------------------
# Architecture detection (works for amd64 and arm64)
# -----------------------------------------------------------------------------
ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH:-amd64}

# -----------------------------------------------------------------------------
# Base dependencies + Go
# -----------------------------------------------------------------------------
RUN apk upgrade --no-cache && \
    apk add --no-cache \
    git curl wget bash jq yq unzip \
    build-base make \
    docker-cli docker-cli-compose \
    nodejs npm \
    python3 py3-pip \
    openjdk21 maven \
    go \
    ca-certificates sudo shadow \
    github-cli

# -----------------------------------------------------------------------------
# Gradle
# -----------------------------------------------------------------------------
ARG GRADLE_VERSION=8.5
RUN wget -q https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip \
      -O /tmp/gradle.zip && \
    unzip -q /tmp/gradle.zip -d /opt && \
    ln -s /opt/gradle-${GRADLE_VERSION}/bin/gradle /usr/local/bin/gradle && \
    rm /tmp/gradle.zip

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk
ENV PATH="${PATH}:${JAVA_HOME}/bin"

# -----------------------------------------------------------------------------
# Non-root user
# -----------------------------------------------------------------------------
RUN adduser -D -s /bin/bash devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Go paths
RUN mkdir -p /home/devuser/go/pkg/mod /home/devuser/go/bin && \
    chown -R devuser:devuser /home/devuser/go

ENV GOPATH=/home/devuser/go
ENV GOMODCACHE=/home/devuser/go/pkg/mod
ENV PATH="${PATH}:/home/devuser/go/bin:/usr/lib/go/bin"

# -----------------------------------------------------------------------------
# Go tools (pinned versions compatible with Go 1.21)
# -----------------------------------------------------------------------------
ENV GOBIN=/usr/local/bin
RUN go install golang.org/x/tools/gopls@v0.15.3 || true && \
    go install github.com/go-delve/delve/cmd/dlv@v1.22.1 || true && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@v1.57.2 || true && \
    go install github.com/jstemmer/go-junit-report/v2@v2.1.0 || true && \
    rm -rf /root/.cache/go-build /root/go

# -----------------------------------------------------------------------------
# Taskfile (task runner)
# -----------------------------------------------------------------------------
ARG TASK_VERSION=v3.35.1
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/go-task/task/releases/download/${TASK_VERSION}/task_linux_${ARCH}.tar.gz" | \
    tar xz -C /usr/local/bin task && \
    chmod +x /usr/local/bin/task

# -----------------------------------------------------------------------------
# CLI tools via npm
# -----------------------------------------------------------------------------
RUN npm install -g \
    @anthropic-ai/claude-code \
    harness-mcp-v2 \
    @modelcontextprotocol/server-github \
    @perplexity-ai/mcp-server \
    @stoplight/spectral-cli

# -----------------------------------------------------------------------------
# Workspace
# -----------------------------------------------------------------------------
RUN mkdir -p /workspace && chown -R devuser:devuser /workspace

USER devuser
WORKDIR /workspace

CMD ["bash"]
