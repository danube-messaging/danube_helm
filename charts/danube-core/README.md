# Danube Core Helm Chart

This Helm chart deploys the core components of a Danube messaging cluster on Kubernetes.

## Components

The chart includes the following components:

- **Danube Brokers**: Rust-based messaging brokers with embedded Raft consensus (StatefulSet)
- **Prometheus**: Metrics collection and monitoring (Deployment)
- **Ingress** (optional): HTTP routing to broker admin and metrics endpoints

> **Note**: Metadata is managed by the brokers themselves via embedded Raft consensus
> (openraft). No external metadata store (e.g., ETCD) is required.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PersistentVolume provisioner support in the underlying infrastructure (for production deployments)

## Installation

### Quick Start (Minimal Configuration)

For local development or testing:

```bash
kubectl create namespace danube --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap danube-broker-config \
  --from-file=danube_broker.yml=./charts/danube-core/examples/danube_broker.yml \
  -n danube --dry-run=client -o yaml | kubectl apply -f -
helm install danube-core ./charts/danube-core -n danube --create-namespace \
  -f ./charts/danube-core/examples/values-minimal.yaml
```

### Production Deployment

For production with persistence and high availability:

```bash
kubectl create namespace danube --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap danube-broker-config \
  --from-file=danube_broker.yml=./charts/danube-core/examples/danube_broker.yml \
  -n danube --dry-run=client -o yaml | kubectl apply -f -
helm install danube-core ./charts/danube-core -n danube --create-namespace \
  -f ./charts/danube-core/examples/values-production.yaml
```

### With S3 Cloud Storage

For deployments using S3-compatible storage for WAL:

```bash
# Set up S3 credentials as environment variables or Kubernetes secrets
kubectl create namespace danube --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap danube-broker-config \
  --from-file=danube_broker_cloud.yml=./charts/danube-core/examples/danube_broker_cloud.yml \
  -n danube --dry-run=client -o yaml | kubectl apply -f -
helm install danube-core ./charts/danube-core -n danube --create-namespace \
  -f ./charts/danube-core/examples/values-s3-storage.yaml
```

### Custom Installation

```bash
helm install danube-core ./charts/danube-core --set broker.replicaCount=5
```

### Optional: Prepare Helper Script

You can use the helper script to create the namespace + ConfigMap and print the install command:

```bash
bash ./scripts/prepare_danube_core_release.sh \
  -c ./charts/danube-core/examples/danube_broker.yml
```

## Configuration

The following table lists the configurable parameters of the Danube Core chart and their default values.

### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.clusterName` | Name of the Danube cluster | `danube` |

### Broker Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `broker.replicaCount` | Number of broker replicas | `3` |
| `broker.image.repository` | Broker image repository | `ghcr.io/danube-messaging/danube-broker` |
| `broker.image.tag` | Broker image tag | `v0.7.2` |
| `broker.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `broker.ports.client` | Client port | `6650` |
| `broker.ports.admin` | Admin port | `50051` |
| `broker.ports.prometheus` | Prometheus metrics port | `9040` |
| `broker.ports.raft` | Raft inter-node transport port | `7650` |
| `broker.persistence.enabled` | Enable persistent storage | `true` |
| `broker.persistence.size` | Storage size | `20Gi` |
| `broker.persistence.storageClass` | Storage class | `""` (default) |
| `broker.resources.requests.memory` | Memory request | `1Gi` |
| `broker.resources.requests.cpu` | CPU request | `500m` |
| `broker.resources.limits.memory` | Memory limit | `2Gi` |
| `broker.resources.limits.cpu` | CPU limit | `1000m` |
| `broker.externalAccess.enabled` | Enable external access | `false` |
| `broker.externalAccess.type` | Service type (ClusterIP/NodePort) | `ClusterIP` |
| `broker.tls.enabled` | Enable TLS | `false` |
| `broker.config.existingConfigMap` | Existing ConfigMap with broker config | `danube-broker-config` |
| `broker.config.fileName` | Config file name in ConfigMap | `danube_broker.yml` |

### Prometheus Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `prometheus.enabled` | Enable Prometheus deployment | `true` |
| `prometheus.image.repository` | Prometheus image repository | `prom/prometheus` |
| `prometheus.image.tag` | Prometheus image tag | `v2.53.0` |
| `prometheus.service.port` | Prometheus port | `9090` |
| `prometheus.serviceAccount.create` | Create service account | `true` |
| `prometheus.rbac.create` | Create RBAC resources | `true` |
| `prometheus.resources.requests.memory` | Memory request | `256Mi` |
| `prometheus.resources.requests.cpu` | CPU request | `250m` |

### Ingress Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Ingress hosts configuration | `[]` |
| `ingress.tls` | Ingress TLS configuration | `[]` |

## Accessing the Cluster

### Port Forwarding (Development)

```bash
# Access broker admin API
kubectl port-forward svc/danube-core-broker 50051:50051

# Access Prometheus
kubectl port-forward svc/danube-core-prometheus 9090:9090
```

### Using Ingress (Production)

When ingress is enabled, you can access:
- Admin API: `https://your-domain.com/admin`
- Prometheus: `https://your-domain.com/metrics`

## Connecting Clients

Clients should connect to the broker service:

```bash
# Internal cluster connection
danube-core-broker-headless.default.svc.cluster.local:6650

# Or use the load-balanced service
danube-core-broker.default.svc.cluster.local:6650
```

## Monitoring

Prometheus automatically discovers and scrapes metrics from all broker pods. Access the Prometheus UI to view metrics:

```bash
kubectl port-forward svc/danube-core-prometheus 9090:9090
```

Then open `http://localhost:9090` in your browser.

## Upgrading

```bash
helm upgrade danube-core ./charts/danube-core -f your-values.yaml
```

## Uninstalling

```bash
helm uninstall danube-core
```

**Note**: PersistentVolumeClaims are not automatically deleted. Clean them up manually if needed:

```bash
kubectl delete pvc -l app.kubernetes.io/name=danube-core
```

## Configuration Examples

### Example 1: Minimal Local Setup

See `examples/values-minimal.yaml` for a lightweight configuration suitable for local development.

Create the ConfigMap from the example broker config:

```bash
kubectl create configmap danube-broker-config \
  --from-file=danube_broker.yml=./charts/danube-core/examples/danube_broker.yml \
  -n danube --dry-run=client -o yaml | kubectl apply -f -
```

### Example 2: Production with HA

See `examples/values-production.yaml` for a production-ready configuration with:
- 3 broker replicas with embedded Raft consensus
- Persistent storage
- Resource limits
- Ingress with TLS

### Example 3: S3 Cloud Storage

See `examples/values-s3-storage.yaml` for configuration with S3-compatible cloud storage for write-ahead logs.

Create the ConfigMap using the cloud broker config (edit it for your cloud credentials):

```bash
kubectl create configmap danube-broker-config \
  --from-file=danube_broker_cloud.yml=./charts/danube-core/examples/danube_broker_cloud.yml \
  -n danube --dry-run=client -o yaml | kubectl apply -f -
```

## Scaling the Cluster

Brokers auto-detect whether they are joining an existing cluster or bootstrapping a new one.
During peer discovery, each fresh node checks if any seed peer already has an elected Raft leader.
If so, the node enters **join mode** automatically (registers as "drained") and waits to be
added to the Raft group via the admin CLI.

### Scale Up (e.g., 3 → 5 brokers)

```bash
# 1. Increase replica count — new pods auto-detect the existing cluster
helm upgrade danube-core ./charts/danube-core -n danube \
  --set broker.replicaCount=5

# 2. Wait for new pods to start (they will log "entering join mode")
kubectl get pods -n danube -w

# 3. Add each new node to the Raft cluster
danube-admin cluster add-node --node-addr http://danube-core-broker-3.<headless>:7650
danube-admin cluster add-node --node-addr http://danube-core-broker-4.<headless>:7650

# 4. Promote new nodes to voters
danube-admin cluster promote-node --node-id <ID3>
danube-admin cluster promote-node --node-id <ID4>

# 5. Activate the brokers so they accept topics
danube-admin brokers activate --broker-id <ID3>
danube-admin brokers activate --broker-id <ID4>

# 6. Optionally rebalance topics across all brokers
danube-admin brokers rebalance
```

### Scale Down (e.g., 5 → 3 brokers)

Remove nodes from the Raft group **before** reducing replicas:

```bash
# 1. Remove brokers from Raft membership
danube-admin cluster remove-node --node-id <ID4>
danube-admin cluster remove-node --node-id <ID3>

# 2. Scale down the StatefulSet
helm upgrade danube-core ./charts/danube-core -n danube \
  --set broker.replicaCount=3
```

### Replace a Failed Pod (PVC lost)

If a pod's PVC is destroyed, it starts with a new `node_id` and auto-detects the existing
cluster. The old node must be removed from Raft membership first:

```bash
# 1. Remove the stale node from Raft
danube-admin cluster remove-node --node-id <OLD_ID>

# 2. Delete the broken PVC and pod (StatefulSet recreates them)
kubectl delete pvc data-danube-core-broker-<N> -n danube
kubectl delete pod danube-core-broker-<N> -n danube

# 3. Add the replacement node (new node_id) via the standard scale-up steps
danube-admin cluster add-node --node-addr http://danube-core-broker-<N>.<headless>:7650
danube-admin cluster promote-node --node-id <NEW_ID>
danube-admin brokers activate --broker-id <NEW_ID>
```

## Troubleshooting

### Pods not starting

Check pod logs:
```bash
kubectl logs -l app.kubernetes.io/component=broker
```

### Broker connectivity issues

Verify broker configuration:
```bash
kubectl describe configmap danube-core-broker-config
```

Check service endpoints:
```bash
kubectl get endpoints danube-core-broker
```

### Storage issues

Check PVC status:
```bash
kubectl get pvc -l app.kubernetes.io/name=danube-core
```

## Architecture

The chart creates the following resources:

```
┌─────────────────────────────────────────────┐
│              Ingress (optional)             │
│         /admin → broker, /metrics → prom    │
└─────────────────────────────────────────────┘
                      ▲
                      │
    ┌─────────────────┼─────────────────┐
    │                 │                 │
┌───▼────┐    ┌───────▼──────┐   ┌─────▼──────┐
│ Broker │    │ Broker       │   │ Prometheus │
│ Pod 0  │◄──►│ Service      │   │            │
├────────┤    │ (ClusterIP)  │   │ Scrapes    │
│ Broker │    └──────────────┘   │ Brokers    │
│ Pod 1  │◄──►                   └────────────┘
├────────┤    ┌──────────────┐
│ Broker │    │ Broker       │
│ Pod 2  │◄──►│ Headless Svc │
└────────┘    │ (StatefulSet)│
  Embedded    └──────────────┘
  Raft ◄─►  Peer-to-peer via
  Consensus   headless DNS
              (port 7650)
```

## Support

For issues and questions:
- GitHub: https://github.com/danube-messaging/danube
- Documentation: https://danube-docs.dev-state.com/

## License

This chart is licensed under the Apache License 2.0.
