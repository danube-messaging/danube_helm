# Danube Core Quickstart

This folder provides a minimal, copy-and-run setup for deploying Danube Core.

## Steps

1. **Create the namespace (recommended)**

```bash
kubectl create namespace danube --dry-run=client -o yaml | kubectl apply -f -
```

2. **Apply the broker config ConfigMap**

Filesystem-backed broker config:

```bash
kubectl apply -n danube -f ./charts/danube-core/quickstart/configmap-broker.yaml
```

S3/MinIO-backed broker config:

```bash
kubectl apply -n danube -f ./charts/danube-core/quickstart/configmap-broker-cloud.yaml
```

3. **Install the chart**

```bash
helm install danube-core ./charts/danube-core \
  -n danube \
  --create-namespace \
  -f ./charts/danube-core/quickstart/values-minimal.yaml
```

4. **(Optional) Use the prepare helper**

```bash
./scripts/prepare_danube_core_release.sh \
  -c ./charts/danube-core/quickstart/danube_broker.yml
```

## Notes

- If you change the Helm release name, update `meta_store.host` in the broker config
  to `<release>-danube-core-etcd`.
- Edit `danube_broker.yml` or `danube_broker_cloud.yml` to adjust cluster settings.
