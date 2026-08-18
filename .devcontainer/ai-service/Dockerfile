ARG UV_VERSION=0.12.0
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv
FROM mcr.microsoft.com/devcontainers/python:3.13-bookworm

COPY --from=uv /uv /uvx /usr/local/bin/

ENV UV_CACHE_DIR=/home/vscode/.cache/uv \
    UV_PROJECT_ENVIRONMENT=/home/vscode/.venvs/ragscope-ai-service

USER root

RUN mkdir -p /home/vscode/.cache/uv /home/vscode/.venvs \
    && chown -R vscode:vscode /home/vscode/.cache/uv /home/vscode/.venvs

USER vscode

RUN python --version \
    && uv --version
