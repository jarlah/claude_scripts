#!/bin/bash

set -euo pipefail

TARGET_DIR=$(pwd)
READONLY=""
AGENT="claude"
TOOLCHAIN="base"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$SCRIPT_DIR/agents"
AGENT_DOCKERFILES_DIR="$SCRIPT_DIR/dockerfiles/agents"
TOOLCHAINS_DIR="$SCRIPT_DIR/dockerfiles/toolchains"
# shellcheck source=check_sensitive.sh
source "$SCRIPT_DIR/check_sensitive.sh"

list_values() {
    local dir="$1"
    local ext="$2"
    for f in "$dir"/*."$ext"; do
        [ -e "$f" ] || continue
        local name
        name=$(basename "$f" ".$ext")
        echo "          - $name"
    done
}

usage() {
    echo "Bruk: $0 [-a agent] [-d katalog] [-r] [-t toolchain]"
    echo "  -a    Agent (standard: claude). Tilgjengelige:"
    list_values "$AGENT_DOCKERFILES_DIR" "Dockerfile"
    echo "  -d    Katalog agenten skal jobbe i (standard: nåværende)"
    echo "  -r    Monter arbeidskatalogen som skrivebeskyttet (read-only)"
    echo "  -t    Toolchain (standard: base). Tilgjengelige:"
    echo "          - base"
    list_values "$TOOLCHAINS_DIR" "Dockerfile"
    exit 1
}

while getopts "a:d:rt:h" opt; do
    case $opt in
        a) AGENT="$OPTARG" ;;
        d) TARGET_DIR=$(realpath "$OPTARG") ;;
        r) READONLY=":ro" ;;
        t) TOOLCHAIN="$OPTARG" ;;
        *) usage ;;
    esac
done

AGENT_PLUGIN="$AGENTS_DIR/${AGENT}.sh"
AGENT_DOCKERFILE="$AGENT_DOCKERFILES_DIR/${AGENT}.Dockerfile"
if [ ! -f "$AGENT_PLUGIN" ] || [ ! -f "$AGENT_DOCKERFILE" ]; then
    echo "Feil: ukjent agent '$AGENT'"
    usage
fi

if [ "$TOOLCHAIN" != "base" ]; then
    TOOLCHAIN_DOCKERFILE="$TOOLCHAINS_DIR/${TOOLCHAIN}.Dockerfile"
    if [ ! -f "$TOOLCHAIN_DOCKERFILE" ]; then
        echo "Feil: fant ikke $TOOLCHAIN_DOCKERFILE"
        usage
    fi
fi

check_sensitive_files "$TARGET_DIR" || exit 1

# Agent plugin contract: sets AGENT_CONTAINER_HOME, and defines
# agent_prepare_mounts / agent_cleanup. Populates AGENT_DOCKER_ARGS.
AGENT_DOCKER_ARGS=()
TMP_AGENT_DIR=""
TMP_AGENT_CONFIG=""

# shellcheck source=/dev/null
source "$AGENT_PLUGIN"

cleanup() {
    if declare -F agent_cleanup >/dev/null; then
        agent_cleanup
    fi
}
trap cleanup EXIT

agent_prepare_mounts

AGENT_BASE_IMAGE="agent-runner-${AGENT}"
echo "Bygger $AGENT_BASE_IMAGE..."
docker build -t "$AGENT_BASE_IMAGE" -f "$AGENT_DOCKERFILE" "$AGENT_DOCKERFILES_DIR"

IMAGE_TAG="$AGENT_BASE_IMAGE"
if [ "$TOOLCHAIN" != "base" ]; then
    IMAGE_TAG="${AGENT_BASE_IMAGE}-${TOOLCHAIN}"
    echo "Bygger $IMAGE_TAG..."
    docker build \
        -t "$IMAGE_TAG" \
        --build-arg "BASE_IMAGE=$AGENT_BASE_IMAGE" \
        -f "$TOOLCHAIN_DOCKERFILE" \
        "$TOOLCHAINS_DIR"
fi

echo "Starter $AGENT ($TOOLCHAIN) i: $TARGET_DIR (ReadOnly: ${READONLY:-false})"

USER_ARGS=(--user "$(id -u):$(id -g)")
DOCKER_VERSION_OUTPUT=$(docker --version 2>&1 || true)
if [[ "$DOCKER_VERSION_OUTPUT" == *[Pp]odman* ]]; then
    # Rootless podman: map container uid/gid 1000 to host user so bind-mounted
    # files keep host ownership. Passing --user with host IDs breaks setgroups
    # in the user namespace.
    #
    # --group-add keep-groups skips setgroups() in crun (via the
    # run.oci.keep_original_groups=1 annotation). Needed on LDAP/AD-joined
    # hosts where the user has supplementary GIDs outside the /etc/subgid
    # range — otherwise crun fails with `setgroups: Invalid argument`.
    USER_ARGS=(--userns=keep-id:uid=1000,gid=1000 --group-add keep-groups)
fi

docker run -it \
  --rm \
  "${USER_ARGS[@]}" \
  -v "$TARGET_DIR:/app$READONLY" \
  ${AGENT_DOCKER_ARGS[@]+"${AGENT_DOCKER_ARGS[@]}"} \
  --workdir /app \
  "$IMAGE_TAG"
