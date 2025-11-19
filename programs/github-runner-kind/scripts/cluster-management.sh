#!/usr/bin/env bash
# Cluster management functions

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

create_cluster() {
  echo "Creating kind cluster: $CLUSTER_NAME"
  check_docker_ready
  
  if check_cluster_exists; then
    echo "Cluster $CLUSTER_NAME already exists"
    return 0
  fi
  
  kind create cluster --config "$CONFIG_DIR/kind-config.yaml"
  echo "Cluster created successfully"
}

delete_cluster() {
  echo "Deleting kind cluster: $CLUSTER_NAME"
  
  if ! check_cluster_exists; then
    echo "Cluster $CLUSTER_NAME does not exist"
    return 0
  fi
  
  kind delete cluster --name "$CLUSTER_NAME"
  echo "Cluster deleted successfully"
}

install_controller() {
  echo "Installing Actions Runner Controller"
  
  if ! check_cluster_exists; then
    echo "Error: Cluster $CLUSTER_NAME does not exist. Run 'create-cluster' first."
    exit 1
  fi
  
  kubectl config use-context "kind-$CLUSTER_NAME"
  
  echo "Installing ARC controller in namespace: $CONTROLLER_NAMESPACE"
  helm install arc \
    --namespace "$CONTROLLER_NAMESPACE" \
    --create-namespace \
    oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
  
  echo "Waiting for controller to be ready..."
  kubectl wait --for=condition=available --timeout=300s \
    deployment/arc-gha-runner-scale-set-controller \
    -n "$CONTROLLER_NAMESPACE" || true
  
  echo "ARC controller installed successfully"
}

uninstall_controller() {
  echo "Uninstalling Actions Runner Controller"
  
  if ! check_cluster_exists; then
    echo "Cluster $CLUSTER_NAME does not exist"
    return 0
  fi
  
  kubectl config use-context "kind-$CLUSTER_NAME"
  
  helm uninstall arc -n "$CONTROLLER_NAMESPACE" || echo "Controller not installed"
  kubectl delete namespace "$CONTROLLER_NAMESPACE" --ignore-not-found=true
  
  echo "ARC controller uninstalled"
}

# Export functions
export -f create_cluster
export -f delete_cluster
export -f install_controller
export -f uninstall_controller