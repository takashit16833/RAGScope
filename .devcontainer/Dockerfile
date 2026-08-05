# RAGScopeアプリケーション用のHaskell開発環境。
# AI推論サービスとPostgreSQLは別の実行環境として扱う。
FROM mcr.microsoft.com/devcontainers/base:bookworm

ARG GHC_VERSION=9.12.4
ARG CABAL_VERSION=3.16.1.0
ARG HLS_VERSION=2.14.0.0
ARG CABAL_GILD_VERSION=1.7.0.2
ARG FOURMOLU_VERSION=0.19.0.1
ARG DELTA_VERSION=0.19.2

# パイプ途中の失敗もDockerビルドの失敗として扱う。
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# HaskellツールがUnicodeを含むソースを安定して扱えるようにする。
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

USER root

# 開発とHaskellパッケージのビルドに必要なOS依存を導入する。
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        fd-find \
        libffi-dev \
        libgmp-dev \
        libncurses-dev \
        libnuma-dev \
        pkg-config \
        xz-utils \
        zlib1g-dev \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && architecture="$(dpkg --print-architecture)" \
    && curl -fsSL \
        "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_${architecture}.deb" \
        -o /tmp/git-delta.deb \
    && apt-get install -y --no-install-recommends /tmp/git-delta.deb \
    && fd --version \
    && delta --version \
    && rm -f /tmp/git-delta.deb \
    && rm -rf /var/lib/apt/lists/*

USER vscode

ENV PATH="/home/vscode/.ghcup/bin:/home/vscode/.local/bin:${PATH}"

# GHC、Cabal、HLSをGHCupへ統一し、HLS wrapperから同じGHCを解決できるようにする。
RUN test "$(locale charmap)" = "UTF-8" \
    && mkdir -p /home/vscode/.cabal /home/vscode/.local/bin \
    && curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org \
      | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_MINIMAL=1 sh \
    && ghcup install ghc "${GHC_VERSION}" \
    && ghcup set ghc "${GHC_VERSION}" \
    && ghcup install cabal "${CABAL_VERSION}" \
    && ghcup set cabal "${CABAL_VERSION}" \
    && ghcup install hls "${HLS_VERSION}" \
    && ghcup set hls "${HLS_VERSION}" \
    && test "$(ghc --numeric-version)" = "${GHC_VERSION}" \
    && test "$(cabal --numeric-version)" = "${CABAL_VERSION}" \
    && haskell-language-server-wrapper --version

# GHCupの管理対象外であるformatterを、固定バージョンで導入する。
RUN cabal user-config init \
    && cabal update \
    && cabal install \
      "cabal-gild-${CABAL_GILD_VERSION}" \
      "fourmolu-${FOURMOLU_VERSION}" \
      --install-method=copy \
      --installdir=/home/vscode/.local/bin \
    && cabal-gild --version \
    && fourmolu --version
