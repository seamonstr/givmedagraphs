#!/bin/bash
set -e

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --deploy              Pull latest images, install the systemd unit and start it.
  --registry <url>      Registry holding ALL of the stack's images, e.g.
                        http://192.168.1.10:5000 or registry.example.com. Required with
                        --deploy (and only valid with it). The registry is recorded in
                        .env as REGISTRY. A plain http:// URL is supported; the registry
                        is then added to docker's "insecure-registries".
  -h, --help            Show this help.
EOF
}

# ---- Argument parsing ----
DEPLOY=false
REGISTRY_URL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --deploy)
            DEPLOY=true
            shift
            ;;
        --registry)
            if [[ $# -lt 2 || -z "$2" || "$2" == -* ]]; then
                echo "Error: --registry requires a URL argument" >&2
                usage >&2
                exit 1
            fi
            REGISTRY_URL="$2"
            shift 2
            ;;
        --registry=*)
            REGISTRY_URL="${1#--registry=}"
            if [[ -z "$REGISTRY_URL" ]]; then
                echo "Error: --registry requires a URL argument" >&2
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

if [[ -n "$REGISTRY_URL" && "$DEPLOY" != true ]]; then
    echo "Error: --registry can only be used together with --deploy" >&2
    usage >&2
    exit 1
fi

if [[ "$DEPLOY" == true && -z "$REGISTRY_URL" ]]; then
    echo "Error: --deploy requires --registry" >&2
    usage >&2
    exit 1
fi

# docker compose reads .env from the project directory, so always run from here.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"
cd "$SCRIPT_DIR"

if [[ "$DEPLOY" == true ]]; then
    # If we are in "deploy" mode then we get the latest images, install (or reinstall) the 
    # systemd unit and start it.

    # Split the registry URL into scheme and host[:port]. A bare "host[:port]" is
    # treated as https.
    case "$REGISTRY_URL" in
        http://*)  REGISTRY_INSECURE=true;  REGISTRY_HOST="${REGISTRY_URL#http://}" ;;
        https://*) REGISTRY_INSECURE=false; REGISTRY_HOST="${REGISTRY_URL#https://}" ;;
        *://*)
            echo "Error: unsupported registry URL scheme: $REGISTRY_URL" >&2
            exit 1
            ;;
        *)         REGISTRY_INSECURE=false; REGISTRY_HOST="$REGISTRY_URL" ;;
    esac
    REGISTRY_HOST="${REGISTRY_HOST%/}"
    if [[ -z "$REGISTRY_HOST" || "$REGISTRY_HOST" == */* ]]; then
        echo "Error: registry URL must be of the form [http[s]://]host[:port] (got: $REGISTRY_URL)" >&2
        exit 1
    fi

    # Let docker use the registry over plain http by adding it to "insecure-registries"
    # in daemon.json. Docker is only restarted if the config changed.
    if [[ "$REGISTRY_INSECURE" == true ]]; then
        DAEMON_JSON="/etc/docker/daemon.json"
        echo "🔓 Allowing insecure (http) access to registry $REGISTRY_HOST..."
        rc=0
        NEW_JSON="$(sudo python3 - "$DAEMON_JSON" "$REGISTRY_HOST" <<'PY'
import json, os, sys
path, host = sys.argv[1], sys.argv[2]
cfg = {}
if os.path.exists(path) and os.path.getsize(path) > 0:
    with open(path) as f:
        cfg = json.load(f)
regs = cfg.setdefault("insecure-registries", [])
if host in regs:
    sys.exit(3)
regs.append(host)
print(json.dumps(cfg, indent=2))
PY
)" || rc=$?

        if [[ $rc -eq 3 ]]; then
            echo "   Already configured."
        elif [[ $rc -ne 0 ]]; then
            echo "Error: failed to update $DAEMON_JSON" >&2
            exit 1
        else
            sudo mkdir -p "$(dirname "$DAEMON_JSON")"
            echo "$NEW_JSON" | sudo tee "$DAEMON_JSON" > /dev/null
            echo "🔄 Restarting docker to apply registry configuration..."
            sudo systemctl restart docker
        fi
    fi

    # Record the registry in .env. docker-compose.yml uses it as the prefix for every
    # image, and the systemd unit's later runs pick it up from the same file.
    ENV_FILE="$SCRIPT_DIR/.env"
    touch "$ENV_FILE"
    sed -i '/^REGISTRY=/d' "$ENV_FILE"
    if [[ -s "$ENV_FILE" && -n "$(tail -c1 "$ENV_FILE")" ]]; then
        echo >> "$ENV_FILE"
    fi
    echo "REGISTRY=$REGISTRY_HOST" >> "$ENV_FILE"

    echo "🗑️ Removing old containers..."
    docker compose down --remove-orphans

    echo "⬇️ Pulling latest images from $REGISTRY_HOST..."
    docker compose pull

    UNIT_NAME="givmedagraphs.service"
    UNIT_PATH="/etc/systemd/system/$UNIT_NAME"
    RUN_USER="$(id -un)"

    echo "🛠️ Installing systemd unit $UNIT_NAME (user: $RUN_USER)..."
    sudo tee "$UNIT_PATH" > /dev/null <<EOF
[Unit]
Description=givmedagraphs app stack
Wants=network-online.target
After=network-online.target docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=$RUN_USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_PATH
ExecStop=/usr/bin/env docker compose down

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable "$UNIT_NAME"
    echo "🚀 Starting $UNIT_NAME..."
    sudo systemctl restart "$UNIT_NAME"
else
    # Not in deploy mode means just start the services
    echo "✂️ Removing old containers..."
    docker compose down --remove-orphans

    echo "🚀 Starting services..."
    docker compose up -d
fi



