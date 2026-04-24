# Claude Code plugin.
#
# Reuses the host login if present: copies ~/.claude/.credentials.json,
# settings.json and plugins/ into a throwaway dir that gets mounted at
# /home/node/.claude, plus ~/.claude.json as a writable temp copy.
# Session-scratch subdirs are created empty so Claude can write into them.

AGENT_CONTAINER_HOME="/home/node"

agent_prepare_mounts() {
    local host_dir="${HOME}/.claude"
    local host_config="${HOME}/.claude.json"
    local creds="$host_dir/.credentials.json"

    if [ ! -r "$creds" ] || [ ! -r "$host_dir" ]; then
        echo "Ingen Claude-innlogging funnet — starter throwaway-container, logg inn inne i containeren."
        return 0
    fi

    echo "Fant Claude-innlogging i $host_dir — kopierer minimal config til throwaway-mount."
    TMP_AGENT_DIR=$(mktemp -d)

    cp "$creds" "$TMP_AGENT_DIR/.credentials.json"
    [ -f "$host_dir/settings.json" ] && cp "$host_dir/settings.json" "$TMP_AGENT_DIR/"
    [ -d "$host_dir/plugins" ] && cp -a "$host_dir/plugins" "$TMP_AGENT_DIR/"

    mkdir -p \
        "$TMP_AGENT_DIR/session-env" \
        "$TMP_AGENT_DIR/sessions" \
        "$TMP_AGENT_DIR/shell-snapshots" \
        "$TMP_AGENT_DIR/todos" \
        "$TMP_AGENT_DIR/file-history" \
        "$TMP_AGENT_DIR/statsig" \
        "$TMP_AGENT_DIR/telemetry" \
        "$TMP_AGENT_DIR/projects"

    AGENT_DOCKER_ARGS+=(-v "$TMP_AGENT_DIR:$AGENT_CONTAINER_HOME/.claude")

    if [ -r "$host_config" ]; then
        TMP_AGENT_CONFIG=$(mktemp)
        cp "$host_config" "$TMP_AGENT_CONFIG"
        AGENT_DOCKER_ARGS+=(-v "$TMP_AGENT_CONFIG:$AGENT_CONTAINER_HOME/.claude.json")
    fi
}

agent_cleanup() {
    [ -n "${TMP_AGENT_DIR:-}" ] && [ -d "$TMP_AGENT_DIR" ] && rm -rf "$TMP_AGENT_DIR"
    [ -n "${TMP_AGENT_CONFIG:-}" ] && rm -f "$TMP_AGENT_CONFIG"
}

agent_prompt_argv() {
    AGENT_PROMPT_ARGV=(claude --dangerously-skip-permissions --print "$1")
}
