#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

usage() {
  echo "Usage: $0 [--skip-git-pull] [--skip-build] [--services s1,s2,...]"
  exit 1
}

SKIP_GIT_PULL=false
SKIP_BUILD=false
SERVICES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-git-pull) SKIP_GIT_PULL=true; shift ;;
    --skip-build)    SKIP_BUILD=true; shift ;;
    --services)      SERVICES="$2"; shift 2 ;;
    -h|--help)       usage ;;
    *)               echo "Unknown option: $1"; usage ;;
  esac
done

echo "=== Deploying hubs-compose ==="

if [ "$SKIP_GIT_PULL" = false ]; then
  echo "--- Pulling latest code ---"
  git fetch origin
  git checkout main
  git pull origin main

  for sub in services/reticulum services/spoke services/hubs services/dialog; do
    if [ -d "$sub/.git" ]; then
      echo "Pulling $sub..."
      git -C "$sub" pull origin master 2>/dev/null || true
    fi
  done
fi

if [ "$SKIP_BUILD" = false ]; then
  echo "--- Building Docker images ---"
  if [ -n "$SERVICES" ]; then
    IFS=',' read -ra SVC_ARRAY <<< "$SERVICES"
    for svc in "${SVC_ARRAY[@]}"; do
      docker compose build "$svc"
    done
  else
    docker compose build --parallel
  fi
fi

echo "--- Starting services ---"
if [ -n "$SERVICES" ]; then
  IFS=',' read -ra SVC_ARRAY <<< "$SERVICES"
  docker compose up -d --force-recreate "${SVC_ARRAY[@]}"
else
  docker compose up -d --force-recreate
fi

echo "--- Waiting for services to become healthy ---"
sleep 15
docker compose ps --format "table {{.Name}}\t{{.Status}}"

UNHEALTHY=$(docker compose ps --format "{{.Name}}\t{{.Status}}" | grep -i unhealthy || true)
if [ -n "$UNHEALTHY" ]; then
  echo "⚠️  Unhealthy services:"
  echo "$UNHEALTHY"
  exit 1
fi

echo "=== ✅ Deploy complete ==="
