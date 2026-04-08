FROM golang:alpine

# ---------- Base y dependencias ----------
USER root
ENV GO111MODULE=on

# Versiones (las que realmente necesites puedes fijarlas)
ARG GOLANGCI_LINT_VERSION=v1.61.0
ARG GOPLS_VERSION=latest
ARG DELVE_VERSION=latest
ARG GOMODIFYTAGS_VERSION=v1.16.0
ARG GOPLAY_VERSION=v1.0.0
ARG GOTESTS_VERSION=v1.6.0

# Herramientas base + docker-cli (para Docker-outside-of-Docker)
RUN apk upgrade --no-cache && \
    apk add --no-cache --progress \
    git build-base findutils make \
    bat exa coreutils wget curl bash \
    binutils jq sudo g++ py3-pip yq \
    github-cli \
    nodejs npm shadow docker-cli docker-cli-buildx docker-cli-compose ca-certificates

# ---------- Usuario no root ----------
# Crear usuario
RUN useradd -m -s /bin/bash devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Preparar GOPATH para devuser en su home
RUN mkdir -p /home/devuser/go/pkg/mod /home/devuser/go/bin && \
    chown -R devuser:devuser /home/devuser/go

ENV GOPATH=/home/devuser/go
ENV GOMODCACHE=/home/devuser/go/pkg/mod
ENV PATH="${PATH}:/home/devuser/go/bin"

# ---------- golangci-lint ----------
RUN wget -qO- https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh \
    | sh -s -- -b /usr/local/bin -d ${GOLANGCI_LINT_VERSION}

# ---------- Utilidades Go (robusto, no rompe el build) ----------
RUN set -eux; \
    go install golang.org/x/tools/gopls@${GOPLS_VERSION} || true; \
    go install github.com/ramya-rao-a/go-outline@latest || true; \
    go install golang.org/x/tools/cmd/guru@latest || true; \
    go install golang.org/x/tools/cmd/gorename@latest || true; \
    go install github.com/go-delve/delve/cmd/dlv@${DELVE_VERSION} || true; \
    go install github.com/fatih/gomodifytags@${GOMODIFYTAGS_VERSION} || true; \
    go install github.com/haya14busa/goplay/cmd/goplay@${GOPLAY_VERSION} || true; \
    go install github.com/cweill/gotests/...@${GOTESTS_VERSION} || true; \
    go install github.com/davidrjenni/reftools/cmd/fillstruct@latest || true; \
    go install mvdan.cc/gofumpt@latest || true; \
    go install github.com/uudashr/gopkgs/v2/cmd/gopkgs@latest || true; \
    go install github.com/cuonglm/gocmt@latest || true; \
    go install github.com/go-task/task/v3/cmd/task@latest || true; \
    go install github.com/terraform-linters/tflint@latest || true; \
    go install github.com/zricethezav/gitleaks/v8@latest || true; \
    go install github.com/terraform-docs/terraform-docs@v0.21.0 || true; \
    go install github.com/jstemmer/go-junit-report/v2@latest || true; \
    rm -rf "$GOPATH/pkg"/* "$GOPATH/src"/* /root/.cache/go-build || true

# GOPRIVATE para tus módulos
RUN go env -w GOPRIVATE=github.com/crizstian

# ---------- tfenv + Terraform ----------
RUN git clone --depth=1 https://github.com/tfutils/tfenv.git /home/devuser/.tfenv && \
    chown -R devuser:devuser /home/devuser/.tfenv && \
    echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> /home/devuser/.profile && \
    ln -s /home/devuser/.tfenv/bin/* /usr/local/bin && \
    tfenv install latest && \
    tfenv use latest

# ---------- kubectl (versión más nueva) ----------
ARG KUBECTL_VERSION=v1.30.0
RUN curl -L "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl && \
  chmod +x /usr/local/bin/kubectl


# ---------- Google Cloud SDK ----------
RUN curl -sSL https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.tar.gz -o /tmp/google-cloud-sdk.tar.gz && \
    mkdir -p /usr/local/gcloud && \
    tar -C /usr/local/gcloud -xzf /tmp/google-cloud-sdk.tar.gz && \
    /usr/local/gcloud/google-cloud-sdk/install.sh --quiet && \
    rm /tmp/google-cloud-sdk.tar.gz

ENV PATH="${PATH}:/usr/local/gcloud/google-cloud-sdk/bin"

RUN gcloud components install gke-gcloud-auth-plugin --quiet || true

# ---------- Docker buildx (manual install as fallback) ----------
ARG BUILDX_VERSION=v0.17.1
RUN mkdir -p /usr/lib/docker/cli-plugins && \
    curl -sSL "https://github.com/docker/buildx/releases/download/${BUILDX_VERSION}/buildx-${BUILDX_VERSION}.linux-amd64" \
      -o /usr/lib/docker/cli-plugins/docker-buildx && \
    chmod +x /usr/lib/docker/cli-plugins/docker-buildx

# ---------- CLI tools via npm ----------
RUN npm install -g @anthropic-ai/claude-code harness-mcp-v2 @stoplight/spectral-cli

# Dentro del DevContainer
RUN git clone --depth=1 https://github.com/harness/harness-skills.git .harness-skills

# ---------- Workspace ----------
RUN mkdir -p /workspace && chown -R devuser:devuser /workspace

USER devuser
WORKDIR /workspace

CMD ["bash"]
