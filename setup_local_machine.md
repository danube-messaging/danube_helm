# Setup Danube on the k8s cluster using [kind](https://kind.sigs.k8s.io/)

## Create the cluster

## Install the Ngnix Ingress controller

## Install Danube cluster

make the changes.. (how to modify the name of the brokers and others)

## Expose the NGINX Ingress Controller Ports on Localhost

Since your NGINX Ingress controller is not exposed externally, you need to expose it using port forwarding. The key point is that the Ingress controller needs to be exposed on the HTTP/HTTPS ports (usually 80 and 443) since it does the routing.

You can expose port 80 using the following command:

```bash
kubectl port-forward --namespace <nginx_namespace> service/nginx-ingress-ingress-nginx-controller 80:80
```

## Use Proper DNS Resolution

Ensure that your /etc/hosts file contains the correct DNS entries mapping the broker hostnames to 127.0.0.1:

```bash
sudo nano /etc/hosts
```

Add the following lines:

```bash
127.0.0.1 broker1.example.com broker2.example.com broker3.example.com
```
