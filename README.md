# Danube Helm Charts

Modular Helm charts for deploying [Danube](https://github.com/danube-messaging/danube) messaging platform on Kubernetes.

## Charts

| Chart | Description |
|-------|-------------|
| **[danube-envoy](charts/danube-envoy/)** | Envoy gRPC proxy for routing clients to the correct broker |
| **[danube-core](charts/danube-core/)** | Core components: brokers (StatefulSet), etcd, Prometheus |
| **[danube-ui](charts/danube-ui/)** | Admin server + web dashboard for cluster monitoring |

Additional charts (coming soon): connectors (Qdrant, DeltaLake, SurrealDB, MQTT, Webhook).

## Repository Structure

```
charts/
├── danube-envoy/        # Envoy gRPC proxy (Deployment + NodePort/LoadBalancer)
├── danube-core/         # Brokers, etcd, Prometheus
│   └── examples/        # Broker configs + values-minimal.yaml for Kind
└── danube-ui/           # Admin server + web dashboard
scripts/                 # Helper scripts
setup_local_machine.md   # Step-by-step local deployment guide
```

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- PersistentVolume provisioner support (for production deployments)

## Quick Start

The deployment uses two charts: install the proxy first, discover its address,
then install the core with that address.

> **Shortcut**: If you cloned this repo, run
> `./scripts/prepare_danube_core_release.sh -c ./charts/danube-core/examples/danube_broker.yml`
> to automate steps 1–3 below. See `--help` for options.

### 1. Install the Envoy Proxy

```sh
kubectl create namespace danube
helm install danube-envoy ./charts/danube-envoy -n danube
```

### 2. Discover the Proxy Address

```sh
PROXY_PORT=$(kubectl get svc danube-envoy -n danube \
  -o jsonpath='{.spec.ports[?(@.name=="grpc")].nodePort}')
NODE_IP=$(kubectl get nodes \
  -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Proxy address: ${NODE_IP}:${PROXY_PORT}"
```

### 3. Install Danube Core

```sh
kubectl create configmap danube-broker-config \
  --from-file=danube_broker.yml=./charts/danube-core/examples/danube_broker.yml \
  -n danube

helm install danube-core ./charts/danube-core -n danube \
  -f ./charts/danube-core/examples/values-minimal.yaml \
  --set broker.externalAccess.connectUrl="${NODE_IP}:${PROXY_PORT}"
```

### 4. Test

```sh
danube-cli produce -s http://${NODE_IP}:${PROXY_PORT} \
  -t /default/test_topic -m "Hello from Danube" -c 5
```

For the full walkthrough (Kind cluster setup, verification, consumer testing),
see **[setup_local_machine.md](setup_local_machine.md)**.

### 5. Add the Web Dashboard (optional)

```sh
helm install danube-ui ./charts/danube-ui -n danube
kubectl port-forward svc/danube-ui-frontend 8081:80 -n danube
```

Open **http://localhost:8081** for real-time cluster status, topic management, and
schema registry browsing.

## Documentation

- **[Setup Local Machine](setup_local_machine.md)** — Complete local deployment guide with Kind
- **[Danube Core Chart](charts/danube-core/README.md)** — Configuration reference for brokers, etcd, Prometheus
- **[Envoy Proxy Example](charts/danube-envoy/examples/envoy-proxy.yaml)** — Reference for custom Envoy configurations

## Common Configuration Patterns

### Customize Broker Replicas

```sh
helm install danube-core ./charts/danube-core -n danube \
  --set broker.replicaCount=5
```

### Configure Resource Limits

```sh
helm install danube-core ./charts/danube-core -n danube \
  --set broker.resources.requests.memory=2Gi \
  --set broker.resources.limits.memory=4Gi
```

### Use Custom Envoy Configuration

```sh
# Create a ConfigMap from your custom config
kubectl create configmap my-envoy-config \
  --from-file=envoy.yaml=my-envoy.yaml -n danube

# Install with the custom ConfigMap
helm install danube-envoy ./charts/danube-envoy -n danube \
  --set existingConfigMap=my-envoy-config
```

### Use Custom Values File

```sh
helm install danube-core ./charts/danube-core -n danube \
  -f my-custom-values.yaml
```

## Uninstallation

```sh
helm uninstall danube-ui -n danube   # if installed
helm uninstall danube-core -n danube
helm uninstall danube-envoy -n danube
```

**Note**: PersistentVolumeClaims are not automatically deleted. Clean them up
by deleting the namespace:

```sh
kubectl delete namespace danube
```

## Troubleshooting

Get pod status:

```sh
kubectl get pods -n danube
```

View logs:

```sh
# Broker logs
kubectl logs -l app.kubernetes.io/component=broker -n danube

# ETCD logs
kubectl logs -l app.kubernetes.io/component=etcd -n danube

# Envoy proxy logs
kubectl logs -l app.kubernetes.io/name=danube-envoy -n danube

# Admin server logs
kubectl logs -l app.kubernetes.io/component=admin -n danube
```

For more details, see the [Troubleshooting section](setup_local_machine.md#troubleshooting) in the setup guide.

## License

This Helm chart is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for more details.
