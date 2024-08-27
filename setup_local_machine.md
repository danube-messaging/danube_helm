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
  --set controller.service.type=NodePort \
  --set controller.service.ports.http=6650
```

You can find out which port is assigned by running

```bash
kubectl get svc -n ingress-nginx
```

This will install the NGINX Ingress Controller into the cluster.

## Install Danube PubSub

First, add the repository to your Helm client:

```sh
helm repo add danube https://danrusei.github.io/danube_helm
helm repo update
```

You can install the chart with the release name `my-danube-cluster` using the following command:

```sh
helm install my-danube-cluster danube/danube-helm-chart
```

You can further customize the installation, check the readme file. I'm installing it using the default configuration with 3 danube brokers.

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
