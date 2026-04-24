# Aider plugin.
#
# Aider authenticates purely via env vars and an optional ~/.aider.conf.yml.
# Forwards the common provider keys plus a host config file if present.

AGENT_CONTAINER_HOME="/home/node"

agent_prepare_mounts() {
    local host_conf="${HOME}/.aider.conf.yml"

    if [ -r "$host_conf" ]; then
        echo "Fant Aider-konfig i $host_conf — kopierer til throwaway-mount."
        TMP_AGENT_CONFIG=$(mktemp)
        cp "$host_conf" "$TMP_AGENT_CONFIG"
        AGENT_DOCKER_ARGS+=(-v "$TMP_AGENT_CONFIG:$AGENT_CONTAINER_HOME/.aider.conf.yml:ro")
    fi

    local var
    for var in OPENAI_API_KEY ANTHROPIC_API_KEY DEEPSEEK_API_KEY \
               OPENROUTER_API_KEY GEMINI_API_KEY GROQ_API_KEY \
               MISTRAL_API_KEY COHERE_API_KEY; do
        if [ -n "${!var:-}" ]; then
            AGENT_DOCKER_ARGS+=(-e "$var=${!var}")
        fi
    done

    if [ ${#AGENT_DOCKER_ARGS[@]} -eq 0 ]; then
        echo "Ingen Aider-konfig eller API-nøkler funnet — sett f.eks. OPENAI_API_KEY før du kjører."
    fi
}

agent_cleanup() {
    [ -n "${TMP_AGENT_CONFIG:-}" ] && rm -f "$TMP_AGENT_CONFIG"
}
