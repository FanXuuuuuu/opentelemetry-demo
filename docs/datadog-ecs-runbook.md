# OpenTelemetry Demo Datadog ECS Runbook

## Scope

This fork runs the upstream OpenTelemetry Astronomy Shop demo and sends telemetry
to Datadog US5.

## Datadog inputs

- `DD_API_KEY`: set on the ECS host in `.env.datadog`; do not commit it.
- `DD_SITE`: `us5.datadoghq.com`.
- `env`: `demo`.
- `version`: inherited from `.env` `IMAGE_VERSION`.
- Datadog Collector feature gate:
  `datadog.EnableOperationAndResourceNameV2`.

## Start command

```bash
docker compose --env-file .env --env-file .env.datadog \
  -f compose.yaml -f compose.extras.yaml up -d
```

Use `compose.full.yaml` only if the ECS host has enough memory for Kafka and the
extra services:

```bash
docker compose --env-file .env --env-file .env.datadog \
  -f compose.yaml -f compose.full.yaml -f compose.extras.yaml up -d
```

The Datadog documentation for the OpenTelemetry demo currently recommends 6GB of
available RAM. A 2 vCPU / 2 GiB ECS instance should run with swap enabled or be
upgraded before attempting the full profile.

## What this fork enables

- OTel traces, metrics, and logs are exported through the Collector Datadog
  exporter.
- Datadog's Collector connector derives APM stats from traces for Datadog APM
  service views.
- Datadog Agent collects host/container infrastructure, Docker container logs,
  processes, Universal Service Monitoring, Cloud Network Monitoring, and Remote
  Configuration prerequisites.
- Error Tracking can be demonstrated from application errors in traces/logs.

## Live Debugger note

Datadog Dynamic Instrumentation / Live Debugger is not enabled by the OTel
Collector alone. Datadog requires Agent 7.49+ with Remote Configuration and a
supported Datadog tracing library in the service process. The Agent side is
enabled here; individual services still need Datadog tracing-library setup before
Live Debugger probes can be created from the Datadog UI.

## Verification checklist

1. `docker compose ps` shows `otel-collector`, `datadog-agent`, `frontend-proxy`,
   `frontend`, and backend services healthy or running.
2. `docker logs otel-collector` has no Datadog exporter authentication errors.
3. `docker exec datadog-agent agent status` reports Datadog site US5, logs
   enabled, process agent running, and system-probe enabled.
4. `curl http://localhost:8080` returns the Astronomy Shop frontend.
5. Datadog APM Service Catalog shows `env:demo` services under
   `service.namespace:opentelemetry-demo`.
6. Metrics Explorer can query host/container metrics and OTel application
   metrics.
7. Trace Explorer shows recent traces for frontend checkout/browse flows.
8. Logs Explorer shows container logs correlated with service/env/version.
9. Error Tracking shows issues after triggering known failing checkout/payment
   paths.
10. Live Debugger is validated only after a Datadog tracing library is installed
    for at least one supported service.
