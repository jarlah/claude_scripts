# agents in rootless docker

Run a coding agent ([Claude Code](https://github.com/anthropics/claude-code), [OpenAI Codex CLI](https://github.com/openai/codex), [Gemini CLI](https://github.com/google-gemini/gemini-cli), or [Aider](https://github.com/Aider-AI/aider)) in a disposable Docker container, with a toolchain of your choice and your host login reused read-only when available.

## Why

- Isolate the agent from the host filesystem — only the target directory is mounted.
- Pick a language toolchain per session (Elixir, Rust, …) without polluting the host.
- Reuse your existing host login read-only when available, or spin up a throwaway container and log in fresh.
- Opinionated defaults: agents run in their most permissive "yolo" mode, inside a rootless image, and as the host user so files the agent writes stay host-owned.

## Requirements

- Docker or rootless Podman (with a `docker` compatibility symlink)
- Bash

## Usage

```
./run_agent.sh [-a agent] [-d directory] [-r] [-t toolchain]
```

| Flag | Description | Default |
| --- | --- | --- |
| `-a` | Agent (see below) | `claude` |
| `-d` | Directory the agent should work in | current directory |
| `-r` | Mount the target directory read-only | off |
| `-t` | Toolchain (see below) | `base` |

`./run_claude.sh` is kept as a thin wrapper that forwards to `run_agent.sh -a claude`.

### Agents

| Agent | CLI package | CMD | Host config reused |
| --- | --- | --- | --- |
| `claude` | `@anthropic-ai/claude-code` | `claude --dangerously-skip-permissions` | `~/.claude/` + `~/.claude.json` |
| `codex` | `@openai/codex` | `codex --dangerously-bypass-approvals-and-sandbox` | `~/.codex/`, `$OPENAI_API_KEY` |
| `gemini` | `@google/gemini-cli` | `gemini --yolo` | `~/.gemini/`, `$GEMINI_API_KEY`, `$GOOGLE_API_KEY` |
| `aider` | `aider-chat` (pip) | `aider --yes-always` | `~/.aider.conf.yml`, `$OPENAI_API_KEY` / `$ANTHROPIC_API_KEY` / … |

Each agent is a pair of files:

- `dockerfiles/agents/<name>.Dockerfile` — builds a uid-1000 `node` user at `/home/node`, installs the CLI, sets `CMD`.
- `agents/<name>.sh` — shell plugin that defines `agent_prepare_mounts` / `agent_cleanup`, populating `AGENT_DOCKER_ARGS` with the mounts and `-e` env vars the agent needs.

### Login handling

Each agent's plugin decides what counts as "login":

- **Claude** — a throwaway `~/.claude` is assembled in a temp dir and mounted writable at `/home/node/.claude`. Only `.credentials.json`, `settings.json`, and `plugins/` are copied in; session-scratch subdirectories (`sessions`, `todos`, …) are created empty. `~/.claude.json` is copied to a temp file and mounted writable at `/home/node/.claude.json`. Both temp paths are removed on exit.
- **Codex** — `~/.codex/` is copied to a temp dir and mounted writable at `/home/node/.codex`. `$OPENAI_API_KEY` is forwarded if set.
- **Gemini** — `~/.gemini/` is copied to a temp dir and mounted writable at `/home/node/.gemini`. `$GEMINI_API_KEY` / `$GOOGLE_API_KEY` are forwarded if set.
- **Aider** — `~/.aider.conf.yml` is mounted read-only if present. Provider API keys (`$OPENAI_API_KEY`, `$ANTHROPIC_API_KEY`, `$DEEPSEEK_API_KEY`, `$OPENROUTER_API_KEY`, `$GEMINI_API_KEY`, `$GROQ_API_KEY`, `$MISTRAL_API_KEY`, `$COHERE_API_KEY`) are forwarded if set.

If nothing is found on the host the container is fully throwaway — log in or export keys inside it, and state vanishes on exit.

### Examples

```sh
# Claude Code in the current directory (base image)
./run_agent.sh

# Codex CLI in ~/projects/myapp with the Rust toolchain
./run_agent.sh -a codex -d ~/projects/myapp -t rust

# Aider read-only, against the current directory
./run_agent.sh -a aider -r

# Back-compat wrapper
./run_claude.sh -t node
```

## Toolchains

Each toolchain is a Dockerfile in `dockerfiles/toolchains/` that builds on top of the selected agent base via `--build-arg BASE_IMAGE=agent-runner-<agent>`. The agent base is built automatically on every run; toolchain images are built on demand.

| Toolchain | Adds |
| --- | --- |
| `base` | just the agent base (no extra toolchain) |
| `elixir` | Erlang/OTP, Elixir, hex, rebar |
| `rust` | Rust (stable, minimal) + common native build deps (OpenSSL, ALSA, udev, Wayland, X11) |
| `java` | Eclipse Temurin JDK 24 + Maven 3.9.9 |
| `node` | Node 20 (prepended to `PATH`, overrides the base Node 22) |

### Adding a toolchain

Drop `<name>.Dockerfile` into `dockerfiles/toolchains/`, starting with:

```dockerfile
ARG BASE_IMAGE
FROM ${BASE_IMAGE}
```

and run with `-t <name>`. It will show up in `-h` automatically. Any toolchain must keep the `node` uid-1000 user intact so bind mounts stay host-owned.

### Adding an agent

1. Add `dockerfiles/agents/<name>.Dockerfile`. It must create a uid-1000 `node` user at `/home/node`, install the CLI, and set `CMD` to the agent's "run autonomously" entrypoint. `aider.Dockerfile` is the template for non-Node bases.
2. Add `agents/<name>.sh`. It must set `AGENT_CONTAINER_HOME` and define `agent_prepare_mounts` (appending to `AGENT_DOCKER_ARGS`) and `agent_cleanup`.

Both files are discovered by name, so the new agent shows up in `-h` and is usable as `-a <name>`.

## Layout

```
run_agent.sh                  # entrypoint
run_claude.sh                 # back-compat wrapper: exec run_agent.sh -a claude
check_sensitive.sh
agents/
  claude.sh                   # credential + mount logic per agent
  codex.sh
  gemini.sh
  aider.sh
dockerfiles/
  agents/
    claude.Dockerfile         # agent base images
    codex.Dockerfile
    gemini.Dockerfile
    aider.Dockerfile
  toolchains/
    elixir.Dockerfile         # language layers; FROM ${BASE_IMAGE}
    java.Dockerfile
    node.Dockerfile
    rust.Dockerfile
```
