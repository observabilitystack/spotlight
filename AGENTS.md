# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this repo is

This is the **infrastructure-as-code** for [spotlight.o11y.cool](https://spotlight.o11y.cool),
a public Grafana site that compares AWS EC2 **spot instance prices** over time.

There is **no application source code here**. The repo declaratively wires together
three off-the-shelf container images using Kubernetes manifests plus a Grafana
dashboard definition. The actual data-collection logic lives in a separate image
(`spot-price-exporter`), not in this repo.

## Repository layout

| Path | Purpose |
|------|---------|
| `README.md` | Deployment runbook (`envsubst` + `kubectl`) |
| `aws-spot-price-dashboard.json` | The Grafana dashboard — this is the product UI |
| `manifests/configuration.yaml` | `ConfigMap` `spotlight-configuration`: Prometheus scrape config, Grafana datasource/dashboard provisioning, and `grafana.ini` |
| `manifests/deployment.yaml` | `PersistentVolumeClaim`, single-replica `Deployment` (3 containers), `Service`, and a Traefik `Ingress` |
| `.gitignore` | Ignores `secrets.*` and `tf-workspace/.terraform` |

Everything runs in the `o11y-cool` namespace.

## Architecture

One pod, three containers sharing `localhost`:

```
AWS Spot Price API
      │ (AWS creds via env)
      ▼
spot-price-exporter :8080  ──scrape 1m──▶  Prometheus :9090 ──▶ PVC (128Gi nfs-client)
                                                 │
                                       datasource http://localhost:9090
                                                 ▼
                                           Grafana :3000 ──▶ Service :80 ──▶ Traefik Ingress (ACME TLS)
```

- **prometheus** — `prom/prometheus:v3.11.3`, port 9090, 120GB retention on the PVC, `memory-snapshot-on-shutdown` enabled.
- **spot-price-exporter** — `ghcr.io/observabilitystack/spot-price-exporter:latest`, port 8080, gets AWS creds via `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` env.
- **grafana** — `grafana/grafana:12.4.3`, port 3000. Anonymous auth on, login form disabled, light theme, alerting/analytics off. The dashboard JSON is the default home dashboard.

## Build / test / run

There is **no build step, no test suite, and no CI**. This is expected for a
declarative IaC repo — correctness is validated at `kubectl apply` time.

Deployment is manual (see `README.md`):

```bash
# secrets.env holds: aws_access_key, aws_secret_access_key, grafana_domain, grafana_admin_password
kubectl create namespace o11y-cool
kubectl create configmap spotlight-dashboard --namespace=o11y-cool --from-file=aws-spot-price-dashboard.json

set -a; source secrets.env; set +a
envsubst < manifests/configuration.yaml | kubectl apply -f -
envsubst < manifests/deployment.yaml | kubectl apply -f -
```

To validate a manifest change without a live cluster, dry-run it:

```bash
set -a; source secrets.env; set +a
envsubst < manifests/deployment.yaml | kubectl apply --dry-run=client -f -
```

## Conventions & gotchas

- **`envsubst` templating.** Manifests contain `${grafana_domain}`,
  `${grafana_admin_password}`, `${aws_access_key}`, and `${aws_secret_access_key}`.
  `${grafana_secret_key}`. The raw YAML is **not valid until substituted** — never "fix" these placeholders
  into literal values.
- **Secrets never get committed.** `secrets.env` is gitignored via `secrets.*` and
  is not tracked. Do not paste AWS keys or passwords into any tracked file.
- **`localhost` is intentional.** All three containers are in one pod, so they
  reference each other as `localhost:8080` / `localhost:9090`. Do not rewrite these
  to Service DNS names.
- **Label enrichment matters.** `prometheus.yaml` (inside `configuration.yaml`) uses
  `metric_relabel_configs` to derive:
  - `cpu_type` from the instance-type name — `\di`→`intel`, `\da`→`amd`, `\dg`→`graviton`, else `unspecified`
  - `instance_size` from the part after the `.`

  The dashboard's template-variable cascade (region → AZ → generation → cpu_type →
  size → instance_type) depends on these labels. Changing the regexes will break the
  dashboard filters.
- **Stateful single instance.** `replicas: 1` with `strategy: Recreate` and one
  RWO PVC — do not scale up or switch to RollingUpdate.
- **Node affinity** excludes control-plane nodes.
- **Image versions.** Grafana and Prometheus are pinned; the exporter uses `:latest`.
  Prefer pinning when bumping versions.

## Where changes go

- **Dashboard / panels / queries** → `aws-spot-price-dashboard.json` (re-apply the
  `spotlight-dashboard` ConfigMap to ship it; Grafana reloads every 30s).
- **Scrape config, label rules, Grafana settings** → `manifests/configuration.yaml`.
- **Containers, resources, ingress, volumes** → `manifests/deployment.yaml`.
