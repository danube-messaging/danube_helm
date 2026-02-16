# Setup Danube on a Local Kubernetes Cluster

This guide deploys a 3-broker Danube cluster with an Envoy proxy on a local
[Kind](https://kind.sigs.k8s.io/) cluster and tests producer/consumer connectivity.

The deployment uses two Helm charts:
- **danube-envoy** — Envoy gRPC proxy (installed first to get the proxy address)
- **danube-core** — Brokers, etcd, Prometheus (installed with proxy address)

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [danube-cli](https://github.com/danube-messaging/danube) (for testing)

## 1. Create the Kind Cluster

```bash
kind create cluster
kubectl cluster-info --context kind-kind
```

## Quick Alternative: Helper Script

If you cloned this repository, you can run steps 2–4 with a single command:

```bash
./scripts/prepare_danube_core_release.sh \
  -c ./charts/danube-core/examples/danube_broker.yml
```

The script creates the namespace, installs the Envoy proxy, discovers the proxy
address, creates the broker ConfigMap, and prints the `helm install` command for
`danube-core`. Run `./scripts/prepare_danube_core_release.sh --help` for options.

If you prefer to run each step manually, continue below.

## 2. Install the Envoy Proxy

Install the proxy first so you can discover the external address before deploying
the brokers.

```bash
kubectl create namespace danube
helm install danube-envoy ./charts/danube-envoy -n danube
```

Wait for the proxy pod to become ready:

```bash
kubectl get pods -n danube -w
```

## 3. Discover the Proxy Address

```bash
PROXY_PORT=$(kubectl get svc danube-envoy -n danube \
  -o jsonpath='{.spec.ports[?(@.name=="grpc")].nodePort}')
NODE_IP=$(kubectl get nodes \
  -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Proxy address: ${NODE_IP}:${PROXY_PORT}"
```

Save this address — you will use it for both the broker `connectUrl` and for
`danube-cli` connections.

## 4. Install Danube Core

Create the broker ConfigMap and install the chart with the proxy address:

```bash
kubectl create configmap danube-broker-config \
  --from-file=danube_broker.yml=./charts/danube-core/examples/danube_broker.yml \
  -n danube

helm install danube-core ./charts/danube-core -n danube \
  -f ./charts/danube-core/examples/values-minimal.yaml \
  --set broker.externalAccess.connectUrl="${NODE_IP}:${PROXY_PORT}"
```

This deploys:
- **3 broker pods** (StatefulSet) with persistence enabled
- **1 etcd pod** for metadata storage
- **1 Prometheus pod** for metrics

Brokers start in proxy mode from the beginning — no upgrade or restart needed.

Wait for all pods to become ready:

```bash
kubectl get pods -n danube -w
```

> **Note**: The first broker pod may restart a few times (`CrashLoopBackOff`)
> while waiting for etcd to become ready. This is normal — Kubernetes will keep
> restarting it until etcd accepts connections, then the remaining brokers start
> cleanly.

## 5. Verify the Installation

```bash
kubectl get pods -n danube
```

Expected output (all Running):

```
NAME                                      READY   STATUS    AGE
danube-core-broker-0                      1/1     Running   2m
danube-core-broker-1                      1/1     Running   2m
danube-core-broker-2                      1/1     Running   2m
danube-core-etcd-0                        1/1     Running   2m
danube-core-prometheus-xxxxxxxxx          1/1     Running   2m
danube-envoy-xxxxxxxxx                    1/1     Running   5m
```

Verify brokers registered with proxy mode:

```bash
kubectl logs danube-core-broker-0 -n danube | grep "broker registered"
```

You should see different `broker_url` per pod and a shared `connect_url` pointing
to the proxy address, for example:

```
broker registered broker_url=http://danube-core-broker-0.danube-core-broker-headless.danube.svc.cluster.local:6650 connect_url=http://172.19.0.2:30445
```

## 6. Test Producer and Consumer

Use the proxy address discovered in step 3:

**Terminal 1 — Produce messages:**

```bash
danube-cli produce \
  -s http://${NODE_IP}:${PROXY_PORT} \
  -t /default/test_topic \
  -m "Hello from Danube" -c 5
```

**Terminal 2 — Consume messages:**

```bash
danube-cli consume \
  -s http://${NODE_IP}:${PROXY_PORT} \
  -t /default/test_topic \
  -m test_sub
```

Then produce more messages in terminal 1 — the consumer should receive them in
real time.

## 7. Install the Web Dashboard (optional)

The `danube-ui` chart adds a web dashboard for cluster monitoring, topic
management, and schema registry browsing.

```bash
helm install danube-ui ./charts/danube-ui -n danube
```

Wait for the pods to be ready:

```bash
kubectl get pods -n danube -l app.kubernetes.io/name=danube-ui
```

You should see two pods — the admin API server and the frontend:

```
NAME                                  READY   STATUS    AGE
danube-ui-admin-xxxxxxxxx             1/1     Running   30s
danube-ui-frontend-xxxxxxxxx          1/1     Running   30s
```

Forward the UI port to your local machine:

```bash
kubectl port-forward svc/danube-ui-frontend 8081:80 -n danube
```

Open **http://localhost:8081** in your browser.

> **Note**: The admin server connects to `danube-core-broker:50051` and
> `danube-core-prometheus:9090` by default. If you used a different release name
> for danube-core, override with:
> ```bash
> helm install danube-ui ./charts/danube-ui -n danube \
>   --set admin.config.brokerEndpoint="<release>-broker:50051" \
>   --set admin.config.prometheusUrl="http://<release>-prometheus:9090"
> ```

## How Proxy Mode Works

In a multi-broker cluster, topics are assigned to specific brokers. When a client
connects, it may need to be redirected to the broker that owns its topic.

- Each broker advertises a per-pod **`broker_url`** (internal headless DNS) and a
  shared **`connect_url`** (the Envoy proxy address).
- The client always connects to the proxy (`connect_url`).
- The client first does a **topic lookup** (round-robined to any broker) to
  discover which broker owns the topic.
- On subsequent gRPC calls, the client sends an **`x-danube-broker-url`** metadata
  header with the target broker's internal address.
- Envoy's **Dynamic Forward Proxy** reads this header, resolves the broker's
  headless DNS name inside the cluster, and routes the request to the correct pod.

## Inspect etcd (optional)

```bash
kubectl port-forward svc/danube-core-etcd 2379:2379 -n danube
etcdctl --endpoints=http://localhost:2379 get --prefix /
```

## Access Prometheus (optional)

```bash
kubectl port-forward svc/danube-core-prometheus 9090:9090 -n danube
```

Open `http://localhost:9090` in your browser.

## Troubleshooting

### Broker pods stuck in ContainerCreating

On first install, Kind must pull the broker image (`~50MB`). This can take 1-2
minutes depending on your connection. Check progress with:

```bash
kubectl describe pod danube-core-broker-0 -n danube | tail -5
```

### Envoy proxy not routing correctly

Enable debug logging temporarily to see request routing decisions:

```bash
kubectl exec deployment/danube-envoy -n danube -- \
  wget -qO- http://localhost:9901/logging?level=debug
```

Check logs for `cluster '...' match for URL` lines to see which cluster each
request is routed to. Revert with `level=info`.

## Install from Helm Repository

Instead of installing from the local chart, you can use the published Helm repo:

```bash
helm repo add danube https://danrusei.github.io/danube_helm
helm repo update

kubectl create namespace danube
helm install danube-envoy danube/danube-envoy -n danube

# Discover proxy address (same as step 3 above)
PROXY_PORT=$(kubectl get svc danube-envoy -n danube \
  -o jsonpath='{.spec.ports[?(@.name=="grpc")].nodePort}')
NODE_IP=$(kubectl get nodes \
  -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

kubectl create configmap danube-broker-config \
  --from-file=danube_broker.yml=danube_broker.yml \
  -n danube

helm install danube-core danube/danube-core -n danube \
  -f values-minimal.yaml \
  --set broker.externalAccess.connectUrl="${NODE_IP}:${PROXY_PORT}"
```

## Cleanup

```bash
helm uninstall danube-ui -n danube    # if installed
helm uninstall danube-core -n danube
helm uninstall danube-envoy -n danube
kubectl delete namespace danube
kind delete cluster
```
