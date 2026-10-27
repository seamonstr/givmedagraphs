#!/bin/bash
set -euo pipefail

# Runs locally to deploy the stack to a Raspberry Pi:
#   1. build/push all images into a local registry (build-to-registry.sh)
#   2. copy the app-stack files the Pi needs onto it
#   3. run startup.sh on the Pi in deploy mode, pointing it at our registry
#
# Assumes "ssh <pi>" works non-interactively (user and keys set up in ~/.ssh/config).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
APP_DIR="$REPO_ROOT/app-stack"

# Where the stack lives on the Pi (relative to the ssh login directory). It must be
# persistent because the systemd unit runs startup.sh from here.
REMOTE_DIR="givmedagraphs"

# Files/directories from app-stack/ that the Pi needs.
DEPLOY_FILES=(grafana nginx .env docker-compose.yml startup.sh)

usage() {
    cat <<EOF
Usage: $(basename "$0") <pi-host>

  <pi-host>   Hostname or IP of the Pi, e.g. mypi.local. Must be reachable with
              plain "ssh <pi-host>".
EOF
}

PI=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Error: unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
        *)
            if [[ -n "$PI" ]]; then
                echo "Error: unexpected extra argument: $1" >&2
                usage >&2
                exit 1
            fi
            PI="$1"
            shift
            ;;
    esac
done

if [[ -z "$PI" ]]; then
    echo "Error: pi hostname/IP is required" >&2
    usage >&2
    exit 1
fi

for f in "${DEPLOY_FILES[@]}"; do
    if [[ ! -e "$APP_DIR/$f" ]]; then
        echo "Error: $APP_DIR/$f does not exist" >&2
        exit 1
    fi
done

# ---- 1. Work out how the Pi can reach this machine ----
# SSH_CONNECTION on the Pi is "<client ip> <client port> <server ip> <server port>", so
# the first field is this machine's address as the Pi sees it.
echo "🔎 Checking connection to $PI..."
BUILD_HOST="$(ssh "$PI" 'echo "${SSH_CONNECTION%% *}"')"
if [[ -z "$BUILD_HOST" ]]; then
    echo "Error: could not determine this machine's address as seen from $PI" >&2
    exit 1
fi
echo "   $PI sees this machine as $BUILD_HOST"

# ---- 2. Build everything into the registry ----
BUILD_LOG="$(mktemp)"
trap 'rm -f "$BUILD_LOG"' EXIT

echo "🏗️ Building images into the registry..."
"$SCRIPT_DIR/build-to-registry.sh" --platform pi --advertise-host "$BUILD_HOST" | tee "$BUILD_LOG"

REGISTRY_URL="$(grep '^REGISTRY_URL=' "$BUILD_LOG" | tail -n1 | cut -d= -f2-)"
if [[ -z "$REGISTRY_URL" ]]; then
    echo "Error: build-to-registry.sh did not report a REGISTRY_URL" >&2
    exit 1
fi
echo "📦 Registry: $REGISTRY_URL"

# ---- 3. Copy the app-stack files to the Pi ----
echo "📤 Copying app-stack files to $PI:$REMOTE_DIR ..."
# tar over ssh keeps the executable bit and lets us replace grafana/ cleanly (removing
# files that no longer exist) instead of nesting a copy inside the old directory.
ssh "$PI" "mkdir -p '$REMOTE_DIR' && rm -rf '$REMOTE_DIR/grafana' '$REMOTE_DIR/nginx'"
tar -C "$APP_DIR" -cf - "${DEPLOY_FILES[@]}" | ssh "$PI" "tar -C '$REMOTE_DIR' -xf -"
ssh "$PI" "chmod 600 '$REMOTE_DIR/.env' && chmod +x '$REMOTE_DIR/startup.sh'"

# ---- 4. Run startup.sh in deploy mode on the Pi ----
echo "🚀 Running startup.sh --deploy on $PI..."
printf -v REMOTE_CMD 'cd %q && ./startup.sh --deploy --registry %q' "$REMOTE_DIR" "$REGISTRY_URL"
# -t so sudo can prompt for a password on the Pi if it needs to.
ssh -t "$PI" "$REMOTE_CMD"

echo "✅ Deployed to $PI."
