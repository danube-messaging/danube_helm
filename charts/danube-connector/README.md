# Danube Connector Chart

A generic Helm chart for deploying any Danube source or sink connector on Kubernetes.

Instead of a separate chart per connector, this single chart handles all connector
types. Each connector is installed as its own Helm release with a connector-specific
values file.

## Supported Connectors

| Connector | Image | Type | Description |
|-----------|-------|------|-------------|
| Qdrant Sink | `ghcr.io/danube-messaging/danube-sink-qdrant` | Sink | Stream messages into Qdrant vector collections |
| Delta Lake Sink | `ghcr.io/danube-messaging/danube-sink-deltalake` | Sink | Write messages to Delta Lake tables (S3/Azure/GCS) |
| SurrealDB Sink | `ghcr.io/danube-messaging/danube-sink-surrealdb` | Sink | Insert messages into SurrealDB tables |
| MQTT Source | `ghcr.io/danube-messaging/danube-source-mqtt` | Source | Bridge MQTT topics into Danube |
| Webhook Source | `ghcr.io/danube-messaging/danube-source-webhook` | Source | HTTP endpoints that publish to Danube topics |

## Prerequisites

- A running Danube cluster (`danube-core` chart installed)
- The external dependency for your connector (Qdrant, MinIO, SurrealDB, MQTT broker, etc.)

## Quick Start

Each connector ships with an example values file in `examples/`. Copy the one you
need, edit it for your environment, and install:

```bash
# Install a Qdrant sink connector
helm install qdrant-sink danube/danube-connector -n danube \
  -f examples/sink-qdrant.yaml

# Install a Delta Lake sink connector
helm install deltalake-sink danube/danube-connector -n danube \
  -f examples/sink-deltalake.yaml

# Install a SurrealDB sink connector
helm install surrealdb-sink danube/danube-connector -n danube \
  -f examples/sink-surrealdb.yaml

# Install an MQTT source connector
helm install mqtt-source danube/danube-connector -n danube \
  -f examples/source-mqtt.yaml

# Install a Webhook source connector
helm install webhook-source danube/danube-connector -n danube \
  -f examples/source-webhook.yaml
```

You can install multiple connectors at the same time — each `helm install` creates
an independent release.

## How It Works

Every Danube connector follows the same runtime contract:

1. Read a **TOML config file** from `CONNECTOR_CONFIG_PATH`
2. Connect to the **Danube broker** via `DANUBE_SERVICE_URL`
3. Expose a **metrics port** (default 9090)
4. Accept **secrets via environment variables** (credentials, API keys)

This chart creates:

| Resource | Purpose |
|----------|---------|
| **ConfigMap** | Mounts your `connector.toml` into the container |
| **Deployment** | Runs the connector image with env vars and config |
| **Service** | Exposes the metrics port (and extra ports like webhook HTTP) |
| **Secret** | Stores credentials as Kubernetes secrets (optional) |

## Configuration

### Providing the TOML Config

**Option 1: Inline in values.yaml** (recommended for getting started)

```yaml
config:
  inline: |
    danube_service_url = "http://danube-core-broker:6650"
    connector_name = "my-connector"

    [qdrant]
    url = "http://qdrant:6334"
    # ... rest of connector config
```

**Option 2: Existing ConfigMap** (for managing config separately)

```bash
kubectl create configmap my-connector-config \
  --from-file=connector.toml=my-connector.toml -n danube

helm install my-connector danube/danube-connector -n danube \
  --set image.repository=ghcr.io/danube-messaging/danube-sink-qdrant \
  --set config.existingConfigMap=my-connector-config
```

### Environment Variables

Non-secret environment variables:

```yaml
env:
  CONNECTOR_CONFIG_PATH: /etc/connector.toml
  DANUBE_SERVICE_URL: "http://danube-core-broker:6650"
  CONNECTOR_NAME: "my-connector"
  RUST_LOG: "info"
```

Secret environment variables (stored in a Kubernetes Secret):

```yaml
secretEnv:
  AWS_ACCESS_KEY_ID: "my-key"
  AWS_SECRET_ACCESS_KEY: "my-secret"
```

Or reference an existing secret:

```yaml
existingSecret: "my-existing-secret"
```

### Extra File Mounts

Some connectors need additional files (e.g. JSON schemas for MQTT source):

```yaml
extraFiles:
  schemas:
    mountPath: /etc/schemas
    files:
      sensor-data.json: |
        {"type": "object", "properties": {"device_id": {"type": "string"}}}
```

### Extra Ports (Webhook Source)

The webhook connector exposes an HTTP server. Add extra ports:

```yaml
extraPorts:
  - name: http
    containerPort: 8080
    servicePort: 8080
```

## Example Values Files

Ready-to-use values files are in `examples/`:

| File | Connector | Key Settings |
|------|-----------|-------------|
| `sink-qdrant.yaml` | Qdrant Sink | `QDRANT_URL`, collection mapping, vector dimension |
| `sink-deltalake.yaml` | Delta Lake Sink | S3/MinIO credentials, table path, field mappings |
| `sink-surrealdb.yaml` | SurrealDB Sink | SurrealDB URL, namespace, table mapping |
| `source-mqtt.yaml` | MQTT Source | Broker host/port, topic mappings, schema files |
| `source-webhook.yaml` | Webhook Source | HTTP port, API key auth, endpoint routing |

Copy an example, edit the TOML config and environment variables for your setup,
and install.

## Managing Connectors

```bash
# List installed connectors
helm list -n danube

# Upgrade a connector (e.g. after editing config)
helm upgrade qdrant-sink danube/danube-connector -n danube -f sink-qdrant.yaml

# Check connector logs
kubectl logs -l app.kubernetes.io/instance=qdrant-sink -n danube

# Uninstall a connector
helm uninstall qdrant-sink -n danube
```

## Full Values Reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image (required) | `""` |
| `image.tag` | Image tag | `"latest"` |
| `image.pullPolicy` | Pull policy | `IfNotPresent` |
| `config.inline` | Inline TOML config content | `""` |
| `config.existingConfigMap` | Use an existing ConfigMap | `""` |
| `config.mountPath` | Config file mount path | `/etc/connector.toml` |
| `extraFiles` | Additional file mounts (schemas, etc.) | `{}` |
| `env` | Non-secret environment variables | `{CONNECTOR_CONFIG_PATH: ...}` |
| `secretEnv` | Secret environment variables | `{}` |
| `existingSecret` | Use an existing Kubernetes Secret | `""` |
| `metricsPort` | Prometheus metrics port | `9090` |
| `extraPorts` | Additional ports (e.g. webhook HTTP) | `[]` |
| `service.type` | Service type | `ClusterIP` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `resources.limits.cpu` | CPU limit | `500m` |
| `resources.limits.memory` | Memory limit | `512Mi` |
