#!/bin/bash
set -euo pipefail

# Runs locally to:
#   1. start a docker registry on an ephemeral host port (reusing it if already running)
#   2. copy the latest grafana and influxdb images from the public registry into it
#   3. build the collector image and push it to it, tagged "latest"
#
# The registry container is left running afterwards so a target machine can pull from it,
# e.g.:  ./startup.sh --deploy --registry http://<this-host>:<port>

REGISTRY_NAME="givmedagraphs-registry"
REGISTRY_IMAGE="docker.io/library/registry:2"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
COLLECTOR_DIR="$REPO_ROOT/app-stack/collector"

# Public images to mirror: "<source image>|<path inside our registry>"
MIRRORED_IMAGES=(
    "docker.io/library/influxdb:latest|library/influxdb:latest"
    "docker.io/grafana/grafana-oss:latest|grafana/grafana-oss:latest"
)
COLLECTOR_IMAGE_PATH="givmedagraphs/collector:latest"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --platform <plat>   Target platform for pulled/built images, e.g. linux/arm64.
                      The alias "pi" means linux/arm64 (64-bit Raspberry Pi OS).
                      Default: the platform of this machine.
  --advertise-host <host>
                      Hostname/IP that other machines should use to reach the registry.
                      Only affects the printed REGISTRY_URL; this script itself always
                      talks to the registry via localhost. Default: localhost.
  -h, --help          Show this help.

On success the last line of output is: REGISTRY_URL=http://<advertise-host>:<port>
EOF
}

PLATFORM=""
ADVERTISE_HOST="localhost"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --platform)
            if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
                echo "Error: --platform requires an argument" >&2
                usage >&2
                exit 1
            fi
            PLATFORM="$2"
            shift 2
            ;;
        --platform=*)
            PLATFORM="${1#--platform=}"
            if [[ -z "$PLATFORM" ]]; then
                echo "Error: --platform requires an argument" >&2
                usage >&2
                exit 1
            fi
            shift
            ;;
        --advertise-host)
            if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
                echo "Error: --advertise-host requires an argument" >&2
                usage >&2
                exit 1
            fi
            ADVERTISE_HOST="$2"
            shift 2
            ;;
        --advertise-host=*)
            ADVERTISE_HOST="${1#--advertise-host=}"
            if [[ -z "$ADVERTISE_HOST" ]]; then
                echo "Error: --advertise-host requires an argument" >&2
                usage >&2
                exit 1
            fi
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Resolve platform aliases to the official Docker/OCI platform name.
case "$PLATFORM" in
    pi) PLATFORM="linux/arm64" ;;
esac

PLATFORM_ARGS=()
if [[ -n "$PLATFORM" ]]; then
    PLATFORM_ARGS=(--platform "$PLATFORM")
fi

# ---- 1. Start the registry ----
registry_port() {
    docker port "$REGISTRY_NAME" 5000/tcp | head -n1 | sed 's/.*://'
}

if [[ "$(docker inspect -f '{{.State.Running}}' "$REGISTRY_NAME" 2>/dev/null || true)" == "true" ]]; then
    echo "♻️ Registry $REGISTRY_NAME is already running."
else
    # Remove any stopped leftover so the name is free.
    docker rm -f "$REGISTRY_NAME" > /dev/null 2>&1 || true
    echo "🗄️ Starting registry $REGISTRY_NAME on an ephemeral port..."
    # Publishing only the container port makes docker pick a free host port.
    docker run -d --name "$REGISTRY_NAME" -p 5000 "$REGISTRY_IMAGE" > /dev/null
fi

PORT="$(registry_port)"
if [[ -z "$PORT" ]]; then
    echo "Error: could not determine the registry's host port" >&2
    exit 1
fi
# docker treats localhost registries as insecure by default, so plain http works here.
REGISTRY="localhost:$PORT"

echo "⏳ Waiting for registry at http://$REGISTRY ..."
for _ in $(seq 1 30); do
    if curl -fsS "http://$REGISTRY/v2/" > /dev/null 2>&1; then
        break
    fi
    sleep 1
done
if ! curl -fsS "http://$REGISTRY/v2/" > /dev/null 2>&1; then
    echo "Error: registry did not become ready" >&2
    exit 1
fi

# ---- 2. Mirror public images ----
for entry in "${MIRRORED_IMAGES[@]}"; do
    SRC="${entry%%|*}"
    DEST="$REGISTRY/${entry##*|}"

    echo "⬇️ Pulling $SRC..."
    docker pull "${PLATFORM_ARGS[@]}" "$SRC"
    docker tag "$SRC" "$DEST"
    echo "⬆️ Pushing $DEST..."
    docker push "$DEST"
done

# ---- 3. Build and push the collector ----
COLLECTOR_DEST="$REGISTRY/$COLLECTOR_IMAGE_PATH"
echo "🔨 Building collector image $COLLECTOR_DEST..."
docker build "${PLATFORM_ARGS[@]}" \
    -f "$COLLECTOR_DIR/Containerfile" \
    -t "$COLLECTOR_DEST" \
    "$COLLECTOR_DIR"
echo "⬆️ Pushing $COLLECTOR_DEST..."
docker push "$COLLECTOR_DEST"

echo "✅ Done. Registry is running locally at http://$REGISTRY."
# Machine-readable result; callers parse this line.
echo "REGISTRY_URL=http://$ADVERTISE_HOST:$PORT"
