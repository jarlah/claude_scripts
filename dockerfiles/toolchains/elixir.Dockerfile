ARG ELIXIR_IMAGE=hexpm/elixir:1.19.5-erlang-28.3.2-debian-bookworm-20260421-slim
ARG BASE_IMAGE

FROM ${ELIXIR_IMAGE} AS elixir-src

FROM ${BASE_IMAGE}

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libncurses6 libssl3 zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=elixir-src /usr/local/lib/erlang /usr/local/lib/erlang
COPY --from=elixir-src /usr/local/lib/elixir /usr/local/lib/elixir

RUN ln -s /usr/local/lib/erlang/bin/erl /usr/local/bin/erl \
    && ln -s /usr/local/lib/erlang/bin/erlc /usr/local/bin/erlc \
    && ln -s /usr/local/lib/erlang/bin/escript /usr/local/bin/escript \
    && ln -s /usr/local/lib/erlang/bin/dialyzer /usr/local/bin/dialyzer \
    && ln -s /usr/local/lib/erlang/bin/ct_run /usr/local/bin/ct_run \
    && ln -s /usr/local/lib/erlang/bin/typer /usr/local/bin/typer \
    && ln -s /usr/local/lib/elixir/bin/elixir /usr/local/bin/elixir \
    && ln -s /usr/local/lib/elixir/bin/elixirc /usr/local/bin/elixirc \
    && ln -s /usr/local/lib/elixir/bin/iex /usr/local/bin/iex \
    && ln -s /usr/local/lib/elixir/bin/mix /usr/local/bin/mix

USER node
RUN mix local.hex --force && mix local.rebar --force
