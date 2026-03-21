# -----------------------------------------------
FROM ghcr.io/astral-sh/uv:latest AS uv

# -----------------------------------------------
FROM python:3.14-slim-trixie

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt update \
    && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
        ca-certificates curl wget git \
        gosu passwd \
    && rm -rf /var/lib/apt/lists/*

# install uv system-wide/for all users
COPY --from=uv /uv /uvx /usr/local/bin/
# use the system Python interpreter; don't let uv download its own
ENV UV_PYTHON_DOWNLOADS=never

# install claude code (native binary, available to all users via /usr/local/bin/claude)
RUN curl -fsSL https://claude.ai/install.sh | bash \
    && if ! [ -f /usr/local/bin/claude ]; then \
        find /root/.claude -name "claude" -type f -perm /111 2>/dev/null \
            | head -1 \
            | xargs -I{} install -m 755 {} /usr/local/bin/claude; \
    fi

RUN groupadd --system --gid 999 claude \
    && useradd --system \
        --gid 999 --uid 999 \
        --create-home --shell \
        /bin/bash \
        claude

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /app

# this file maps the host UID/GID to the claude user before dropping privileges
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

