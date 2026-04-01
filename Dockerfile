# -----------------------------------------------
FROM ghcr.io/astral-sh/uv:latest AS uv

# -----------------------------------------------
FROM python:3.14-slim-trixie

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
        ca-certificates curl wget git wget

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    mkdir -p -m 755 /etc/apt/keyrings \
	  && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	  && cat $out | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	  && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	  && mkdir -p -m 755 /etc/apt/sources.list.d \
	  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	  && apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
        gh

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt clean \
    && rm -rf /var/lib/apt/lists/*

# install uv system-wide
COPY --from=uv /uv /uvx /usr/local/bin/

# use the system Python interpreter - don't let uv download its own
ENV UV_PYTHON_DOWNLOADS=never

RUN groupadd --system --gid 1000 claude \
    && useradd --system \
        --gid 1000 --uid 1000 \
        --create-home --shell \
        /bin/bash \
        claude

WORKDIR /home/claude

# install claude code (native binary, available to all users via /usr/local/bin/claude)
RUN curl -fsSL https://claude.ai/install.sh | bash -x

RUN cp -RvP /root/.local . \
    && chown -R claude:claude .local \
    && cp /home/claude/.local/bin/claude /usr/bin/claude \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/claude/.bashrc

USER claude
WORKDIR /app

