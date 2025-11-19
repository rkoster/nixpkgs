#!/usr/bin/env bash
# Runner deployment functions

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/template-utils.sh"

deploy_runner_set() {
  local arg="$1"
  local instance_key
  instance_key=$(parse_repo_instance "$arg")
  validate_instance "$instance_key"
  
  # Extract instance configuration
  local repo="${REPOS[$instance_key]}"
  local installation_name="${INSTALLATION_NAMES[$instance_key]}"
  local min_runners="${MIN_RUNNERS[$instance_key]}"
  local max_runners="${MAX_RUNNERS[$instance_key]}"
  local runner_type="${TYPES[$instance_key]}"
  local build_cache_size="${BUILD_CACHE_SIZES[$instance_key]}"
  local cache_paths="${CACHE_PATHS[$instance_key]}"
  local instance_id="${INSTANCE_IDS[$instance_key]}"
  local dind_sidecar="${DIND_SIDECARS[$instance_key]}"
  local dind_image="${DIND_IMAGES[$instance_key]}"
  local dind_storage_size="${DIND_STORAGE_SIZES[$instance_key]}"
  
  echo "Deploying runner scale set for: $repo (instance $instance_id)"
  echo "Installation name: $installation_name"
  echo "Runner type: $runner_type"
  
  if ! check_cluster_exists; then
    echo "Error: Cluster $CLUSTER_NAME does not exist. Run 'create-cluster' first."
    exit 1
  fi
  
  kubectl config use-context "kind-$CLUSTER_NAME"
  
  # Validate GitHub CLI
  if ! command -v gh >/dev/null 2>&1; then
    echo "Error: GitHub CLI (gh) not found"
    exit 1
  fi
  
  if ! gh auth status >/dev/null 2>&1; then
    echo "Error: GitHub CLI not authenticated. Run: gh auth login"
    exit 1
  fi
  
  echo "Getting GitHub PAT..."
  GITHUB_PAT=$(gh auth token)
  
  if [ -z "$GITHUB_PAT" ]; then
    echo "Error: Failed to get GitHub PAT"
    exit 1
  fi
  
  echo "Installing runner scale set with Helm..."
  
  # Build base helm command
  local helm_cmd=(
    helm upgrade --install "$installation_name"
    --namespace "$RUNNERS_NAMESPACE"
    --create-namespace
    --set githubConfigUrl="https://github.com/$repo"
    --set githubConfigSecret.github_token="$GITHUB_PAT"
    --set controllerServiceAccount.name="arc-gha-rs-controller"
    --set runnerScaleSetName="$installation_name"
    --set minRunners="$min_runners"
    --set maxRunners="$max_runners"
  )
  
  # Configure runner type and add custom templates
  configure_runner_type "$runner_type" "$cache_paths" "$installation_name" \
    "$instance_id" "$dind_sidecar" "$dind_image" "$dind_storage_size" helm_cmd
  
  # Add chart URL and execute
  helm_cmd+=(oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set)
  
  # Execute the helm command
  "${helm_cmd[@]}"
  
  echo "Waiting for listener pod to be ready..."
  kubectl wait --for=condition=ready --timeout=300s \
    pod -l app.kubernetes.io/instance="$installation_name" \
    -n "$RUNNERS_NAMESPACE" || true
  
  echo "Runner scale set deployed successfully"
  print_deployment_summary "$runner_type" "$cache_paths" "$max_runners" \
    "$installation_name" "$build_cache_size" "$dind_sidecar"
}

configure_runner_type() {
  local runner_type="$1"
  local cache_paths="$2"
  local installation_name="$3"
  local instance_id="$4"
  local dind_sidecar="$5"
  local dind_image="$6"
  local dind_storage_size="$7"
  local -n helm_cmd_ref="$8"
  
  case "$runner_type" in
    "kubernetes")
      echo "Configuring standard Kubernetes mode"
      helm_cmd_ref+=(--set containerMode.type="kubernetes")
      ;;
      
    "cached-privileged-kubernetes")
      echo "Configuring cached privileged mode using kubernetes container type with custom privileged template"
      helm_cmd_ref+=(--set containerMode.type="kubernetes")
      
      local temp_values=$(mktemp)
      process_cached_privileged_template \
        "$TEMPLATE_DIR/cached-privileged-values.yaml" \
        "$cache_paths" \
        "$installation_name" \
        "$temp_values"
      
      helm_cmd_ref+=(--values "$temp_values")
      ;;
      
    "dind")
      echo "Configuring DIND mode"
      helm_cmd_ref+=(--set containerMode.type="dind")
      ;;
      
    *)
      echo "Error: Unknown runner type: $runner_type"
      exit 1
      ;;
  esac
  
  # Add DinD sidecar if enabled
  if [ "$dind_sidecar" = "true" ]; then
    configure_dind_sidecar "$dind_image" "$installation_name" \
      "$dind_storage_size" helm_cmd_ref
  fi
}

configure_dind_sidecar() {
  local dind_image="$1"
  local installation_name="$2"
  local dind_storage_size="$3"
  local -n helm_cmd_ref="$4"
  
  echo "Adding DinD sidecar container for Docker access via TCP"
  
  # Create PVC if storage size specified
  if [ -n "$dind_storage_size" ]; then
    echo "Creating persistent volume claim for DinD storage..."
    create_dind_pvc "$TEMPLATE_DIR/dind-pvc.yaml" "$installation_name" \
      "$dind_storage_size" "$RUNNERS_NAMESPACE"
  fi
  
  # Process DinD sidecar template
  local temp_values=$(mktemp)
  process_dind_sidecar_template \
    "$TEMPLATE_DIR/dind-sidecar-values.yaml" \
    "$dind_image" \
    "$installation_name" \
    "$dind_storage_size" \
    "$temp_values"
  
  helm_cmd_ref+=(--values "$temp_values")
}

print_deployment_summary() {
  local runner_type="$1"
  local cache_paths="$2"
  local max_runners="$3"
  local installation_name="$4"
  local build_cache_size="$5"
  local dind_sidecar="$6"
  
  if [ "$runner_type" = "cached-privileged-kubernetes" ] && [ -n "$cache_paths" ] && [ "$cache_paths" != "[]" ]; then
    echo "Deterministic cache partitions configured (workers reuse cache slots):"
    local temp_json=$(mktemp)
    printf '%s\n' "$cache_paths" > "$temp_json"
    local cache_count
    cache_count=$(jq length < "$temp_json")
    for i in $(seq 0 $((cache_count-1))); do
      local cache_name cache_path
      cache_name=$(jq -r ".[$i].name" < "$temp_json")
      cache_path=$(jq -r ".[$i].path" < "$temp_json")
      echo "  - $cache_path: partitioned into $max_runners slots (hostPath: /tmp/github-runner-cache/$installation_name/$cache_name/{0..$((max_runners-1))})"
    done
    rm -f "$temp_json"
  fi
  
  if [ -n "$build_cache_size" ]; then
    echo "Build artifacts cache enabled with size: $build_cache_size"
  fi
  
  if [ "$dind_sidecar" = "true" ]; then
    echo "DinD sidecar enabled - Docker available at tcp://localhost:2375"
  fi
  
  echo "Use this in your workflow:"
  echo "  runs-on: $installation_name"
}

# Export functions
export -f deploy_runner_set
export -f configure_runner_type
export -f configure_dind_sidecar
export -f print_deployment_summary