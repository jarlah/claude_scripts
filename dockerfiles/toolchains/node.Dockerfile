ARG BASE_IMAGE

FROM node:20-slim AS node20-src

FROM ${BASE_IMAGE}

USER root

COPY --from=node20-src /usr/local/bin /opt/node20/bin
COPY --from=node20-src /usr/local/include /opt/node20/include
COPY --from=node20-src /usr/local/lib/node_modules /opt/node20/lib/node_modules

ENV PATH=/opt/node20/bin:${PATH}

USER node
