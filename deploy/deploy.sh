#!/usr/bin/env bash
# Выкладка закоммиченного HEAD на сервер: ./deploy/deploy.sh <ip>
# Код передаётся архивом (git archive), на сервере пересобирается и перезапускается.
set -euo pipefail
HOST="${1:?usage: deploy.sh <ip>}"
KEY="${PUT_SSH_KEY:-$HOME/.ssh/id_ed25519_put_deploy}"
SSH=(ssh -i "$KEY" -o StrictHostKeyChecking=accept-new "deploy@$HOST")
cd "$(git rev-parse --show-toplevel)"
echo "Выкладываю $(git rev-parse --short HEAD) на $HOST"
git archive --format=tar HEAD backend deploy | gzip | "${SSH[@]}" \
  "rm -rf /opt/put/src.new && mkdir -p /opt/put/src.new && tar -xz -C /opt/put/src.new \
   && rm -rf /opt/put/src && mv /opt/put/src.new /opt/put/src"
"${SSH[@]}" "cd /opt/put/src && docker compose --env-file /opt/put/.env -f deploy/compose.prod.yaml up -d --build \
  && docker image prune -f >/dev/null && docker compose --env-file /opt/put/.env -f deploy/compose.prod.yaml ps"
