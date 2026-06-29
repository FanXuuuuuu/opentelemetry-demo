# Task Summary - 2026-06-29

## Target

Replace the existing ECS demo application on `8.141.2.50` with a fork of
`open-telemetry/opentelemetry-demo`, connect the new demo to Datadog US5, and
verify metrics, traces, logs, Error Tracking, and Live Debugger related features.

## Completed locally

1. Pulled `open-telemetry/opentelemetry-demo` `main` into the workspace.
2. Added `upstream` remote:
   `https://github.com/open-telemetry/opentelemetry-demo.git`.
3. Added `origin` remote target:
   `https://github.com/FanXuuuuuu/opentelemetry-demo.git`.
4. Added Datadog Collector exporter configuration in
   `src/otel-collector/otelcol-config-extras.yml`.
5. Added Datadog Collector connector, extension, and resource processor
   settings so traces, APM stats, metrics, and logs are sent in Datadog's
   expected shape.
6. Added a Datadog Agent service in `compose.extras.yaml` for infrastructure,
   container logs, process collection, Remote Configuration, USM, and network
   monitoring prerequisites.
7. Added `.env.datadog.example` so `DD_API_KEY` is supplied on the ECS host
   without committing secrets.
8. Added `.env.datadog` to `.gitignore`.
9. Added `docs/datadog-ecs-runbook.md` with startup and verification steps.
10. Added `scripts/ecs-deploy-datadog-demo.sh` as the ECS deployment helper.

## Current blockers

1. The fork now exists and is readable at
   `https://github.com/FanXuuuuuu/opentelemetry-demo.git`, but pushing from the
   Codex command environment is still blocked by GitHub authentication.
2. ECS SSH access from the Codex command environment is blocked because no
   default SSH private key exists under `C:\Users\Felix\.ssh`, and
   non-interactive root login returned:
   `Permission denied (publickey,password)`.
   The user has confirmed an active Xshell connection from the local machine,
   but that GUI terminal session is not usable as OpenSSH credentials by Codex.
3. Local Docker validation is blocked because Docker CLI is not installed on the
   local machine.
4. Full OpenTelemetry demo deployment is likely too large for the current
   2 vCPU / 2 GiB ECS instance. Datadog's current OpenTelemetry demo guidance
   recommends 6GB available RAM. Use swap, a reduced compose profile, or a larger
   ECS instance before running the full profile.

## Intended ECS deployment steps

After GitHub push authentication and Codex-usable SSH access are available:

1. Push this workspace branch to the fork.
2. SSH to `8.141.2.50`.
3. Stop the previous demo application with the deployment method found on the
   host, for example `docker compose down` or the existing systemd unit stop.
4. Clone/pull the fork on the ECS host.
5. Create `.env.datadog` with `DD_API_KEY=<redacted>` and
   `DD_SITE=us5.datadoghq.com`.
6. Run the helper script, or start the new demo manually.

   Helper script:

   ```bash
   DD_API_KEY=<redacted> bash scripts/ecs-deploy-datadog-demo.sh
   ```

   Manual start:

   ```bash
   docker compose --env-file .env --env-file .env.datadog \
     -f compose.yaml -f compose.extras.yaml up -d
   ```

7. If memory permits, start the full profile:

   ```bash
   docker compose --env-file .env --env-file .env.datadog \
     -f compose.yaml -f compose.full.yaml -f compose.extras.yaml up -d
   ```

## Verification still required

1. `docker compose ps` on ECS shows all required services running.
2. `docker logs otel-collector` has no Datadog exporter errors.
3. `docker exec datadog-agent agent status` confirms US5, logs, process agent,
   system-probe, and Remote Configuration.
4. `http://8.141.2.50:8080` serves the Astronomy Shop frontend.
5. Datadog Metrics Explorer receives host/container and OTel app metrics.
6. Datadog Trace Explorer receives `env:demo` service traces.
7. Datadog Logs Explorer receives container logs with service/env/version tags.
8. Datadog Error Tracking receives an issue after an intentional failing flow.
9. Live Debugger/Dynamic Instrumentation is verified only after adding a
   supported Datadog tracing library to at least one service process; OTel
   Collector export alone does not enable Live Debugger probes.
