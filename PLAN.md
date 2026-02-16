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
- [x] Test on Kind cluster with danube-core

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

### Phase 3: `danube-connector` — Generic Connector Chart

A single generic chart that deploys any Danube connector. Each connector is installed
as its own Helm release with a connector-specific values file.

```bash
helm install qdrant-sink danube/danube-connector -n danube -f examples/sink-qdrant.yaml
helm install mqtt-source danube/danube-connector -n danube -f examples/source-mqtt.yaml
```

The chart creates: ConfigMap (TOML config), Deployment, Service (metrics + extra ports), Secret (optional).

#### Example Values Files

| File | Image | External Dependencies |
|------|-------|----------------------|
| `sink-qdrant.yaml` | `danube-sink-qdrant` | Qdrant |
| `sink-deltalake.yaml` | `danube-sink-deltalake` | S3/MinIO/GCS |
| `sink-surrealdb.yaml` | `danube-sink-surrealdb` | SurrealDB |
| `source-mqtt.yaml` | `danube-source-mqtt` | MQTT broker |
| `source-webhook.yaml` | `danube-source-webhook` | None (exposes HTTP) |

#### Tasks

- [x] Create generic `charts/danube-connector/` chart
- [x] ConfigMap from inline TOML, Secret for credentials, extra file mounts
- [x] Extra ports support (webhook HTTP server)
- [x] Example values files for all 5 connectors
- [x] Chart README with usage instructions
- [ ] Test on Kind cluster

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
