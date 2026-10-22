#!/bin/bash
set -euo pipefail

# Runs the whole stack on this machine:
#   1. build-to-registry.sh starts a local registry and fills it with all of the images
#   2. startup.sh starts the stack, pulling every image from that registry
#
# The registry address is passed to docker-compose through the REGISTRY environment
# variable (docker-compose.yml uses it as the image prefix), so app-stack/.env is not
# modified.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
APP_DIR="$REPO_ROOT/app-stack"

usage() {
    cat <<EOF
Usage: $(basename "$0")

Builds all images into a local registry, then starts the app stack from it.
Accessible afterwards at:
  InfluxDB: http://localhost:8086
  Grafana:  http://localhost:3000
EOF
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        echo "Error: unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
esac

# ---- 1. Build everything into the registry ----
BUILD_LOG="$(mktemp)"
trap 'rm -f "$BUILD_LOG"' EXIT

echo "🏗️ Building images into the local registry..."
"$SCRIPT_DIR/build-to-registry.sh" | tee "$BUILD_LOG"

REGISTRY_URL="$(grep '^REGISTRY_URL=' "$BUILD_LOG" | tail -n1 | cut -d= -f2-)"
if [[ -z "$REGISTRY_URL" ]]; then
    echo "Error: build-to-registry.sh did not report a REGISTRY_URL" >&2
    exit 1
fi
# docker-compose.yml wants host[:port] without a scheme.
REGISTRY="${REGISTRY_URL#http://}"
echo "📦 Registry: $REGISTRY"

# ---- 2. Start the stack ----
echo "▶️ Starting the app stack..."
export REGISTRY
cd "$APP_DIR"
./startup.sh

echo "✅ Stack is up:"
echo "   InfluxDB: http://localhost:8086"
echo "   Grafana:  http://localhost:3000"
