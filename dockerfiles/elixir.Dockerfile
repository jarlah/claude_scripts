FROM claude-code-base

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget gnupg build-essential \
    && wget -O /tmp/erlang-solutions.deb https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb \
    && dpkg -i /tmp/erlang-solutions.deb \
    && rm /tmp/erlang-solutions.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends esl-erlang elixir \
    && rm -rf /var/lib/apt/lists/*

USER node
RUN mix local.hex --force && mix local.rebar --force
