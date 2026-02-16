# Danube Helm Charts — Plan (Next Phases)

## What's Done

Phase 1 is complete. The following charts are implemented, tested, and published:

| Chart | Status | Description |
|-------|--------|-------------|
| **danube-envoy** | ✅ Done | Envoy gRPC proxy with Dynamic Forward Proxy + Lua filter |
| **danube-core** | ✅ Done | Brokers (StatefulSet), etcd, Prometheus |

See [setup_local_machine.md](setup_local_machine.md) for the tested deployment flow.

---

## Next Phases

### Phase 2: `danube-ui` — Admin Server + Web UI

Deploys `danube-admin` in `--mode ui` (HTTP API server) and `danube-admin-ui` (Nginx-served React app).

**When to install:** Users who want a web dashboard for cluster monitoring, topic management, and visual exploration.

```yaml
# values.yaml
admin:
  image:
    repository: ghcr.io/danube-messaging/danube-admin
    tag: "latest"
  service:
    port: 8080
  config:
    brokerEndpoint: "danube-core-broker:50051"
    prometheusUrl: "http://danube-core-prometheus:9090"
    requestTimeoutMs: 5000
    cacheTtlMs: 3000
    corsAllowOrigin: ""    # auto-constructed from UI service

ui:
  enabled: true
  image:
    repository: ghcr.io/danube-messaging/danube-admin-ui
    tag: "latest"
  service:
    type: ClusterIP
    port: 80
```

**Service discovery:** The admin server connects to `danube-core-broker:50051` (admin gRPC) and `danube-core-prometheus:9090` by default. Override `admin.config.brokerEndpoint` and `admin.config.prometheusUrl` if using a different release name or namespace.

#### Tasks

- [x] Create `charts/danube-ui/` chart (admin server + UI)
- [x] Service discovery: broker and prometheus endpoints via values
- [ ] Add `examples/mcp/` configs for Claude Desktop and Windsurf
- [ ] Document external MCP usage (stdio + port-forward or external access)
- [ ] Test on Kind cluster with danube-core

---

### Phase 2b: MCP Integration (External)

The MCP server runs **outside** the cluster, launched by the AI tool (Claude Desktop / Windsurf / VSCode) using stdio transport.

**Connectivity requirements:**
- Broker admin gRPC endpoint reachable (via `kubectl port-forward` or external access)
- Prometheus reachable for metrics tools

**Example local MCP run (stdio):**
```bash
danube-admin serve --mode mcp \
  --broker-endpoint http://localhost:50051 \
  --prometheus-url http://localhost:9090
```

**MCP config example:**
```json
{
  "mcpServers": {
    "danube-admin": {
      "command": "danube-admin",
      "args": [
        "serve", "--mode", "mcp",
        "--broker-endpoint", "http://localhost:50051",
        "--prometheus-url", "http://localhost:9090"
      ]
    }
  }
}
```

---

### Phase 3: Connector Charts — Data Pipeline Add-ons

Each connector follows the same template pattern.

#### Common Connector Structure

```yaml
connector:
  image:
    repository: ghcr.io/danube-messaging/danube-sink-<NAME>
    tag: "v0.2.1"
  replicaCount: 1
  config: {}           # Connector-specific TOML config (mounted as ConfigMap)
  env: {}              # Environment variables (secrets via envFrom)
  secrets: {}          # Kubernetes secrets for credentials
  metricsPort: 9090
  resources:
    requests: { cpu: 100m, memory: 128Mi }
    limits:   { cpu: 500m, memory: 512Mi }
```

#### Planned Connectors

| Chart | Image | Key Config | External Dependencies |
|-------|-------|------------|----------------------|
| `danube-connector-qdrant` | `danube-sink-qdrant` | `qdrant.url`, `topic_mappings`, `vector_dimension` | Qdrant |
| `danube-connector-deltalake` | `danube-sink-deltalake` | `deltalake.storage_backend`, `s3_*`, `topic_mappings` | S3/MinIO/GCS |
| `danube-connector-surrealdb` | `danube-sink-surrealdb` | `surrealdb.*`, `topic_mappings` | SurrealDB |
| `danube-connector-webhook` | `danube-source-webhook` | `webhook.endpoints`, `api_key` | None (exposes HTTP) |
| `danube-connector-mqtt` | `danube-source-mqtt` | `mqtt.broker_url`, `topic_mappings` | MQTT broker |

#### Tasks

- [ ] Create connector chart template (shared pattern)
- [ ] `charts/danube-connector-qdrant/`
- [ ] `charts/danube-connector-deltalake/`
- [ ] `charts/danube-connector-surrealdb/`
- [ ] `charts/danube-connector-webhook/` (with Ingress)
- [ ] `charts/danube-connector-mqtt/`
- [ ] Each connector: ConfigMap from TOML values, secret references, metrics port
- [ ] Optional init Jobs for schema/topic creation

---

### Phase 4: Polish & Distribution

- [ ] GitHub Actions: lint, test, package, publish charts
- [ ] `ct` (chart-testing) integration
- [ ] Add `broker-hpa.yaml` for horizontal pod autoscaling
- [ ] Add `servicemonitor.yaml` for Prometheus Operator users
- [ ] Add PDBs + topology spread / anti-affinity for brokers and etcd
- [ ] Add Helm test hooks for smoke checks
- [ ] Optional `danube-stack` umbrella chart (core + envoy + admin in one install)
- [ ] Grafana dashboard JSON ConfigMap
- [ ] Security: NetworkPolicies, PodSecurityContext, RBAC
- [ ] Production deployment guide

---

## Version Pinning

| Component | Image | Tag |
|-----------|-------|-----|
| Danube Broker | `ghcr.io/danube-messaging/danube-broker` | `v0.7.3` |
| Danube Admin | `ghcr.io/danube-messaging/danube-admin` | `v0.7.2` |
| Danube Admin UI | `ghcr.io/danube-messaging/danube-admin-ui` | `latest` |
| Envoy | `envoyproxy/envoy` | `v1.31-latest` |
| ETCD | `quay.io/coreos/etcd` | `v3.5.9` |
| Prometheus | `prom/prometheus` | `v2.53.0` |
| Qdrant Sink | `ghcr.io/danube-messaging/danube-sink-qdrant` | `v0.2.1` |
| DeltaLake Sink | `ghcr.io/danube-messaging/danube-sink-deltalake` | `v0.2.1` |
| SurrealDB Sink | `ghcr.io/danube-messaging/danube-sink-surrealdb` | `v0.2.1` |
| Webhook Source | `ghcr.io/danube-messaging/danube-source-webhook` | `v0.2.0` |
| MQTT Source | `ghcr.io/danube-messaging/danube-source-mqtt` | `latest` |
