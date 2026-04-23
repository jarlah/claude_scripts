FROM claude-code-base

USER root

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:${PATH}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        curl build-essential pkg-config libssl-dev \
        libasound2-dev libudev-dev \
        libwayland-dev libxkbcommon-dev \
        libx11-dev libxcursor-dev libxi-dev libxrandr-dev \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --default-toolchain stable --profile minimal --no-modify-path \
    && chmod -R a+rwX /usr/local/rustup /usr/local/cargo \
    && rm -rf /var/lib/apt/lists/*

USER node
