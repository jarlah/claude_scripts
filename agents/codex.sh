# OpenAI Codex CLI plugin.
#
# Reuses the host login by copying ~/.codex/ (auth.json, config.toml, …) into
# a throwaway dir mounted at /home/node/.codex. Forwards OPENAI_API_KEY if set.

AGENT_CONTAINER_HOME="/home/node"

agent_prepare_mounts() {
    local host_dir="${HOME}/.codex"

    if [ -d "$host_dir" ] && [ -r "$host_dir" ]; then
        echo "Fant Codex-konfig i $host_dir — kopierer til throwaway-mount."
        TMP_AGENT_DIR=$(mktemp -d)
        cp -a "$host_dir/." "$TMP_AGENT_DIR/"
        AGENT_DOCKER_ARGS+=(-v "$TMP_AGENT_DIR:$AGENT_CONTAINER_HOME/.codex")
    else
        echo "Ingen Codex-konfig funnet — starter throwaway-container, logg inn inne i containeren."
    fi

    if [ -n "${OPENAI_API_KEY:-}" ]; then
        AGENT_DOCKER_ARGS+=(-e "OPENAI_API_KEY=$OPENAI_API_KEY")
    fi
}

agent_cleanup() {
    [ -n "${TMP_AGENT_DIR:-}" ] && [ -d "$TMP_AGENT_DIR" ] && rm -rf "$TMP_AGENT_DIR"
}

agent_prompt_argv() {
    AGENT_PROMPT_ARGV=(codex exec --dangerously-bypass-approvals-and-sandbox "$1")
}
