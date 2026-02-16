#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: prepare_danube_core_release.sh -c <broker-config-file> [options]

Prepares a Kubernetes cluster for Danube by:
  1. Creating the namespace
  2. Installing the danube-envoy proxy chart
  3. Discovering the proxy address (NodePort + Node IP)
  4. Creating the broker ConfigMap
  5. Printing the exact helm install command for danube-core

Options:
  -c, --config-file     Path to danube_broker.yml (required)
  -n, --namespace       Kubernetes namespace (default: danube)
  -m, --configmap-name  ConfigMap name (default: danube-broker-config)
  -v, --values-file     Values file for danube-core (default: ./charts/danube-core/examples/values-minimal.yaml)
  -e, --envoy-chart     Envoy chart path or repo reference (default: ./charts/danube-envoy)
      --no-create-namespace  Skip creating the namespace
      --skip-envoy           Skip installing danube-envoy (already installed)
  -h, --help            Show this help message

Example:
  ./scripts/prepare_danube_core_release.sh \
    -c ./charts/danube-core/examples/danube_broker.yml

  # Using charts from Helm repo
  ./scripts/prepare_danube_core_release.sh \
    -c danube_broker.yml \
    -e danube/danube-envoy
USAGE
}

NAMESPACE="danube"
CONFIGMAP_NAME="danube-broker-config"
RELEASE_NAME="danube-core"
VALUES_FILE="./charts/danube-core/examples/values-minimal.yaml"
ENVOY_CHART="./charts/danube-envoy"
CREATE_NAMESPACE="true"
SKIP_ENVOY="false"
CONFIG_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--config-file)
      CONFIG_FILE="$2"
      shift 2
      ;;
    -n|--namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    -m|--configmap-name)
      CONFIGMAP_NAME="$2"
      shift 2
      ;;
    -v|--values-file)
      VALUES_FILE="$2"
      shift 2
      ;;
    -e|--envoy-chart)
      ENVOY_CHART="$2"
      shift 2
      ;;
    --no-create-namespace)
      CREATE_NAMESPACE="false"
      shift
      ;;
    --skip-envoy)
      SKIP_ENVOY="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$CONFIG_FILE" ]]; then
  echo "Error: --config-file is required." >&2
  usage
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: config file not found: $CONFIG_FILE" >&2
  exit 1
fi

# Step 1: Create namespace
if [[ "$CREATE_NAMESPACE" == "true" ]]; then
  echo "==> Creating namespace '$NAMESPACE'..."
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
fi

# Step 2: Install danube-envoy
if [[ "$SKIP_ENVOY" == "false" ]]; then
  echo "==> Installing danube-envoy from '$ENVOY_CHART'..."
  helm install danube-envoy "$ENVOY_CHART" -n "$NAMESPACE"
  echo "==> Waiting for envoy proxy pod to be ready..."
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=danube-envoy \
    -n "$NAMESPACE" --timeout=120s
fi

# Step 3: Discover proxy address
echo "==> Discovering proxy address..."
PROXY_PORT=$(kubectl get svc danube-envoy -n "$NAMESPACE" \
  -o jsonpath='{.spec.ports[?(@.name=="grpc")].nodePort}')
NODE_IP=$(kubectl get nodes \
  -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

if [[ -z "$PROXY_PORT" || -z "$NODE_IP" ]]; then
  echo "Error: could not discover proxy address." >&2
  echo "  PROXY_PORT=$PROXY_PORT  NODE_IP=$NODE_IP" >&2
  exit 1
fi

PROXY_ADDR="${NODE_IP}:${PROXY_PORT}"
echo "    Proxy address: ${PROXY_ADDR}"

# Step 4: Create broker ConfigMap
echo "==> Creating ConfigMap '$CONFIGMAP_NAME' from '$CONFIG_FILE'..."
kubectl create configmap "$CONFIGMAP_NAME" \
  --from-file=danube_broker.yml="$CONFIG_FILE" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# Step 5: Print install command
cat <<EOF

✅ Preparation complete.

Run the following command to install Danube:

  helm install $RELEASE_NAME ./charts/danube-core -n $NAMESPACE \\
    -f $VALUES_FILE \\
    --set broker.externalAccess.connectUrl="$PROXY_ADDR"

EOF
