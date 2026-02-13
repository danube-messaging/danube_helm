#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: prepare_danube_core_release.sh -c <broker-config-file> [options]

Options:
  -c, --config-file     Path to danube_broker.yml (required)
  -n, --namespace       Kubernetes namespace (default: danube)
  -m, --configmap-name  ConfigMap name (default: danube-broker-config)
  -f, --file-name       File name in ConfigMap (default: danube_broker.yml)
  -r, --release-name    Helm release name (default: danube-core)
  -v, --values-file     Values file (default: ./charts/danube-core/quickstart/values-minimal.yaml)
      --no-create-namespace Skip creating the namespace
  -h, --help            Show this help message

Example:
  ./scripts/prepare_danube_core_release.sh \
    -c ./charts/danube-core/quickstart/danube_broker.yml \
    -n danube
USAGE
}

NAMESPACE="danube"
CONFIGMAP_NAME="danube-broker-config"
FILE_NAME="danube_broker.yml"
RELEASE_NAME="danube-core"
VALUES_FILE="./charts/danube-core/quickstart/values-minimal.yaml"
CREATE_NAMESPACE="true"
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
    -f|--file-name)
      FILE_NAME="$2"
      shift 2
      ;;
    -r|--release-name)
      RELEASE_NAME="$2"
      shift 2
      ;;
    -v|--values-file)
      VALUES_FILE="$2"
      shift 2
      ;;
    --no-create-namespace)
      CREATE_NAMESPACE="false"
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

if [[ "$CREATE_NAMESPACE" == "true" ]]; then
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
fi

kubectl create configmap "$CONFIGMAP_NAME" \
  --from-file="$FILE_NAME"="$CONFIG_FILE" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF

ConfigMap "$CONFIGMAP_NAME" applied in namespace "$NAMESPACE".

Next step:
  helm install $RELEASE_NAME ./charts/danube-core -n $NAMESPACE -f $VALUES_FILE --create-namespace
EOF
