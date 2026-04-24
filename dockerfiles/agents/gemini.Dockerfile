FROM node:22-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @google/gemini-cli

RUN chmod 777 /home/node \
    && mkdir -p /app && chown node:node /app

USER node
WORKDIR /app

CMD ["gemini", "--yolo"]
