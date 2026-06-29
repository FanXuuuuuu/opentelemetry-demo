#!/usr/bin/env bash
set -euo pipefail

DD_SITE="${DD_SITE:-us5.datadoghq.com}"
CONFIG_DIR="/etc/datadog-agent"
DATADOG_YAML="$CONFIG_DIR/datadog.yaml"
SYSTEM_PROBE_YAML="$CONFIG_DIR/system-probe.yaml"
STAMP="$(date +%Y%m%d%H%M%S)"

if [[ ! -f "$DATADOG_YAML" ]]; then
  echo "$DATADOG_YAML does not exist. Install the Datadog Agent first." >&2
  exit 2
fi

cp -a "$DATADOG_YAML" "$DATADOG_YAML.bak.$STAMP"
if [[ -f "$SYSTEM_PROBE_YAML" ]]; then
  cp -a "$SYSTEM_PROBE_YAML" "$SYSTEM_PROBE_YAML.bak.$STAMP"
elif [[ -f "$SYSTEM_PROBE_YAML.example" ]]; then
  cp -a "$SYSTEM_PROBE_YAML.example" "$SYSTEM_PROBE_YAML"
else
  touch "$SYSTEM_PROBE_YAML"
fi

python3 - "$DATADOG_YAML" "$DD_SITE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
site = sys.argv[2]
text = path.read_text()
start = "# BEGIN codex opentelemetry-demo datadog settings\n"
end = "# END codex opentelemetry-demo datadog settings\n"
block = f"""{start}site: {site}
env: demo
logs_enabled: true
apm_config:
  enabled: true
  apm_non_local_traffic: true
dogstatsd_non_local_traffic: true
logs_config:
  container_collect_all: true
process_config:
  process_collection:
    enabled: true
container_labels_as_tags:
  com.docker.compose.service: compose_service
remote_configuration:
  enabled: true
tags:
  - service:opentelemetry-demo
{end}"""

if start in text and end in text:
    before, rest = text.split(start, 1)
    _, after = rest.split(end, 1)
    text = before + block + after.lstrip("\n")
else:
    text = text.rstrip() + "\n\n" + block
path.write_text(text)
PY

python3 - "$SYSTEM_PROBE_YAML" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text() if path.exists() else ""
start = "# BEGIN codex opentelemetry-demo datadog settings\n"
end = "# END codex opentelemetry-demo datadog settings\n"
block = f"""{start}system_probe_config:
  enabled: true
network_config:
  enabled: true
service_monitoring_config:
  enabled: true
{end}"""

if start in text and end in text:
    before, rest = text.split(start, 1)
    _, after = rest.split(end, 1)
    text = before + block + after.lstrip("\n")
else:
    text = text.rstrip() + "\n\n" + block
path.write_text(text)
PY

chown dd-agent:dd-agent "$DATADOG_YAML" "$SYSTEM_PROBE_YAML"
chmod 640 "$DATADOG_YAML" "$SYSTEM_PROBE_YAML"

systemctl enable --now datadog-agent
systemctl restart datadog-agent
systemctl enable --now datadog-agent-trace datadog-agent-process datadog-agent-sysprobe || true
systemctl restart datadog-agent-trace datadog-agent-process datadog-agent-sysprobe || true

echo "Datadog host Agent configured for OpenTelemetry demo on $DD_SITE."
