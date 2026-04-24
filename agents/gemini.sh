# Google Gemini CLI plugin.
#
# Reuses host settings by copying ~/.gemini/ into a throwaway dir mounted at
# /home/node/.gemini. Forwards GEMINI_API_KEY / GOOGLE_API_KEY if set.

AGENT_CONTAINER_HOME="/home/node"

agent_prepare_mounts() {
    local host_dir="${HOME}/.gemini"

    if [ -d "$host_dir" ] && [ -r "$host_dir" ]; then
        echo "Fant Gemini-konfig i $host_dir — kopierer til throwaway-mount."
        TMP_AGENT_DIR=$(mktemp -d)
        cp -a "$host_dir/." "$TMP_AGENT_DIR/"
        AGENT_DOCKER_ARGS+=(-v "$TMP_AGENT_DIR:$AGENT_CONTAINER_HOME/.gemini")
    else
        echo "Ingen Gemini-konfig funnet — starter throwaway-container, logg inn inne i containeren."
    fi

    [ -n "${GEMINI_API_KEY:-}" ] && AGENT_DOCKER_ARGS+=(-e "GEMINI_API_KEY=$GEMINI_API_KEY")
    [ -n "${GOOGLE_API_KEY:-}" ] && AGENT_DOCKER_ARGS+=(-e "GOOGLE_API_KEY=$GOOGLE_API_KEY")
}

agent_cleanup() {
    [ -n "${TMP_AGENT_DIR:-}" ] && [ -d "$TMP_AGENT_DIR" ] && rm -rf "$TMP_AGENT_DIR"
}
