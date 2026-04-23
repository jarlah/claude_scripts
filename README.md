# claude_scripts

Run [Claude Code](https://github.com/anthropics/claude-code) in a disposable Docker container, with a toolchain of your choice and your host login reused read-only when available.

## Why

- Isolate Claude Code from the host filesystem — only the target directory is mounted.
- Pick a language toolchain per session (Elixir, Rust, …) without polluting the host.
- Reuse your existing host login read-only when available, or spin up a throwaway container and log in fresh.
- Opinionated defaults: Claude runs with `--dangerously-skip-permissions` (yolo), inside a rootless image, and as the host user so files Claude writes stay host-owned.

## Requirements

- Docker
- Bash

## Usage

```
./run_claude.sh [-d directory] [-r] [-t toolchain]
```

| Flag | Description | Default |
| --- | --- | --- |
| `-d` | Directory Claude should work in | current directory |
| `-r` | Mount the target directory read-only | off |
| `-t` | Toolchain (see below) | `base` |

### Login handling

On start the script looks for `~/.claude/.credentials.json` on the host:

- **Found** → a throwaway `~/.claude` is assembled in a temp dir and mounted writable at `/root/.claude`. Only a selective set of host files is copied in: `.credentials.json`, `settings.json`, and `plugins/`. Session-scratch subdirectories (`sessions`, `todos`, `shell-snapshots`, `file-history`, `projects`, etc.) are created empty. If `~/.claude.json` exists it is copied to a temp file and mounted writable at `/root/.claude.json`. The container can write freely; nothing is written back to the host, and both temp paths are removed on exit.
- **Not found** → no config is mounted. The container is fully throwaway: log in interactively, and the credentials vanish when the container exits.

### Examples

```sh
# Run in the current directory with the base image
./run_claude.sh

# Run in ~/projects/myapp with the Rust toolchain
./run_claude.sh -d ~/projects/myapp -t rust

# Read-only working directory
./run_claude.sh -r
```

## Toolchains

Each toolchain is a Dockerfile in `dockerfiles/` that builds on top of `claude-code-base`. The base image is built automatically on every run; toolchain images are built on demand.

| Toolchain | Adds |
| --- | --- |
| `base` | Node 22, git, `@anthropic-ai/claude-code` |
| `elixir` | Erlang/OTP, Elixir, hex, rebar |
| `rust` | Rust (stable, minimal) + common native build deps (OpenSSL, ALSA, udev, Wayland, X11) |
| `java` | Eclipse Temurin JDK 24 + Maven 3.9.9 |

### Adding a toolchain

Drop `<name>.Dockerfile` into `dockerfiles/`, starting from `FROM claude-code-base`, and run with `-t <name>`. It will show up in `-h` automatically.

## Layout

```
run_claude.sh            # entrypoint
dockerfiles/
  base.Dockerfile        # Node + Claude Code CLI
  elixir.Dockerfile
  rust.Dockerfile
  java.Dockerfile
```
