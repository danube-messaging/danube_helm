# Setup Danube on the kubernetes cluster

The below process shows how to install Danube on the local machine

## Create the cluster with [kind](https://kind.sigs.k8s.io/)

[Kind](https://github.com/kubernetes-sigs/kind) is a tool for running local Kubernetes clusters using Docker container “nodes”.

```bash
kind create cluster
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.30.0) 🖼
 ✓ Preparing nodes 📦  
 ✓ Writing configuration 📜 
 ✓ Starting control-plane 🕹️ 
 ✓ Installing CNI 🔌 
 ✓ Installing StorageClass 💾 
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind
```

## Install the Ngnix Ingress controller

Using the Official NGINX Ingress Helm Chart

You can install the NGINX Ingress Controller using Helm:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

You can expose the NGINX Ingress controller using a NodePort service so that traffic from the local machine (outside the cluster) can reach the Ingress controller.

```bash
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --set controller.service.type=NodePort
```

You can find out which port is assigned by running

```bash
kubectl get svc

NAME                                               TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
kubernetes                                         ClusterIP   10.96.0.1       <none>        443/TCP                      4m17s
nginx-ingress-ingress-nginx-controller             NodePort    10.96.245.118   <none>        80:30115/TCP,443:30294/TCP   2m58s
nginx-ingress-ingress-nginx-controller-admission   ClusterIP   10.96.169.82    <none>        443/TCP                      2m58s
```

If ngnix is running as NodePort (usually for testing), you need local port in this case **30115**, in order to provide to danube_helm installation.

## Install Danube PubSub

### Option 1: Install from Local Chart (Development)

For local development, install directly from the chart directory:

```sh
# Minimal setup for testing (1 broker, no persistence)
kubectl create namespace danube --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n danube -f ./charts/danube-core/quickstart/configmap-broker.yaml
helm install danube-core ./charts/danube-core -n danube --create-namespace \
  -f ./charts/danube-core/quickstart/values-minimal.yaml

# Production setup (3 brokers, persistence enabled)
kubectl create namespace danube --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n danube -f ./charts/danube-core/quickstart/configmap-broker.yaml
helm install danube-core ./charts/danube-core -n danube --create-namespace \
  -f ./charts/danube-core/quickstart/values-production.yaml
```

### Option 2: Install from Helm Repository (Production)

First, add the repository to your Helm client:

```sh
helm repo add danube https://danrusei.github.io/danube_helm
helm repo update
```

Then install the chart:

```sh
helm install danube danube/danube-core
```

Create the broker ConfigMap before installation:

```sh
kubectl create namespace danube --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n danube -f ./charts/danube-core/quickstart/configmap-broker.yaml
```

### Configure External Access via NodePort

If using NodePort ingress (typical for local Kind clusters), configure the advertised port:

```sh
helm install danube ./charts/danube-core \
  --set broker.externalAccess.enabled=true \
  --set broker.externalAccess.type=NodePort \
  --set broker.externalAccess.advertisedPort=30115
```

The advertisedPort should match your ingress NodePort (30115 in the example above).

You can further customize the installation - check the [README](charts/danube-core/README.md) for all configuration options.

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

## Check the install

Make sure that the brokers, etcd, prometheus and the nginx ingress are running properly in the cluster.

```bash
kubectl get pods -l app.kubernetes.io/name=danube-core

NAME                                  READY   STATUS    RESTARTS   AGE
danube-core-broker-0                  1/1     Running   0          2m
danube-core-broker-1                  1/1     Running   0          2m
danube-core-broker-2                  1/1     Running   0          2m
danube-core-etcd-0                    1/1     Running   0          2m
danube-core-etcd-1                    1/1     Running   0          2m
danube-core-etcd-2                    1/1     Running   0          2m
danube-core-prometheus-xxxxxxxxx      1/1     Running   0          2m
```

Check services:

```bash
kubectl get svc -l app.kubernetes.io/name=danube-core

NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
danube-core-broker           ClusterIP   10.96.40.244    <none>        6650/TCP,50051/TCP,9040/TCP  2m
danube-core-broker-headless  ClusterIP   None            <none>        6650/TCP,50051/TCP,9040/TCP  2m
danube-core-etcd             ClusterIP   10.96.232.70    <none>        2379/TCP,2380/TCP            2m
danube-core-etcd-headless    ClusterIP   None            <none>        2379/TCP,2380/TCP            2m
danube-core-prometheus       ClusterIP   10.96.100.50    <none>        9090/TCP                     2m
```

Validate that the brokers have started correctly:

```bash
kubectl logs danube-core-broker-0

initializing metrics exporter
2024-08-28T04:30:22.969462Z  INFO danube_broker: Use ETCD storage as metadata persistent store
2024-08-28T04:30:22.969598Z  INFO danube_broker: Start the Danube Service
2024-08-28T04:30:22.969612Z  INFO danube_broker::danube_service: Setting up the cluster MY_CLUSTER
2024-08-28T04:30:22.971978Z  INFO danube_broker::danube_service::local_cache: Initial cache populated
2024-08-28T04:30:22.972013Z  INFO danube_broker::danube_service: Started the Local Cache service.
2024-08-28T04:30:22.990763Z  INFO danube_broker::danube_service::broker_register: Broker 14150019297734190044 registered in the cluster
2024-08-28T04:30:22.991620Z  INFO danube_broker::danube_service: Namespace default already exists.
2024-08-28T04:30:22.991926Z  INFO danube_broker::danube_service: Namespace system already exists.
2024-08-28T04:30:22.992480Z  INFO danube_broker::danube_service: Namespace default already exists.
2024-08-28T04:30:22.992490Z  INFO danube_broker::danube_service: cluster metadata setup completed
2024-08-28T04:30:22.992551Z  INFO danube_broker::danube_service:  Started the Broker GRPC server
2024-08-28T04:30:22.992563Z  INFO danube_broker::broker_server: Server is listening on address: 0.0.0.0:6650
2024-08-28T04:30:22.992605Z  INFO danube_broker::danube_service: Started the Leader Election service
2024-08-28T04:30:22.993050Z  INFO danube_broker::danube_service: Started the Load Manager service.
2024-08-28T04:30:22.993143Z  INFO danube_broker::danube_service:  Started the Danube Admin GRPC server
2024-08-28T04:30:22.993274Z  INFO danube_broker::admin: Admin is listening on address: 0.0.0.0:50051
```

## Setup in order to communicate with cluster PubSub brokers

```bash
kubectl get nodes -o wide
NAME                 STATUS   ROLES           AGE   VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION       CONTAINER-RUNTIME
kind-control-plane   Ready    control-plane   53m   v1.30.0   172.20.0.2    <none>        Debian GNU/Linux 12 (bookworm)   5.15.0-118-generic   containerd://1.7.15
```

Use the **INTERNAL-IP** to route the traffic to broker hosts. Add the following in the hosts file, but make sure you match the number and the name of the brokers from the helm values.yaml file.

```bash
cat /etc/hosts
172.20.0.2 broker1.example.com broker2.example.com broker3.example.com

```

## Inspect the etcd instance (optional)

If you want to connect from your local machine, use kubectl port-forward to forward the etcd port to your local machine:

Port Forward etcd Service:

```bash
kubectl port-forward service/danube-core-etcd 2379:2379
```

Once port forwarding is set up, you can run etcdctl commands from your local machine:

```bash
etcdctl --endpoints=http://localhost:2379 watch --prefix /
```

## Access Prometheus (optional)

Port forward Prometheus to view metrics:

```bash
kubectl port-forward service/danube-core-prometheus 9090:9090
```

Then open `http://localhost:9090` in your browser to access the Prometheus UI.
