FROM node:22-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @openai/codex

RUN chmod 777 /home/node \
    && mkdir -p /app && chown node:node /app

USER node
WORKDIR /app

CMD ["codex", "--dangerously-bypass-approvals-and-sandbox"]
