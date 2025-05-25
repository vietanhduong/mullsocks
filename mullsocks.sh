#!/usr/bin/env bash

set -euo pipefail

script_name="$(basename "${BASH_SOURCE[0]}")"

MULLSOCKS_VERSION="v0.1.0"

MULLSOCKS_IMAGE=${MULLSOCKS_IMAGE:-"ghcr.io/vietanhduong/mullsocks:$MULLSOCKS_VERSION"}
MULLSOCKS_PROXY_IMAGE=${MULLSOCKS_PROXY_IMAGE:-"ghcr.io/vietanhduong/mullsocks-proxy:$MULLSOCKS_VERSION"}

ACCOUNT=${MULLVAD_ACCOUNT:-""}
PORT=${MULLVAD_PORT:-1080}
LOCATION=${MULLVAD_LOCATION:-"hk"}
CONFIG_DIR=${MULLVAD_CONFIG_DIR:-"$HOME/.mullsocks"}
CONTAINER_NAME="mullsocks"
PROXY_CONTAINER_NAME="mullsocks-proxy"
NETWORK_NAME="mullsocks_network"

function usage() {
  echo "Usage: $script_name [FLAGS]"
  echo "Deploy and manage a Mullvad SOCKS5 proxy container."
  echo ""
  echo "Examples:"
  echo "  # Quick start with default settings"
  echo "  $ $script_name --account <your_account_number>"
  echo ""
  echo "  # Change server location"
  echo "  $ $script_name --account <your_account_number> --location sg"
  echo ""
  echo "  # Change port"
  echo "  $ $script_name --account <your_account_number> --port 1081"
  echo ""
  echo "  # Stop the mullsocks container"
  echo "  $ $script_name --stop"
  echo ""
  echo "Flags:"
  echo "  -h, --help              Show this help message"
  echo "      --config-dir        Directory for mullsocks configuration (default: '$CONFIG_DIR')"
  echo "      --stop              Stop the mullsocks container"
  echo "  -a, --account           Mullvad account number"
  echo "  -p, --port              Port to use for the SOCKS5 proxy (default: $PORT)"
  echo "  -l, --location          Mullvad server location. Use quotes for multiple words (e.g., 'hk hkg') (default: '$LOCATION')"
}

function parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --stop)
      docker stop "$CONTAINER_NAME" "$PROXY_CONTAINER_NAME" 2>/dev/null || true
      docker network rm "$NETWORK_NAME" 2>/dev/null || true
      exit 0
      ;;
    --container)
      CONTAINER_NAME="$2"
      shift 2
      ;;
    --config-dir)
      CONFIG_DIR="$2"
      shift 2
      ;;
    -a | --account)
      ACCOUNT="$2"
      shift 2
      ;;
    -p | --port)
      PORT="$2"
      shift 2
      ;;
    -l | --location)
      LOCATION="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
    esac
  done
}

parse_args "$@"

function ensure_containers() {
  # Ensure the network for the containers exists
  if ! docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
    docker network create "$NETWORK_NAME" || {
      echo "Failed to create Docker network '$NETWORK_NAME'. Please check your Docker setup." >&2
      exit 1
    }
  fi

  # Ensure the main container is running
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container '$CONTAINER_NAME' not found. Starting it..."
    docker run -d --cgroupns host \
      --cap-add NET_ADMIN \
      --cap-add SYS_MODULE \
      --sysctl net.ipv4.conf.all.src_valid_mark=1 \
      --privileged \
      --network "$NETWORK_NAME" \
      --network-alias "$CONTAINER_NAME" \
      --volume "$CONFIG_DIR":/etc/mullvad \
      --name "$CONTAINER_NAME" --rm "$MULLSOCKS_IMAGE" || {
      echo "Failed to start the $CONTAINER_NAME container. Please check your Docker setup." >&2
      exit 1
    }
  fi

  # Ensure the proxy container is running
  if ! docker ps --format '{{.Names}}' | grep -q "^${PROXY_CONTAINER_NAME}$"; then
    echo "Container '$PROXY_CONTAINER_NAME' not found. Starting it..."
    docker run -d \
      --network "$NETWORK_NAME" \
      --network-alias "$PROXY_CONTAINER_NAME" \
      --name "$PROXY_CONTAINER_NAME" --rm \
      -p "$PORT":1080 \
      "$MULLSOCKS_PROXY_IMAGE" || {
      echo "Failed to start the $PROXY_CONTAINER_NAME container. Please check your Docker setup." >&2
      exit 1
    }
  fi
}

function get_account_from_container() {
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Container '$CONTAINER_NAME' not found." >&2
    return 1
  fi

  docker exec -it "$CONTAINER_NAME" bash -c "mullvad account get" | grep 'account' | grep -Po '(\d+)' || {
    echo "No account number found." >&2
    return 1
  }
}

# If the args is empty, we will try to read it from the container (if it exists)
if [ -z "$ACCOUNT" ]; then
  ACCOUNT=$(get_account_from_container || {
    echo "No account number provided. Please provide it using the -a or --account flag." >&2
    exit 1
  })
fi

# Ensure the docker container is running
ensure_containers || {
  echo "Failed to ensure the containers are running. Please check your Docker setup." >&2
  exit 1
}

# Wait until the container is fully up
until docker exec "$CONTAINER_NAME" bash -c "mullvad status" >/dev/null 2>&1; do
  echo "Waiting for the mullsocks container to be ready..."
  sleep 1
done

CURRENT_ACCOUNT=$(get_account_from_container || echo "")
echo "Using account: $ACCOUNT"

# IF the current account in the container is different from the one provided, we will update it
if [ "$ACCOUNT" != "$CURRENT_ACCOUNT" ]; then
  echo "Setting account to $ACCOUNT"
  docker exec -it "$CONTAINER_NAME" bash -c "mullvad account login $ACCOUNT" || {
    echo "Failed to set the account in the container. Please check your account number." >&2
    exit 1
  }

  docker exec -it "$CONTAINER_NAME" bash -c "mullvad relay set tunnel-protocol wireguard"
  docker exec -it "$CONTAINER_NAME" bash -c "mullvad lockdown-mode set on"
  docker exec -it "$CONTAINER_NAME" bash -c "mullvad lan set allow"
  docker exec -it "$CONTAINER_NAME" bash -c "mullvad auto-connect set on"
  docker exec -it "$CONTAINER_NAME" bash -c "mullvad tunnel set wireguard rotate-key"
fi

# Set the location
docker exec -it "$CONTAINER_NAME" bash -c "mullvad relay set location $LOCATION" || {
  echo "Failed to set the location in the container. Please check your location." >&2
  exit 1
}

docker exec -it "$CONTAINER_NAME" bash -c "mullvad reconnect --wait" || {
  echo "Failed to connect to the Mullvad server. Please check your connection." >&2
  exit 1
}

echo "Mullsocks is now running with the following configuration:"
echo "  Account: $ACCOUNT"
echo "  Location: $LOCATION"
echo "  Port: $PORT"
echo "You can now use the SOCKS5 proxy at 'socks5://localhost:$PORT'."
