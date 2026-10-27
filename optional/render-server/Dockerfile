# Cloud coding-agent workspace: OpenCode (BYOK) + Linux dev toolchain.
# Everything that must survive restarts lives on the persistent disk at /data
# (see scripts/entrypoint.sh); this image only carries reproducible tooling.
FROM node:22-bookworm

# keep in sync with files/OPENCODE_VERSION
ARG OPENCODE_VERSION=1.19.4

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    OPENCODE_DISABLE_AUTOUPDATE=1

RUN set -eux; \
    mkdir -p -m 755 /etc/apt/keyrings; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      gh git git-lfs curl wget ca-certificates jq ripgrep fd-find tree less vim-tiny nano \
      build-essential make cmake pkg-config \
      python3 python3-pip python3-venv python3-dev pipx \
      unzip zip xz-utils openssh-client procps lsof htop tini sqlite3 rsync; \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd; \
    rm -rf /var/lib/apt/lists/*

# uv (fast Python package manager), pnpm/yarn via corepack, OpenCode, Render CLI
RUN set -eux; \
    pip install --no-cache-dir uv; \
    corepack enable; \
    npm install -g --no-fund --no-audit "opencode-ai@${OPENCODE_VERSION}"; \
    opencode --version; \
    curl -fsSL https://raw.githubusercontent.com/render-oss/cli/refs/heads/main/bin/install.sh | sh; \
    (command -v render || ln -sf "$HOME/.local/bin/render" /usr/local/bin/render); \
    render --version

# Build context is the repo root (see render.yaml).
COPY files/gen-opencode-config.sh /opt/cloud-agent/
COPY files/render-deploy-check /usr/local/bin/
COPY optional/render-server/entrypoint.sh optional/render-server/AGENTS.md optional/render-server/bashrc.example /opt/cloud-agent/server/
RUN chmod +x /opt/cloud-agent/gen-opencode-config.sh /usr/local/bin/render-deploy-check /opt/cloud-agent/server/entrypoint.sh

ENV DATA_DIR=/data PORT=10000
EXPOSE 10000
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/cloud-agent/server/entrypoint.sh"]
