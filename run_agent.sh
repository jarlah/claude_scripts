#!/bin/bash

set -euo pipefail

TARGET_DIR=$(pwd)
READONLY=""
AGENT="claude"
TOOLCHAIN="base"
COMMAND=""
PROMPT=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$SCRIPT_DIR/agents"
AGENT_DOCKERFILES_DIR="$SCRIPT_DIR/dockerfiles/agents"
TOOLCHAINS_DIR="$SCRIPT_DIR/dockerfiles/toolchains"
RUNTIME="${RUNTIME:-docker}"
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
    echo "Bruk: $0 [-a agent] [-d katalog] [-r] [-t toolchain] [-c kommando | -p prompt]"
    echo "  -a    Agent (standard: claude). Tilgjengelige:"
    list_values "$AGENT_DOCKERFILES_DIR" "Dockerfile"
    echo "  -d    Katalog agenten skal jobbe i (standard: nåværende)"
    echo "  -r    Monter arbeidskatalogen som skrivebeskyttet (read-only)"
    echo "  -t    Toolchain (standard: base). Tilgjengelige:"
    echo "          - base"
    list_values "$TOOLCHAINS_DIR" "Dockerfile"
    echo "  -c    Kjør kommando ikke-interaktivt i containeren (overstyrer agent CMD)"
    echo "  -p    Send prompt ikke-interaktivt til agenten"
    echo
    echo "Miljø:"
    echo "  RUNTIME   Container-runtime (standard: docker; sett til podman for rootless)"
    exit 1
}

while getopts "a:d:rt:c:p:h" opt; do
    case $opt in
        a) AGENT="$OPTARG" ;;
        d) TARGET_DIR=$(realpath "$OPTARG") ;;
        r) READONLY=":ro" ;;
        t) TOOLCHAIN="$OPTARG" ;;
        c) COMMAND="$OPTARG" ;;
        p) PROMPT="$OPTARG" ;;
        *) usage ;;
    esac
done

if [ -n "$COMMAND" ] && [ -n "$PROMPT" ]; then
    echo "Feil: -c og -p kan ikke brukes samtidig" >&2
    usage
fi

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

# Agent plugin contract: sets AGENT_CONTAINER_HOME, defines
# agent_prepare_mounts / agent_cleanup, and (for -p) agent_prompt_argv.
# Populates AGENT_DOCKER_ARGS and AGENT_PROMPT_ARGV.
AGENT_DOCKER_ARGS=()
AGENT_PROMPT_ARGV=()
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
"$RUNTIME" build -t "$AGENT_BASE_IMAGE" -f "$AGENT_DOCKERFILE" "$AGENT_DOCKERFILES_DIR"

IMAGE_TAG="$AGENT_BASE_IMAGE"
if [ "$TOOLCHAIN" != "base" ]; then
    IMAGE_TAG="${AGENT_BASE_IMAGE}-${TOOLCHAIN}"
    echo "Bygger $IMAGE_TAG..."
    "$RUNTIME" build \
        -t "$IMAGE_TAG" \
        --build-arg "BASE_IMAGE=$AGENT_BASE_IMAGE" \
        -f "$TOOLCHAIN_DOCKERFILE" \
        "$TOOLCHAINS_DIR"
fi

echo "Starter $AGENT ($TOOLCHAIN) i: $TARGET_DIR (ReadOnly: ${READONLY:-false})"

USER_ARGS=(--user "$(id -u):$(id -g)")
RUNTIME_VERSION_OUTPUT=$("$RUNTIME" --version 2>&1 || true)
if [[ "$RUNTIME_VERSION_OUTPUT" == *[Pp]odman* ]]; then
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

# Mode-dependent argv: interactive (default) keeps -it and the image's CMD;
# -c runs the supplied shell command via sh; -p invokes the agent's prompt
# argv as defined by the plugin. Both non-interactive modes drop -it.
TTY_ARGS=(-it)
RUN_OVERRIDE=("$IMAGE_TAG")
if [ -n "$COMMAND" ]; then
    TTY_ARGS=()
    RUN_OVERRIDE=(--entrypoint sh "$IMAGE_TAG" -c "$COMMAND")
elif [ -n "$PROMPT" ]; then
    if ! declare -F agent_prompt_argv >/dev/null; then
        echo "Feil: agent '$AGENT' støtter ikke prompt-modus" >&2
        exit 1
    fi
    agent_prompt_argv "$PROMPT"
    TTY_ARGS=()
    RUN_OVERRIDE=("$IMAGE_TAG" "${AGENT_PROMPT_ARGV[@]}")
fi

"$RUNTIME" run \
  ${TTY_ARGS[@]+"${TTY_ARGS[@]}"} \
  --rm \
  "${USER_ARGS[@]}" \
  -v "$TARGET_DIR:/app$READONLY" \
  ${AGENT_DOCKER_ARGS[@]+"${AGENT_DOCKER_ARGS[@]}"} \
  --workdir /app \
  "${RUN_OVERRIDE[@]}"
