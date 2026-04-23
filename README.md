# claude_scripts

Run [Claude Code](https://github.com/anthropics/claude-code) in a disposable Docker container, with a toolchain of your choice and your host login reused read-only when available.

## Why

- Isolate Claude Code from the host filesystem — only the target directory is mounted.
- Pick a language toolchain per session (Elixir, Rust, …) without polluting the host.
- Reuse your existing host login read-only when available, or spin up a throwaway container and log in fresh.

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

- **Found** → `~/.claude` is mounted read-only so the existing login is reused without risk of the container writing back to it. If `~/.claude.json` exists it is copied to a temp file and mounted writable, so the container can update it freely without touching the host copy (the temp file is removed on exit).
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

### Adding a toolchain

Drop `<name>.Dockerfile` into `dockerfiles/`, starting from `FROM claude-code-base`, and run with `-t <name>`. It will show up in `-h` automatically.

## Layout

```
run_claude.sh            # entrypoint
dockerfiles/
  base.Dockerfile        # Node + Claude Code CLI
  elixir.Dockerfile
  rust.Dockerfile
```
