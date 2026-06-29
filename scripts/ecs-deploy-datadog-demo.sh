#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/FanXuuuuuu/opentelemetry-demo.git}"
APP_DIR="${APP_DIR:-/opt/opentelemetry-demo}"
DD_SITE="${DD_SITE:-us5.datadoghq.com}"

if [[ -z "${DD_API_KEY:-}" ]]; then
  if [[ -f /etc/datadog-agent/datadog.yaml ]]; then
    DD_API_KEY="$(sed -n 's/^api_key:[[:space:]]*//p' /etc/datadog-agent/datadog.yaml | tail -n1)"
  fi
  if [[ -z "${DD_API_KEY:-}" ]]; then
    echo "DD_API_KEY is required. Example:" >&2
    echo "  DD_API_KEY=... bash scripts/ecs-deploy-datadog-demo.sh" >&2
    exit 2
  fi
fi

echo "== Host =="
hostname
whoami
free -h || true

echo "== Docker =="
docker --version
docker compose version

echo "== Stop old demo containers if present =="
docker ps --format '{{.Names}}' | grep -E '^(demo-spring-app|fx-python|otel-collector|frontend-proxy|frontend|ad|cart|checkout|currency|email|image-provider|load-generator|payment|product-catalog|quote|recommendation|shipping|flagd|flagd-ui|telemetry-docs|astronomy-db|valkey-cart)$' || true
if [[ -d "$APP_DIR" ]]; then
  cd "$APP_DIR"
  docker compose --env-file .env --env-file .env.datadog -f compose.yaml -f compose.extras.yaml down --remove-orphans || true
fi

echo "== Clone or update fork =="
mkdir -p "$(dirname "$APP_DIR")"
if [[ -d "$APP_DIR/.git" ]]; then
  cd "$APP_DIR"
  git fetch origin main
  git checkout main
  git reset --hard origin/main
else
  rm -rf "$APP_DIR"
  git clone "$REPO_URL" "$APP_DIR"
  cd "$APP_DIR"
fi

echo "== Write Datadog env file =="
cat > .env.datadog <<EOF
DD_API_KEY=$DD_API_KEY
DD_SITE=$DD_SITE
EOF
chmod 600 .env.datadog

echo "== Validate compose =="
docker compose --env-file .env --env-file .env.datadog -f compose.yaml -f compose.extras.yaml config >/tmp/opentelemetry-demo-compose.rendered.yml

echo "== Start OpenTelemetry demo with Datadog =="
docker compose --env-file .env --env-file .env.datadog -f compose.yaml -f compose.extras.yaml up -d

echo "== Status =="
docker compose --env-file .env --env-file .env.datadog -f compose.yaml -f compose.extras.yaml ps

echo "== Basic checks =="
sleep 20
curl -fsS http://localhost:8080 >/dev/null && echo "frontend ok"
docker logs --tail=80 otel-collector || true
datadog-agent status 2>/dev/null | head -160 || docker exec datadog-agent agent status || true

echo "Done. Open http://8.141.2.50:8080 and verify Datadog env:demo data."
