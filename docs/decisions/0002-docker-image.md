# 0002. Container image: multi-stage build on python:3.13-slim, non-root

- Status: Accepted
- Date: 2026-10-28

## Context

The app must run identically on a laptop (x86), in CI and on an Oracle Cloud ARM server.
The image should be small, fast to rebuild and safe to run.

## Decision

| Concern | Choice | Alternatives considered | Why |
|---|---|---|---|
| Base image | `python:3.13-slim` | `python:3.13-alpine`, distroless | Debian-based with glibc, so prebuilt Python wheels install as is. Alpine uses musl and often forces slow source builds. Distroless is smaller but has no shell, which makes learning and debugging harder |
| Build structure | Multi-stage (builder + runtime) | Single stage | Build tools and caches stay in the builder; the runtime image only gets the venv and the code |
| Installer in the image | `uv sync --locked --no-dev` | `pip install -r requirements.txt` | Same lockfile as the laptop and CI; `--locked` fails the build if the lock is out of date |
| User | Non-root `appuser` (uid 10001) | root (the default) | Limits damage if the app is compromised; Kubernetes policies can require it |
| Architectures | linux/amd64 and linux/arm64 | amd64 only | The laptop is x86, the Oracle server is ARM (Ampere A1) |

## Consequences

- Dependency layers are cached: editing code rebuilds in seconds.
- The same image tag runs on both architectures (a multi-arch manifest, built in CI).
- Base image updates must be tracked; Dependabot will do this in a later stage.
