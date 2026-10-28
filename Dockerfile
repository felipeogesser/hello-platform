# syntax=docker/dockerfile:1

# ---------- Stage 1: builder ----------
# Has the build tools (uv). Installs dependencies into /app/.venv.
FROM python:3.13-slim AS builder

# Copy the uv binary from its official image instead of installing it with pip.
COPY --from=ghcr.io/astral-sh/uv:0.11 /uv /bin/uv

# Precompile .py to .pyc (faster startup); copy files instead of hard-linking
# (needed with a cache mount); never let uv download another Python.
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0

WORKDIR /app

# Dependencies first, code second: this layer is only rebuilt when
# pyproject.toml or uv.lock change, not on every code edit.
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev --no-install-project

COPY app ./app

# ---------- Stage 2: runtime ----------
# Starts from a clean image: no uv, no build cache, no dev dependencies.
FROM python:3.13-slim AS runtime

# Run as an unprivileged user: if the app is compromised, the attacker is not root.
RUN python -m pip uninstall -y pip \
    && rm -rf /usr/local/lib/python3.13/ensurepip \
    && useradd --create-home --uid 10001 appuser

WORKDIR /app
COPY --from=builder --chown=appuser:appuser /app/.venv /app/.venv
COPY --from=builder --chown=appuser:appuser /app/app /app/app

# Use the venv's Python; print logs immediately (important for docker logs).
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

USER appuser
EXPOSE 8000

# Docker marks the container unhealthy if /health stops answering.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/health', timeout=2)"]

# Exec form: uvicorn is PID 1 and receives stop signals directly.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]