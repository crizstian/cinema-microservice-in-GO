# =============================================================================
# infra-repo DevContainer
# Terraform, Kubernetes, Helm, Cloud CLIs
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
    git curl wget bash jq yq unzip \
    make \
    docker-cli docker-cli-compose \
    nodejs npm \
    python3 py3-pip \
    ca-certificates sudo shadow \
    github-cli \
    openssh-client

# -----------------------------------------------------------------------------
# tfenv + Terraform
# -----------------------------------------------------------------------------
RUN git clone --depth=1 https://github.com/tfutils/tfenv.git /opt/tfenv && \
    ln -s /opt/tfenv/bin/* /usr/local/bin && \
    tfenv install latest && \
    tfenv use latest

# -----------------------------------------------------------------------------
# tflint (pre-built binary)
# -----------------------------------------------------------------------------
ARG TFLINT_VERSION=v0.50.3
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_${ARCH}.zip" \
    -o /tmp/tflint.zip && \
    unzip -q /tmp/tflint.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/tflint && \
    rm /tmp/tflint.zip

# -----------------------------------------------------------------------------
# terraform-docs (pre-built binary)
# -----------------------------------------------------------------------------
ARG TERRAFORM_DOCS_VERSION=v0.18.0
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/terraform-docs/terraform-docs/releases/download/${TERRAFORM_DOCS_VERSION}/terraform-docs-${TERRAFORM_DOCS_VERSION}-linux-${ARCH}.tar.gz" | \
    tar xz -C /usr/local/bin terraform-docs && \
    chmod +x /usr/local/bin/terraform-docs

# -----------------------------------------------------------------------------
# kubectl
# -----------------------------------------------------------------------------
ARG KUBECTL_VERSION=v1.30.0
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -L "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
    -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

# -----------------------------------------------------------------------------
# Helm
# -----------------------------------------------------------------------------
ARG HELM_VERSION=v3.14.0
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" | \
    tar xz -C /tmp && \
    mv /tmp/linux-${ARCH}/helm /usr/local/bin/helm && \
    rm -rf /tmp/linux-${ARCH}

# -----------------------------------------------------------------------------
# Kustomize
# -----------------------------------------------------------------------------
ARG KUSTOMIZE_VERSION=v5.3.0
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") && \
    curl -fsSL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_${ARCH}.tar.gz" | \
    tar xz -C /usr/local/bin

# -----------------------------------------------------------------------------
# Google Cloud SDK
# -----------------------------------------------------------------------------
RUN curl -sSL https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz \
    -o /tmp/google-cloud-sdk.tar.gz && \
    mkdir -p /usr/local/gcloud && \
    tar -C /usr/local/gcloud -xzf /tmp/google-cloud-sdk.tar.gz && \
    /usr/local/gcloud/google-cloud-sdk/install.sh --quiet && \
    rm /tmp/google-cloud-sdk.tar.gz

ENV PATH="${PATH}:/usr/local/gcloud/google-cloud-sdk/bin"

RUN gcloud components install gke-gcloud-auth-plugin --quiet || true

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
    mcp-server-kubernetes

# -----------------------------------------------------------------------------
# Workspace
# -----------------------------------------------------------------------------
RUN mkdir -p /workspace && chown -R devuser:devuser /workspace

USER devuser
WORKDIR /workspace

CMD ["bash"]
