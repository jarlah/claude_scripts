#!/bin/bash

set -euo pipefail

TARGET_DIR=$(pwd)
READONLY=""
TOOLCHAIN="base"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILES_DIR="$SCRIPT_DIR/dockerfiles"
HOST_CLAUDE_DIR="${HOME}/.claude"
HOST_CLAUDE_CONFIG="${HOME}/.claude.json"
CREDENTIALS_FILE="$HOST_CLAUDE_DIR/.credentials.json"

usage() {
    echo "Bruk: $0 [-d katalog] [-r] [-t toolchain]"
    echo "  -d    Katalog Claude skal jobbe i (standard: nåværende)"
    echo "  -r    Monter arbeidskatalogen som skrivebeskyttet (read-only)"
    echo "  -t    Toolchain (standard: base). Tilgjengelige:"
    for f in "$DOCKERFILES_DIR"/*.Dockerfile; do
        [ -e "$f" ] || continue
        name=$(basename "$f" .Dockerfile)
        echo "          - $name"
    done
    exit 1
}

while getopts "d:rt:h" opt; do
    case $opt in
        d) TARGET_DIR=$(realpath "$OPTARG") ;;
        r) READONLY=":ro" ;;
        t) TOOLCHAIN="$OPTARG" ;;
        *) usage ;;
    esac
done

DOCKERFILE="$DOCKERFILES_DIR/${TOOLCHAIN}.Dockerfile"
if [ ! -f "$DOCKERFILE" ]; then
    echo "Feil: fant ikke $DOCKERFILE"
    usage
fi

cleanup() {
    # Container runs as root, so writes into $TMP_CLAUDE_DIR are root-owned on the host.
    # Chown back via a throwaway container so plain rm as the host user works.
    if [ -n "${TMP_CLAUDE_DIR:-}" ] && [ -d "$TMP_CLAUDE_DIR" ]; then
        if docker image inspect claude-code-base >/dev/null 2>&1; then
            docker run --rm -v "$TMP_CLAUDE_DIR:/c" claude-code-base \
                chown -R "$(id -u):$(id -g)" /c >/dev/null 2>&1 || true
        fi
        rm -rf "$TMP_CLAUDE_DIR"
    fi
    [ -n "${TMP_CLAUDE_CONFIG:-}" ] && rm -f "$TMP_CLAUDE_CONFIG"
}

CLAUDE_MOUNT=()
if [ -r "$CREDENTIALS_FILE" ] && [ -r "$HOST_CLAUDE_DIR" ]; then
    echo "Fant Claude-innlogging i $HOST_CLAUDE_DIR — kopierer minimal config til throwaway-mount."
    TMP_CLAUDE_DIR=$(mktemp -d)
    trap cleanup EXIT

    # Persistent user state we want inside the container.
    cp "$CREDENTIALS_FILE" "$TMP_CLAUDE_DIR/.credentials.json"
    [ -f "$HOST_CLAUDE_DIR/settings.json" ] && cp "$HOST_CLAUDE_DIR/settings.json" "$TMP_CLAUDE_DIR/"
    [ -d "$HOST_CLAUDE_DIR/plugins" ] && cp -a "$HOST_CLAUDE_DIR/plugins" "$TMP_CLAUDE_DIR/"

    # Empty dirs Claude writes to during a session (parent must exist for plain mkdir).
    mkdir -p \
        "$TMP_CLAUDE_DIR/session-env" \
        "$TMP_CLAUDE_DIR/sessions" \
        "$TMP_CLAUDE_DIR/shell-snapshots" \
        "$TMP_CLAUDE_DIR/todos" \
        "$TMP_CLAUDE_DIR/file-history" \
        "$TMP_CLAUDE_DIR/statsig" \
        "$TMP_CLAUDE_DIR/telemetry" \
        "$TMP_CLAUDE_DIR/projects"

    CLAUDE_MOUNT=(-v "$TMP_CLAUDE_DIR:/root/.claude")

    if [ -r "$HOST_CLAUDE_CONFIG" ]; then
        TMP_CLAUDE_CONFIG=$(mktemp)
        cp "$HOST_CLAUDE_CONFIG" "$TMP_CLAUDE_CONFIG"
        CLAUDE_MOUNT+=(-v "$TMP_CLAUDE_CONFIG:/root/.claude.json")
    fi
else
    echo "Ingen Claude-innlogging funnet — starter throwaway-container, logg inn inne i containeren."
fi

echo "Bygger claude-code-base..."
docker build -t claude-code-base -f "$DOCKERFILES_DIR/base.Dockerfile" "$DOCKERFILES_DIR"

IMAGE_TAG="claude-code-${TOOLCHAIN}"
if [ "$TOOLCHAIN" != "base" ]; then
    echo "Bygger $IMAGE_TAG..."
    docker build -t "$IMAGE_TAG" -f "$DOCKERFILE" "$DOCKERFILES_DIR"
fi

echo "Starter Claude ($TOOLCHAIN) i: $TARGET_DIR (ReadOnly: ${READONLY:-false})"

docker run -it \
  --rm \
  -v "$TARGET_DIR:/app$READONLY" \
  ${CLAUDE_MOUNT[@]+"${CLAUDE_MOUNT[@]}"} \
  --workdir /app \
  "$IMAGE_TAG"
