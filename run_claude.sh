#!/bin/bash
# Back-compat wrapper: forwards to run_agent.sh with -a claude.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/run_agent.sh" -a claude "$@"
