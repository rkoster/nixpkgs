#!/usr/bin/env bash
# Core utilities for GitHub runner management

get_unique_repos() {
  printf '%s\n' "${REPOS[@]}" | sort -u
}

get_repo_instances() {
  local repo="$1"
  for key in "${!REPOS[@]}"; do
    if [[ "${REPOS[$key]}" == "$repo" ]]; then
      echo "$key"
    fi
  done | sort
}

parse_repo_instance() {
  local arg="$1"
  local repo instance_num
  
  if [[ "$arg" == *":"* ]]; then
    repo="${arg%:*}"
    instance_num="${arg#*:}"
  else
    repo="$arg"
    instance_num="1"
  fi
  
  echo "$repo:$instance_num"
}

validate_instance() {
  local key="$1"
  if [[ ! ${REPOS["$key"]+_} ]]; then
    echo "Error: Instance '$key' not configured"
    echo "Available instances:"
    printf '%s\n' "${!REPOS[@]}" | sort
    exit 1
  fi
}

check_docker_ready() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker command not found"
    exit 1
  fi
  
  if ! docker ps >/dev/null 2>&1; then
    echo "Error: Docker daemon not accessible"
    echo "Ensure Docker is running and your user has permissions"
    exit 1
  fi
}

check_cluster_exists() {
  kind get clusters 2>/dev/null | grep -q "^$CLUSTER_NAME$"
}

# Export functions for use in other scripts
export -f get_unique_repos
export -f get_repo_instances  
export -f parse_repo_instance
export -f validate_instance
export -f check_docker_ready
export -f check_cluster_exists