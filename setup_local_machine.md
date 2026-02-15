# Setup Danube on a Local Kubernetes Cluster

This guide shows how to deploy Danube on a local [Kind](https://kind.sigs.k8s.io/) cluster
and connect to it from your machine.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)

## 1. Create the Kind Cluster

```bash
kind create cluster
kubectl cluster-info --context kind-kind
```

## 2. Install Danube

### Create the namespace and broker ConfigMap

The broker configuration is provided via a ConfigMap created from the example config file:

```bash
kubectl create namespace danube
kubectl create configmap danube-broker-config \
  --from-file=danube_broker.yml=./charts/danube-core/examples/danube_broker.yml \
  -n danube
```

### Option A: Minimal Setup (1 broker, local development)

Best for getting started. Uses 1 broker, no persistence, no ingress.

```bash
helm install danube-core ./charts/danube-core -n danube \
  -f ./charts/danube-core/examples/values-minimal.yaml
```

Access the broker via port-forward:

```bash
kubectl port-forward svc/danube-core-broker 6650:6650 -n danube
```

Your client connects to `http://localhost:6650`. Since there is only 1 broker,
no redirects happen and port-forward is sufficient.

### Option B: Multi-Broker with Ingress (proxy mode)

For multi-broker deployments, external clients connect through an nginx ingress
that routes gRPC traffic to the correct broker pod. This is called **proxy mode**:

- Each broker advertises a per-pod `broker_url` (headless DNS, internal identity)
  and a shared `connect_url` (the ingress address).
- The client sends an `x-danube-broker-url` gRPC metadata header on every RPC.
- The nginx ingress uses `upstream-hash-by` on this header to route consistently
  to the same backend pod.

#### Install the NGINX Ingress Controller

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --set controller.service.type=NodePort \
  --set controller.config.http2=true
```

Find the assigned NodePort for HTTP (port 80):

```bash
kubectl get svc nginx-ingress-ingress-nginx-controller \
  -o jsonpath='{.spec.ports[?(@.port==80)].nodePort}'
```

Note this port (e.g., `30115`).

#### Get the Kind node IP

```bash
kubectl get nodes -o wide
# Use the INTERNAL-IP (e.g., 172.20.0.2)
```

Add the ingress host to `/etc/hosts`:

```bash
# Replace 172.20.0.2 with your node's INTERNAL-IP
echo "172.20.0.2 broker.local" | sudo tee -a /etc/hosts
```

#### Deploy with proxy mode

```bash
helm install danube-core ./charts/danube-core -n danube \
  -f ./charts/danube-core/examples/values-minimal.yaml \
  --set broker.replicaCount=3 \
  --set broker.externalAccess.connectUrl="broker.local:30115" \
  --set ingress.enabled=true \
  --set 'ingress.hosts[0].host=broker.local' \
  --set 'ingress.hosts[0].paths[0].path=/' \
  --set 'ingress.hosts[0].paths[0].pathType=ImplementationSpecific' \
  --set 'ingress.hosts[0].paths[0].servicePort=client'
```

Your client connects to `http://broker.local:30115`.

> **Note**: Proxy mode requires a broker image that supports the `--connect-url` CLI flag.
> Without it, the broker sets both `broker_url` and `connect_url` to the same internal
> address, and external clients cannot reach redirected brokers.

### Option C: Install from Helm Repository

```bash
helm repo add danube https://danrusei.github.io/danube_helm
helm repo update

kubectl create namespace danube
kubectl create configmap danube-broker-config \
  --from-file=danube_broker.yml=./charts/danube-core/examples/danube_broker.yml \
  -n danube

helm install danube-core danube/danube-core -n danube \
  -f ./charts/danube-core/examples/values-minimal.yaml
```

## 3. Verify the Installation

Check that pods are running:

```bash
kubectl get pods -n danube

NAME                                  READY   STATUS    RESTARTS   AGE
danube-core-broker-0                  1/1     Running   0          2m
danube-core-etcd-0                    1/1     Running   0          2m
danube-core-prometheus-xxxxxxxxx      1/1     Running   0          2m
```

Check services:

```bash
kubectl get svc -n danube

NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
danube-core-broker           ClusterIP   10.96.40.244    <none>        6650/TCP,50051/TCP,9040/TCP  2m
danube-core-broker-headless  ClusterIP   None            <none>        6650/TCP,50051/TCP,9040/TCP  2m
danube-core-etcd             ClusterIP   10.96.232.70    <none>        2379/TCP                     2m
danube-core-etcd-headless    ClusterIP   None            <none>        2379/TCP,2380/TCP            2m
danube-core-prometheus       ClusterIP   10.96.100.50    <none>        9090/TCP                     2m
```

Check broker logs:

```bash
kubectl logs danube-core-broker-0 -n danube
```

## 4. Inspect etcd (optional)

Port-forward the etcd service:

```bash
kubectl port-forward svc/danube-core-etcd 2379:2379 -n danube
```

Then query with etcdctl:

```bash
etcdctl --endpoints=http://localhost:2379 get --prefix /
```

## 5. Access Prometheus (optional)

```bash
kubectl port-forward svc/danube-core-prometheus 9090:9090 -n danube
```

Open `http://localhost:9090` in your browser.

## Resource Sizing

The minimal configuration is suitable for testing. For production:

**Small to Medium Load:**
- CPU: 500m–1 request, 1–2 limit
- Memory: 512Mi–1Gi request, 1–2Gi limit

**Heavy Load:**
- CPU: 1–2 request, 2–4 limit
- Memory: 1–2Gi request, 2–4Gi limit

## Cleanup

```bash
helm uninstall danube-core -n danube
kubectl delete namespace danube
kind delete cluster
```
