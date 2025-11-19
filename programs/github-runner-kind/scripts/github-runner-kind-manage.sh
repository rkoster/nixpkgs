#!/usr/bin/env bash
set -euo pipefail

# GitHub Actions Runner Controller management script
# This script manages a shared kind cluster with GitHub Actions runners

# Configuration variables will be set by Nix
CLUSTER_NAME=""
CONTROLLER_NAMESPACE=""
RUNNERS_NAMESPACE=""
CONFIG_DIR=""
TEMPLATE_DIR=""

# Repository and instance configuration arrays
declare -A REPOS
declare -A INSTALLATION_NAMES
declare -A MIN_RUNNERS
declare -A MAX_RUNNERS
declare -A TYPES
declare -A BUILD_CACHE_SIZES
declare -A CACHE_PATHS
declare -A INSTANCE_IDS
declare -A DIND_SIDECARS
declare -A DIND_IMAGES
declare -A DIND_STORAGE_SIZES

# Source template utilities
source "$TEMPLATE_DIR/../scripts/template-utils.sh"