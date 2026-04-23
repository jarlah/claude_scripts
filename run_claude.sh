#!/bin/bash

# Standardverdier
TARGET_DIR=$(pwd)
READONLY=""
VOLUME_NAME="claude-config"

usage() {
    echo "Bruk: $0 [-d katalog] [-r] [-v volumnavn]"
    echo "  -d    Katalog Claude skal jobbe i (standard: nåværende)"
    echo "  -r    Monter som skrivebeskyttet (read-only)"
    echo "  -v    Docker volumnavn for konfigurasjon (standard: claude-config)"
    exit 1
}

# Håndter argumenter
while getopts "d:rv:" opt; do
    case $opt in
        d) TARGET_DIR=$(realpath "$OPTARG") ;;
        r) READONLY=":ro" ;;
        v) VOLUME_NAME="$OPTARG" ;;
        *) usage ;;
    esac
done

# Innebygd Dockerfile som en streng
DOCKERFILE="FROM node:18-slim
RUN npm install -g @anthropic-ai/claude-code
WORKDIR /app
CMD [\"claude\"]"

echo "Bygger Claude Code bilde..."
echo "$DOCKERFILE" | docker build -t claude-code-local -f - .

echo "Starter Claude i: $TARGET_DIR (ReadOnly: ${READONLY:-false})"

# Kjør containeren
docker run -it \
  --rm \
  -v "$TARGET_DIR:/app$READONLY" \
  -v "$VOLUME_NAME:/root/.claude" \
  --workdir /app \
  claude-code-local
