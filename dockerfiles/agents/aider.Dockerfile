FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Match other agents: uid 1000 user at /home/node so --userns=keep-id works
# identically across agents and toolchain layers can assume this user.
RUN groupadd -g 1000 node \
    && useradd -u 1000 -g 1000 -m -d /home/node -s /bin/bash node \
    && chmod 777 /home/node \
    && mkdir -p /app && chown node:node /app

RUN pip install --no-cache-dir --break-system-packages aider-chat

USER node
WORKDIR /app

CMD ["aider", "--yes-always"]
