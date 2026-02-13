# Danube Core Helm Chart

This Helm chart deploys the core components of a Danube messaging cluster on Kubernetes.

## Components

The chart includes the following components:

- **Danube Brokers**: Rust-based messaging brokers (StatefulSet)
- **ETCD**: Distributed key-value store for metadata (StatefulSet)
- **Prometheus**: Metrics collection and monitoring (Deployment)
- **Ingress** (optional): HTTP routing to broker admin and metrics endpoints

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PersistentVolume provisioner support in the underlying infrastructure (for production deployments)

## Installation

### Quick Start (Minimal Configuration)

For local development or testing:

```bash
kubectl apply -n danube -f ./charts/danube-core/quickstart/configmap-broker.yaml
helm install danube-core ./charts/danube-core -n danube --create-namespace \
  -f ./charts/danube-core/quickstart/values-minimal.yaml
```

### Production Deployment

For production with persistence and high availability:

```bash
kubectl apply -n danube -f ./charts/danube-core/quickstart/configmap-broker.yaml
helm install danube-core ./charts/danube-core -n danube --create-namespace \
  -f ./charts/danube-core/quickstart/values-production.yaml
```

### With S3 Cloud Storage

For deployments using S3-compatible storage for WAL:

```bash
# Set up S3 credentials as environment variables or Kubernetes secrets
kubectl apply -n danube -f ./charts/danube-core/quickstart/configmap-broker-cloud.yaml
helm install danube-core ./charts/danube-core -n danube --create-namespace \
  -f ./charts/danube-core/quickstart/values-s3-storage.yaml
```

### Custom Installation

```bash
helm install danube-core ./charts/danube-core --set broker.replicaCount=5 --set etcd.replicaCount=3
```

### Optional: Prepare Helper Script

You can use the helper script to create the ConfigMap and print the install command:

```bash
bash ./scripts/prepare_danube_core_release.sh \
  -c ./charts/danube-core/quickstart/danube_broker.yml
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

### ETCD Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `etcd.replicaCount` | Number of ETCD replicas | `3` |
| `etcd.image.repository` | ETCD image repository | `quay.io/coreos/etcd` |
| `etcd.image.tag` | ETCD image tag | `v3.5.9` |
| `etcd.image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `etcd.service.port` | Client port | `2379` |
| `etcd.service.peerPort` | Peer port | `2380` |
| `etcd.persistence.enabled` | Enable persistent storage | `true` |
| `etcd.persistence.size` | Storage size | `10Gi` |
| `etcd.persistence.storageClass` | Storage class | `""` (default) |
| `etcd.resources.requests.memory` | Memory request | `512Mi` |
| `etcd.resources.requests.cpu` | CPU request | `250m` |
| `etcd.resources.limits.memory` | Memory limit | `1Gi` |
| `etcd.resources.limits.cpu` | CPU limit | `500m` |

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

See `quickstart/values-minimal.yaml` for a lightweight configuration suitable for local development.

Create the ConfigMap from the example broker config:

```bash
kubectl apply -n danube -f ./charts/danube-core/quickstart/configmap-broker.yaml
```

### Example 2: Production with HA

See `quickstart/values-production.yaml` for a production-ready configuration with:
- 3 broker replicas
- 3 ETCD replicas
- Persistent storage
- Resource limits
- Ingress with TLS

### Example 3: S3 Cloud Storage

See `quickstart/values-s3-storage.yaml` for configuration with S3-compatible cloud storage for write-ahead logs.

Create the ConfigMap using the cloud broker config (edit it for your cloud credentials):

```bash
kubectl apply -n danube -f ./charts/danube-core/quickstart/configmap-broker-cloud.yaml
```

## Troubleshooting

### Pods not starting

Check pod logs:
```bash
kubectl logs -l app.kubernetes.io/component=broker
kubectl logs -l app.kubernetes.io/component=etcd
```

### ETCD cluster issues

Check ETCD cluster health:
```bash
kubectl exec -it danube-core-etcd-0 -- etcdctl endpoint health
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
│ Pod 0  │    │ Service      │   │            │
├────────┤    │ (ClusterIP)  │   │ Scrapes    │
│ Broker │    └──────────────┘   │ Brokers    │
│ Pod 1  │                       └────────────┘
├────────┤                              │
│ Broker │                              │
│ Pod 2  │    ┌──────────────┐          │
└────┬───┘    │ Broker       │          │
     │        │ Headless Svc │          │
     │        │ (StatefulSet)│          │
     │        └──────────────┘          │
     │                                  │
     │        ┌──────────────┐          │
     └────────► ETCD         ◄──────────┘
              │ StatefulSet  │
              │ (3 replicas) │
              └──────────────┘
```

## Support

For issues and questions:
- GitHub: https://github.com/danube-messaging/danube
- Documentation: https://danube-messaging.io

## License

This chart is licensed under the Apache License 2.0.
