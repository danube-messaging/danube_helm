# Install Ngnix as ingress controller in the k8s cluster

Using the Official NGINX Ingress Helm Chart

You can install the NGINX Ingress Controller using Helm:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install nginx-ingress ingress-nginx/ingress-nginx --set controller.publishService.enabled=true
```

This will install the NGINX Ingress Controller into the cluster.
