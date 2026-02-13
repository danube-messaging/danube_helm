# Danube Helm Charts

Modular Helm charts for deploying Danube messaging platform on Kubernetes.

## Chart Structure

This repository provides a modular approach to deploying Danube:

- **`danube-core`**: Core components (3 brokers, ETCD, Prometheus) - required foundation
- **Additional charts** (coming soon): Admin UI, connectors (Qdrant, DeltaLake, SurrealDB, MQTT, Webhook)

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PersistentVolume provisioner support (for production deployments)

## Quick Start

### Install Core Components

```sh
# Minimal local setup
helm install danube ./charts/danube-core -f ./charts/danube-core/examples/values-minimal.yaml

# Production setup with HA
helm install danube ./charts/danube-core -f ./charts/danube-core/examples/values-production.yaml
```

### Add Optional Components (Coming Soon)

```sh
# Install Admin UI
helm install danube-admin ./charts/danube-admin

# Install connectors as needed
helm install danube-qdrant ./charts/danube-qdrant-connector
```

## Documentation

For detailed configuration options, see the chart-specific documentation:

- **[Danube Core Chart](charts/danube-core/README.md)**: Complete reference for all configuration parameters

## Common Configuration Patterns

### Customize Broker Replicas

```sh
helm install danube ./charts/danube-core --set broker.replicaCount=5
```

### Enable Ingress

```sh
helm install danube ./charts/danube-core \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=danube.example.com
```

### Configure Resource Limits

```sh
helm install danube ./charts/danube-core \
  --set broker.resources.requests.memory=2Gi \
  --set broker.resources.limits.memory=4Gi
```

### Use Custom Values File

```sh
helm install danube ./charts/danube-core -f my-custom-values.yaml
```

## Uninstallation

To uninstall the Danube release:

```sh
helm uninstall danube
```

This command removes all the Kubernetes components associated with the chart and deletes the release.

**Note**: PersistentVolumeClaims are not automatically deleted. Clean them up manually if needed:

```sh
kubectl delete pvc -l app.kubernetes.io/name=danube-core
```

## Troubleshooting

Get pod status:

```sh
kubectl get pods -l app.kubernetes.io/name=danube-core
```

View logs:

```sh
# Broker logs
kubectl logs -l app.kubernetes.io/component=broker

# ETCD logs
kubectl logs -l app.kubernetes.io/component=etcd

# Prometheus logs
kubectl logs -l app.kubernetes.io/component=prometheus
```

For detailed troubleshooting, see the [Danube Core Chart Documentation](charts/danube-core/README.md#troubleshooting).

## License

This Helm chart is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for more details.
