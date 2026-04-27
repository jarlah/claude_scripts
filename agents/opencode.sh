# OpenCode plugin.
#
# Reuses the host config if present: copies ~/.config/opencode/opencode.json
# and tui.json into a throwaway dir mounted at /home/node/.config/opencode.
# The auth file (~/.local/share/opencode/auth.json, written by
# "opencode auth login") is copied into a throwaway .local tree mounted at
# /home/node/.local so provider credentials work and runtime state is writable.
# Common provider API keys are also forwarded from the host environment.

AGENT_CONTAINER_HOME="/home/node"

agent_prepare_mounts() {
    local host_config_dir="${HOME}/.config/opencode"
    local host_auth="${HOME}/.local/share/opencode/auth.json"
    local found_creds=0

    # Check for any usable credentials (config dir or auth file or env keys)
    if [ -d "$host_config_dir" ] || [ -f "$host_auth" ] \
        || [ -n "${ANTHROPIC_API_KEY:-}" ] \
        || [ -n "${OPENAI_API_KEY:-}" ] \
        || [ -n "${GEMINI_API_KEY:-}" ] \
        || [ -n "${OPENROUTER_API_KEY:-}" ] \
        || [ -n "${OPENCODE_API_KEY:-}" ]; then
        found_creds=1
    fi

    if [ "$found_creds" -eq 0 ]; then
        echo "No OpenCode credentials found — starting throwaway container, log in inside the container."
        return 0
    fi

    echo "Found OpenCode credentials — copying minimal config to throwaway mounts."

    # --- config dir ---
    TMP_AGENT_DIR=$(mktemp -d)
    mkdir -p "$TMP_AGENT_DIR"

    [ -f "$host_config_dir/opencode.json" ] && cp "$host_config_dir/opencode.json" "$TMP_AGENT_DIR/"
    [ -f "$host_config_dir/tui.json" ]      && cp "$host_config_dir/tui.json"      "$TMP_AGENT_DIR/"

    # Create writable scratch dirs OpenCode may write into during the session
    mkdir -p \
        "$TMP_AGENT_DIR/agents" \
        "$TMP_AGENT_DIR/commands" \
        "$TMP_AGENT_DIR/plugins" \
        "$TMP_AGENT_DIR/themes"

    AGENT_DOCKER_ARGS+=(-v "$TMP_AGENT_DIR:$AGENT_CONTAINER_HOME/.config/opencode")

    # --- .local (auth + writable runtime state) ---
    if [ -f "$host_auth" ]; then
        TMP_AGENT_LOCAL=$(mktemp -d)
        mkdir -p "$TMP_AGENT_LOCAL/share/opencode" "$TMP_AGENT_LOCAL/state"
        cp "$host_auth" "$TMP_AGENT_LOCAL/share/opencode/auth.json"
        AGENT_DOCKER_ARGS+=(-v "$TMP_AGENT_LOCAL:$AGENT_CONTAINER_HOME/.local")
    fi

    # --- provider API keys from host environment ---
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        AGENT_DOCKER_ARGS+=(-e "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY")
    fi
    if [ -n "${OPENAI_API_KEY:-}" ]; then
        AGENT_DOCKER_ARGS+=(-e "OPENAI_API_KEY=$OPENAI_API_KEY")
    fi
    if [ -n "${GEMINI_API_KEY:-}" ]; then
        AGENT_DOCKER_ARGS+=(-e "GEMINI_API_KEY=$GEMINI_API_KEY")
    fi
    if [ -n "${OPENROUTER_API_KEY:-}" ]; then
        AGENT_DOCKER_ARGS+=(-e "OPENROUTER_API_KEY=$OPENROUTER_API_KEY")
    fi
    if [ -n "${OPENCODE_API_KEY:-}" ]; then
        AGENT_DOCKER_ARGS+=(-e "OPENCODE_API_KEY=$OPENCODE_API_KEY")
    fi

    return 0
}

agent_cleanup() {
    [ -n "${TMP_AGENT_DIR:-}"  ] && [ -d "$TMP_AGENT_DIR"  ] && rm -rf "$TMP_AGENT_DIR"
    [ -n "${TMP_AGENT_LOCAL:-}" ] && [ -d "$TMP_AGENT_LOCAL" ] && rm -rf "$TMP_AGENT_LOCAL"
}

agent_prompt_argv() {
    AGENT_PROMPT_ARGV=(opencode run --dangerously-skip-permissions "$1")
}
