# Danube Cluster Helm Chart

This Helm chart deploys the Danube Cluster with ETCD as metadata storage in the same namespace.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+

## Installation

### Add Helm Repository

First, add the repository to your Helm client:

```sh
helm repo add danube https://danube-messaging.github.io/danube_helm
helm repo update
```

### Install the Helm Chart

You can install the chart with the release name `my-danube-cluster` using the following command:

```sh
helm install my-danube-cluster danube/danube-helm-chart
```

This will deploy the Danube Broker and an ETCD instance with the default configuration.

## Configuration

### ETCD Configuration

The following table lists the configurable parameters of the ETCD chart and their default values.

| Parameter                   | Description                        | Default               |
|-----------------------------|------------------------------------|-----------------------|
| `etcd.enabled`              | Enable or disable ETCD deployment  | `true`                |
| `etcd.replicaCount`         | Number of ETCD instances           | `1`                   |
| `etcd.image.repository`     | ETCD image repository              | `bitnami/etcd`        |
| `etcd.image.tag`            | ETCD image tag                     | `latest`              |
| `etcd.image.pullPolicy`     | ETCD image pull policy             | `IfNotPresent`        |
| `etcd.service.type`         | ETCD service type                  | `ClusterIP`           |
| `etcd.service.port`         | ETCD service port                  | `2379`                |

### Broker Configuration

The following table lists the configurable parameters of the Danube Broker chart and their default values.

| Parameter                     | Description                          | Default                                |
|-------------------------------|--------------------------------------|----------------------------------------|
| `broker.replicaCount`         | Number of broker instances           | `1`                                    |
| `broker.image.repository`     | Broker image repository              | `ghcr.io/your-username/danube-broker`  |
| `broker.image.tag`            | Broker image tag                     | `latest`                               |
| `broker.image.pullPolicy`     | Broker image pull policy             | `IfNotPresent`                         |
| `broker.service.type`         | Broker service type                  | `ClusterIP`                            |
| `broker.service.port`         | Broker service port                  | `6650`                                 |
| `broker.resources.limits.cpu` | CPU limit for broker container       | `500m`                                 |
| `broker.resources.limits.memory` | Memory limit for broker container | `512Mi`                                |
| `broker.resources.requests.cpu` | CPU request for broker container   | `200m`                                 |
| `broker.resources.requests.memory` | Memory request for broker container | `256Mi`                            |
| `broker.env.RUST_LOG`         | Rust log level for broker            | `danube_broker=trace`                  |
| `broker.brokerAddr`           | Broker address                       | `0.0.0.0:6650`                         |
| `broker.clusterName`          | Cluster name                         | `MY_CLUSTER`                           |
| `broker.metaStoreAddr`        | Metadata store address               | `etcd:2379`                            |

You can override the default values by providing a custom `values.yaml` file:

```sh
helm install my-danube-cluster danube/danube-helm-chart -f custom-values.yaml
```

Alternatively, you can specify individual values using the `--set` flag:

```sh
helm install my-danube-cluster danube/danube-helm-chart --set broker.replicaCount=2 --set broker.brokerAddr="0.0.0.0:6651"
```

## Resource consideration

Pay attention to resource allocation, the default configuration is just OK for testing.

For production environment you may want to increase.

### Sizing for Production

**Small to Medium Load**:

CPU Requests: 500m to 1 CPU
CPU Limits: 1 CPU to 2 CPUs
Memory Requests: 512Mi to 1Gi
Memory Limits: 1Gi to 2Gi

**Heavy Load:**
CPU Requests: 1 CPU to 2 CPUs
CPU Limits: 2 CPUs to 4 CPUs
Memory Requests: 1Gi to 2Gi
Memory Limits: 2Gi to 4Gi

## Uninstallation

To uninstall the `my-danube-cluster` release:

```sh
helm uninstall my-danube-cluster
```

This command removes all the Kubernetes components associated with the chart and deletes the release.

## Troubleshooting

To get the status of the ETCD and Broker pods:

```sh
kubectl get pods -l app=etcd
kubectl get pods -l app=broker
```

To view the logs of a specific broker pod:

```sh
kubectl logs <broker-pod-name>
```

## License

This Helm chart is licensed under the Apache 2.0 License. See the [LICENSE](LICENSE) file for more details.
