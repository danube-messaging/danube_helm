# Danube Helm Charts — Redesign Plan

## Executive Summary

Replace the monolithic `charts/danube_with_etcd` chart with a **modular, composable Helm chart system** that mirrors the Docker Compose layering model already proven in the `danube` repo. A **core chart** provides the production-ready messaging backbone (ETCD + Brokers + Prometheus). Optional **add-on charts** let users wire in the Admin UI and connectors, while MCP integration runs **externally** via `danube-admin` launched by Claude Desktop/Windsurf (stdio transport).

The end-state: an **AI-native Kubernetes platform** where every layer — infrastructure, messaging logic, observability, and data pipelines — is manageable through MCP-powered natural language.

---

## 1. What Exists Today (Problems)

| Issue | Detail |
|-------|--------|
| **Monolithic chart** | Single `danube_with_etcd` chart bundles everything; no way to opt-in to UI, MCP, or connectors |
| **Hardcoded broker instances** | `values.yaml` lists 3 named broker instances; scaling requires editing the list manually |
| **Outdated broker config** | Uses flat config format (`broker_host`, `broker_port`); current broker uses nested YAML (`broker.host`, `broker.ports.client`) |
| **No healthchecks** | ETCD deployment has no healthcheck; brokers use `busybox` init-container instead of proper readiness probes |
| **No StatefulSet for ETCD** | ETCD runs as a Deployment (no stable identity, no PVCs) |
| **No Prometheus deployment** | Only a scrape config example; Prometheus itself is not managed |
| **No admin / UI / MCP** | `danube-admin` (UI gateway + MCP server) didn't exist when the chart was written |
| **No connectors** | Sink/source connectors (Qdrant, DeltaLake, SurrealDB, Webhook, MQTT) have no Helm support |
| **Stale image tags** | Uses `latest` and `ghcr.io/your-username/danube-broker` |

---

## 2. Architecture Overview

```
danube-helm/
├── charts/
│   ├── danube-core/              # REQUIRED — The backbone
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── _helpers.tpl
│   │       ├── NOTES.txt
│   │       ├── broker-statefulset.yaml
│   │       ├── broker-configmap.yaml
│   │       ├── broker-service.yaml
│   │       ├── broker-service-headless.yaml
│   │       ├── broker-hpa.yaml             (optional, gated)
│   │       ├── etcd-statefulset.yaml
│   │       ├── etcd-service.yaml
│   │       ├── etcd-service-headless.yaml
│   │       ├── prometheus-deployment.yaml
│   │       ├── prometheus-configmap.yaml
│   │       ├── prometheus-service.yaml
│   │       ├── ingress.yaml                (optional, gated)
│   │       └── servicemonitor.yaml         (optional, for Prometheus Operator)
│   │
│   ├── danube-admin/             # OPTIONAL — Admin Server (UI mode) + Admin UI
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── admin-deployment.yaml
│   │       ├── admin-service.yaml
│   │       ├── admin-ui-deployment.yaml    (gated by adminUI.enabled)
│   │       ├── admin-ui-service.yaml
│   │       └── ingress.yaml
│   │
│   ├── danube-connector-qdrant/          # OPTIONAL — Qdrant sink connector
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── connector-deployment.yaml
│   │       ├── connector-configmap.yaml
│   │       └── connector-service.yaml
│   │
│   ├── danube-connector-deltalake/       # OPTIONAL — DeltaLake sink connector
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── connector-deployment.yaml
│   │       ├── connector-configmap.yaml
│   │       └── connector-service.yaml
│   │
│   ├── danube-connector-surrealdb/       # OPTIONAL — SurrealDB sink connector
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── connector-deployment.yaml
│   │       ├── connector-configmap.yaml
│   │       └── connector-service.yaml
│   │
│   ├── danube-connector-webhook/         # OPTIONAL — Webhook source connector
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── connector-deployment.yaml
│   │       ├── connector-configmap.yaml
│   │       ├── connector-service.yaml
│   │       └── ingress.yaml
│   │
│   ├── danube-connector-mqtt/            # OPTIONAL — MQTT source connector
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── connector-deployment.yaml
│   │       ├── connector-configmap.yaml
│   │       └── connector-service.yaml
│   │
│   └── danube-stack/              # OPTIONAL — Umbrella chart (core + add-ons)
│       ├── Chart.yaml
│       └── values.yaml
│
├── PLAN.md                       # This file
├── README.md                     # Updated top-level README
├── LICENSE
└── examples/
    ├── quickstart-values.yaml    # Minimal: 3 brokers, ETCD, Prometheus
    ├── with-ui-values.yaml       # + Admin Server + Admin UI
    ├── with-mcp-values.yaml      # Expose broker/prometheus for external MCP
    ├── full-stack-values.yaml    # Everything enabled
    ├── production-values.yaml    # Production-tuned resources + TLS
    └── mcp/
        ├── claude_desktop_config.json
        └── windsurf_mcp_config.json
```

---

## 3. Chart-by-Chart Design

### 3.1 `danube-core` — The Backbone (Required)

This is the only chart that **must** be installed. It provides a fully functional Danube messaging cluster.

#### Components

| Component | K8s Resource | Why |
|-----------|-------------|-----|
| **ETCD** | StatefulSet + Headless Service + PVC | Stable network identity, persistent metadata storage |
| **Brokers** | StatefulSet (replicas: 3 default) | Scalable via `replicaCount`, stable pod names for advertised addresses |
| **Prometheus** | Deployment + ConfigMap + Service | Auto-discovers brokers via headless service, scrapes metrics |
| **Ingress** | Ingress (optional, gated) | Routes external gRPC traffic to brokers |

#### Key Design Decisions

**Brokers as StatefulSet (not per-instance Deployments):**
- Current chart creates 3 separate Deployments (`broker1`, `broker2`, `broker3`). This doesn't scale.
- A StatefulSet with `replicas: 3` gives us `danube-broker-0`, `danube-broker-1`, `danube-broker-2` with stable DNS names.
- Each broker gets its advertised address from its pod name + headless service: `danube-broker-0.danube-broker-headless.NAMESPACE.svc.cluster.local:6650`.
- Scaling is just `--set broker.replicaCount=5`.

**External access + advertised address strategy:**
- Define `broker.externalAccess` modes (ClusterIP-only, NodePort, LoadBalancer, Ingress/Gateway).
- Add `advertisedAddrTemplate` to compute advertised gRPC endpoints for each mode.
- Document when clients should use in-cluster DNS vs external addresses (important for SDKs).

**ETCD as StatefulSet with PVC:**
- Current chart runs ETCD as a Deployment with no persistent storage — data loss on restart.
- StatefulSet with PersistentVolumeClaim ensures metadata survives pod restarts.
- Uses `quay.io/coreos/etcd:v3.5.9` (pinned, not `latest`).

**ETCD multi-node bootstrap:**
- For `replicaCount > 1`, template `initial-cluster`, peer URLs, and `initial-cluster-state` using StatefulSet ordinals.
- Support a configurable cluster domain for peer DNS names.
- Provide a clear dev vs prod toggle (single-node vs 3-node).

**Updated Broker Config Format:**
- Matches the current `danube_broker.yml` structure with nested `broker.host`, `broker.ports`, `meta_store`, `load_manager`, `wal_cloud`, etc.
- ConfigMap is templated from `values.yaml` so users can override any field.

**TLS + secret handling:**
- Expose TLS settings and secret references for broker/client auth and admin connections.
- Allow mounting custom CA/cert/key secrets into broker, admin, and MCP pods.

**Prometheus auto-scrape:**
- ConfigMap uses `kubernetes_sd_configs` with role `endpoints` to auto-discover broker pods.
- No more hardcoded `broker1:9040`, `broker2:9040` target lists.

#### `values.yaml` Structure (Core)

```yaml
global:
  clusterName: "MY_CLUSTER"
  imageRegistry: "ghcr.io/danube-messaging"

broker:
  replicaCount: 3
  image:
    repository: ghcr.io/danube-messaging/danube-broker
    tag: "v0.7.2"
    pullPolicy: IfNotPresent
  ports:
    client: 6650
    admin: 50051
    prometheus: 9040
  service:
    type: ClusterIP
  externalAccess:
    enabled: false
    type: ClusterIP # ClusterIP | NodePort | LoadBalancer | Ingress
    advertisedAddrTemplate: "{podName}.{headlessService}.{namespace}.svc.cluster.local:6650"
  resources:
    requests: { cpu: 200m, memory: 256Mi }
    limits:   { cpu: 500m, memory: 512Mi }
  env:
    RUST_LOG: "danube_broker=info,danube_core=info"
  tls:
    enabled: false
    secretName: ""
  config:
    autoCreateTopics: true
    bootstrapNamespaces: ["default"]
    assignmentStrategy: "balanced"
    auth:
      mode: none
    storage:
      walDir: "/danube-data/wal"
      cloudBackend: "fs"                # fs | s3 | gcs | azblob
      cloudRoot: "/danube-data/cloud-storage"
      uploaderEnabled: false
    policies:
      maxProducersPerTopic: 0
      maxMessageSize: 10485760
  persistence:
    enabled: true
    size: 10Gi
    storageClass: ""
  hpa:
    enabled: false
    minReplicas: 3
    maxReplicas: 10
    targetCPU: 70

etcd:
  replicaCount: 1                       # 1 for dev, 3 for production
  image:
    repository: quay.io/coreos/etcd
    tag: "v3.5.9"
    pullPolicy: IfNotPresent
  service:
    port: 2379
    peerPort: 2380
  cluster:
    initialClusterState: "new"
    domain: "cluster.local"
  persistence:
    enabled: true
    size: 2Gi
    storageClass: ""
  resources:
    requests: { cpu: 100m, memory: 128Mi }
    limits:   { cpu: 500m, memory: 512Mi }
  auth:
    enabled: false                      # ALLOW_NONE_AUTHENTICATION=yes

prometheus:
  enabled: true
  image:
    repository: prom/prometheus
    tag: "v2.53.0"
  service:
    port: 9090
  scrapeInterval: 5s
  resources:
    requests: { cpu: 100m, memory: 256Mi }
    limits:   { cpu: 500m, memory: 512Mi }
  # If using Prometheus Operator, set this instead:
  serviceMonitor:
    enabled: false

ingress:
  enabled: false
  className: "nginx"
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
  hosts: []
  tls: []
```

---

### 3.2 `danube-admin` — Admin Server + Web UI (Optional)

Deploys `danube-admin` in `--mode ui` (HTTP API server) and optionally the `danube-admin-ui` (Nginx-served React app).

**When to install:** Users who want a web dashboard for cluster monitoring, topic management, and visual exploration.

```yaml
# values.yaml
admin:
  enabled: true
  image:
    repository: ghcr.io/danube-messaging/danube-admin
    tag: "v0.7.2"
  service:
    port: 8080
  config:
    brokerEndpoint: ""     # Auto-discovered from danube-core service
    prometheusUrl: ""      # Auto-discovered from danube-core prometheus service
    requestTimeoutMs: 5000
    cacheTtlMs: 3000
  tls:
    enabled: false
    secretName: ""

core:
  releaseName: "danube"
  namespace: "" # defaults to release namespace

adminUI:
  enabled: true
  image:
    repository: ghcr.io/danube-messaging/danube-admin-ui
    tag: "latest"
  service:
    port: 80
  ingress:
    enabled: false
    host: "danube-ui.example.com"
```

**Service discovery:** The admin chart references the core chart's service names via a shared naming convention (`{{ .Release.Name }}-danube-broker-headless`) or explicit `values.yaml` override. This is cleaner than cross-chart dependencies. Set `core.releaseName`/`core.namespace` when installing in a different namespace.

---

### 3.3 MCP Integration (External)

The MCP server should run **outside** the cluster, launched by the AI tool (Claude Desktop/Windsurf/VSCode) using stdio transport. Only the Admin UI/server mode needs a chart in-cluster.

**Connectivity requirements:**
- Broker admin gRPC endpoint reachable (via `broker.externalAccess` or `kubectl port-forward`).
- Prometheus reachable for metrics tools (via `kubectl port-forward` or external access).

**Example local MCP run (stdio):**
```bash
danube-admin serve --mode mcp \
  --broker-endpoint http://localhost:50051 \
  --prometheus-url http://localhost:9090
```

Store MCP config examples under `examples/mcp/` for Claude Desktop and Windsurf.

---

### 3.4 Connector Charts — Data Pipeline Add-ons (Optional)

Each connector follows the **same template pattern**, making it easy to add new connectors in the future.

#### Common Connector Structure

Every connector chart shares this `values.yaml` shape:

```yaml
connector:
  enabled: true
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

#### Connector-Specific Details

| Chart | Image | Key Config | External Dependencies |
|-------|-------|------------|----------------------|
| `danube-connector-qdrant` | `danube-sink-qdrant:v0.2.1` | `qdrant.url`, `topic_mappings`, `vector_dimension` | Qdrant (user-managed or in-cluster) |
| `danube-connector-deltalake` | `danube-sink-deltalake:v0.2.1` | `deltalake.storage_backend`, `s3_*`, `topic_mappings` | S3/MinIO/GCS (user-managed) |
| `danube-connector-surrealdb` | `danube-sink-surrealdb:v0.2.1` | `surrealdb.*`, `topic_mappings` | SurrealDB (user-managed or in-cluster) |
| `danube-connector-webhook` | `danube-source-webhook:v0.2.0` | `webhook.endpoints`, `api_key` | None (exposes HTTP ingress) |
| `danube-connector-mqtt` | `danube-source-mqtt:latest` | `mqtt.broker_url`, `topic_mappings` | MQTT broker (user-managed) |

Each connector ConfigMap renders a `connector.toml` from values, with environment variable overrides for secrets (`AWS_ACCESS_KEY_ID`, `QDRANT_API_KEY`, etc.).

**Optional topic/schema bootstrap Jobs:** mirror the Docker examples by adding an optional Helm Job (or hook) that registers schemas and creates topics via `danube-admin-cli`.

---

## 4. Installation Scenarios

### Scenario 1: Quickstart (Dev/Testing)

```bash
helm install danube ./charts/danube-core
```

Deploys: 3 brokers + 1 ETCD + Prometheus. Ready to produce/consume in ~30 seconds.

For external clients, enable `broker.externalAccess` and set `advertisedAddrTemplate` to the desired external address scheme.

### Scenario 2: With Admin UI

```bash
helm install danube ./charts/danube-core
helm install danube-admin ./charts/danube-admin \
  --set admin.config.brokerEndpoint=danube-danube-broker-0.danube-danube-broker-headless:50051
```

### Scenario 3: AI-Native Management (External MCP)

```bash
helm install danube ./charts/danube-core

# Expose broker + Prometheus for the local MCP process
kubectl port-forward svc/<release-name>-danube-broker 50051:50051
kubectl port-forward svc/<release-name>-prometheus 9090:9090

# Run MCP locally (stdio transport)
danube-admin serve --mode mcp \
  --broker-endpoint http://localhost:50051 \
  --prometheus-url http://localhost:9090
```

Configure Claude/Windsurf using the configs in `examples/mcp/`. If you enable `broker.externalAccess`, you can skip port-forwarding.

### Scenario 4: Full AI-Native Stack with Qdrant RAG Pipeline

```bash
# Core messaging
helm install danube ./charts/danube-core \
  --set broker.replicaCount=5 \
  --set broker.config.assignmentStrategy=balanced

# AI management layer (UI in-cluster)
helm install danube-admin ./charts/danube-admin

# MCP runs locally (see Scenario 3)

# Data pipeline: Qdrant vector search
helm install danube-qdrant ./charts/danube-connector-qdrant \
  -f my-qdrant-connector-values.yaml
```

### Scenario 5: Production with Cloud Storage + TLS

```bash
helm install danube ./charts/danube-core -f examples/production-values.yaml
```

Where `production-values.yaml` enables:
- S3 cloud backend for WAL persistence
- TLS authentication
- HPA for auto-scaling brokers
- 3-node ETCD cluster
- Increased resource limits
- ServiceMonitor for Prometheus Operator

---

## 5. AI-Native Management Vision

The ultimate goal is managing the entire stack through natural language via three MCP layers:

| Layer | MCP Server | Deployed By | Example Queries |
|-------|-----------|-------------|-----------------|
| **Infrastructure** | Kubernetes MCP Server | External (user's AI tool) | "Scale the Danube broker StatefulSet to 5 replicas" |
| | | | "Check ETCD pod health and storage usage" |
| | | | "Show me the ingress configuration" |
| **Messaging Logic** | Danube Admin MCP Server | External (Claude/Windsurf local MCP) | "Create topic 'orders-v1' with 4 partitions and an Avro schema" |
| | | | "Show consumer lag for all subscriptions" |
| | | | "Rebalance topics across brokers" |
| | | | "Register a JSON schema for user events" |
| **Observability** | Prometheus/Grafana MCP | External or future chart | "Show broker message throughput for the last hour" |
| | | | "Alert me if p99 latency exceeds 50ms" |
| | | | "Compare CPU usage across all broker pods" |
| **Data Pipelines** | Danube Admin MCP (extended) | External (Claude/Windsurf local MCP) | "Deploy a Qdrant sink connector for topic /ai/embeddings" |
| | | | "Show connector processing rate and error count" |
| | | | "Scale the DeltaLake connector to 3 replicas" |

### MCP Config for Full Stack Management

Configure your AI assistant to launch the local MCP process (stdio):

```json
{
  "mcpServers": {
    "danube-admin": {
      "command": "danube-admin",
      "args": [
        "serve",
        "--mode",
        "mcp",
        "--broker-endpoint",
        "http://localhost:50051",
        "--prometheus-url",
        "http://localhost:9090"
      ]
    }
  }
}
```

Ensure the broker and Prometheus endpoints are reachable (port-forward or external access):
```bash
kubectl port-forward svc/<release-name>-danube-broker 50051:50051
kubectl port-forward svc/<release-name>-prometheus 9090:9090
```

---

## 6. Implementation Phases

### Phase 1: Core Chart (MVP)
**Goal:** Replace `danube_with_etcd` with production-ready `danube-core`.

- [ ] Create `charts/danube-core/Chart.yaml` (apiVersion v2, version 1.0.0)
- [ ] Create `charts/danube-core/values.yaml` with full broker config structure
- [ ] Template: `_helpers.tpl` — naming conventions, labels, selectors
- [ ] Template: `broker-statefulset.yaml` — StatefulSet with readiness/liveness probes
- [ ] Template: `broker-configmap.yaml` — Full `danube_broker.yml` from values
- [ ] Template: `broker-service.yaml` — ClusterIP service for client access
- [ ] Template: `broker-service-headless.yaml` — Headless service for StatefulSet DNS
- [ ] External access + advertised address templates (NodePort/LB/Ingress)
- [ ] Template: `etcd-statefulset.yaml` — StatefulSet with PVC and healthcheck
- [ ] ETCD multi-node bootstrap (peer URLs + initial cluster)
- [ ] Template: `etcd-service.yaml` + `etcd-service-headless.yaml`
- [ ] Template: `prometheus-deployment.yaml` + `prometheus-configmap.yaml` + service
- [ ] Template: `ingress.yaml` (gated by `ingress.enabled`)
- [ ] Template: `NOTES.txt` — post-install instructions
- [ ] TLS/secret mounts for broker and etcd
- [ ] Create `examples/quickstart-values.yaml`
- [ ] Create `examples/production-values.yaml`
- [ ] Test with `helm template` and `helm install` on kind cluster
- [ ] Update top-level `README.md`

### Phase 2: Admin + MCP Integration
**Goal:** Enable UI dashboard and AI-native management.

- [ ] Create `charts/danube-admin/` chart (admin server + UI)
- [ ] Service discovery: auto-resolve broker and prometheus endpoints (with namespace overrides)
- [ ] Create `examples/with-ui-values.yaml`
- [ ] Create `examples/with-mcp-values.yaml` (external access settings)
- [ ] Add `examples/mcp/` configs for Claude Desktop and Windsurf
- [ ] Document external MCP usage (stdio + port-forward or external access)

### Phase 3: Connector Charts
**Goal:** Plug-and-play data pipeline connectors.

- [ ] Create connector chart template (shared pattern)
- [ ] `charts/danube-connector-qdrant/` — Qdrant vector sink
- [ ] `charts/danube-connector-deltalake/` — DeltaLake sink
- [ ] `charts/danube-connector-surrealdb/` — SurrealDB sink
- [ ] `charts/danube-connector-webhook/` — Webhook source (with Ingress)
- [ ] `charts/danube-connector-mqtt/` — MQTT source
- [ ] Each connector: ConfigMap from TOML values, secret references, metrics port
- [ ] Optional init Jobs for schema/topic creation (mirrors Docker `topic-init`)
- [ ] Verify connector image tags for each release
- [ ] Create `examples/full-stack-values.yaml`

### Phase 4: Polish & Distribution
**Goal:** Production-ready distribution via Helm repository.

- [ ] GitHub Actions: lint, test, package, publish charts
- [ ] `ct` (chart-testing) integration
- [ ] Helm repo hosted on GitHub Pages (`gh-pages` branch)
- [ ] Add `broker-hpa.yaml` for horizontal pod autoscaling
- [ ] Add `servicemonitor.yaml` for Prometheus Operator users
- [ ] Add PDBs + topology spread/anti-affinity for brokers and etcd
- [ ] Add Helm test hooks for smoke checks
- [ ] Add optional `danube-stack` umbrella chart
- [ ] Grafana dashboard JSON ConfigMap (optional)
- [ ] Security: NetworkPolicies, PodSecurityContext, RBAC
- [ ] Comprehensive `README.md` with architecture diagrams

---

## 7. Migration from Old Chart

Since backward compatibility is not required:

1. **Delete** `charts/danube_with_etcd/` entirely
2. **Delete** `rendered-manifests.yaml` (outdated)
3. **Delete** `prometheus_example.yaml` (replaced by in-chart Prometheus)
4. **Update** `setup_local_machine.md` to reference new chart names and values
5. **Rewrite** `README.md` as the new landing page

Users on the old chart: `helm uninstall` → `helm install` with new chart.

---

## 8. Naming Conventions

| Resource | Name Pattern |
|----------|-------------|
| Broker StatefulSet | `{{ .Release.Name }}-danube-broker` |
| Broker Headless Service | `{{ .Release.Name }}-danube-broker-headless` |
| Broker Client Service | `{{ .Release.Name }}-danube-broker` |
| ETCD StatefulSet | `{{ .Release.Name }}-etcd` |
| ETCD Headless Service | `{{ .Release.Name }}-etcd-headless` |
| Prometheus Deployment | `{{ .Release.Name }}-prometheus` |
| Admin Deployment | `{{ .Release.Name }}-danube-admin` |
| Admin UI Deployment | `{{ .Release.Name }}-danube-admin-ui` |
| MCP Deployment | `{{ .Release.Name }}-danube-mcp` |
| Connector Deployment | `{{ .Release.Name }}-connector-<type>` |
| ConfigMaps | `{{ .Release.Name }}-<component>-config` |

---

## 9. Version Pinning

| Component | Image | Tag |
|-----------|-------|-----|
| Danube Broker | `ghcr.io/danube-messaging/danube-broker` | `v0.7.2` |
| Danube Admin | `ghcr.io/danube-messaging/danube-admin` | `v0.7.2` |
| Danube Admin UI | `ghcr.io/danube-messaging/danube-admin-ui` | `latest` |
| ETCD | `quay.io/coreos/etcd` | `v3.5.9` |
| Prometheus | `prom/prometheus` | `v2.53.0` |
| Qdrant Sink | `ghcr.io/danube-messaging/danube-sink-qdrant` | `v0.2.1` |
| DeltaLake Sink | `ghcr.io/danube-messaging/danube-sink-deltalake` | `v0.2.1` |
| SurrealDB Sink | `ghcr.io/danube-messaging/danube-sink-surrealdb` | `v0.2.1` |
| Webhook Source | `ghcr.io/danube-messaging/danube-source-webhook` | `v0.2.0` |
| MQTT Source | `ghcr.io/danube-messaging/danube-source-mqtt` | `latest` |

---

## 10. What This Unlocks

Once fully implemented, a user's workflow looks like:

```bash
# 1. Deploy the messaging backbone
helm install danube danube/danube-core

# 2. Add AI management
helm install danube-mcp danube/danube-mcp

# 3. Ask AI to manage everything
"Create a topic called 'user-events' with JSON schema validation and 4 partitions"
"Deploy a Qdrant connector to stream embeddings from /ai/vectors"  
"Show me the message throughput across all brokers"
"Scale the broker cluster to 5 nodes"
"Check ETCD health and show storage usage"
"Rebalance topics — broker-2 seems overloaded"
```

The Helm charts handle the **infrastructure plumbing**. The MCP servers handle the **intelligent management**. The user just talks.
