FROM node:22-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

# Make $HOME world-writable so the container works when run with
# --user $(id -u):$(id -g) from the host.
RUN chmod 777 /home/node \
    && mkdir -p /app && chown node:node /app

USER node
WORKDIR /app

CMD ["claude", "--dangerously-skip-permissions"]
