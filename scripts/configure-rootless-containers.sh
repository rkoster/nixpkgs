#!/bin/bash

set -e

echo "=== Configuring Rootless Containers for OpenCode Workspace ==="

# Function to create directories if they don't exist
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Configure Podman for rootless operation
configure_podman() {
    echo "Configuring Podman for rootless operation..."
    
    # Create necessary directories
    ensure_dir "$HOME/.config/containers"
    
    # Create containers.conf for rootless mode
    cat > "$HOME/.config/containers/containers.conf" <<'EOF'
[containers]
# Use user namespace for rootless containers
userns = "auto"

# Set default mount type
mount_program = "/usr/bin/fuse-overlayfs"

# Enable cgroup v2 management (works around cgroup read-only issues)
cgroup_manager = "systemd"

# Use rootless networking
netns = "auto"

# Configure storage
[storage]
driver = "overlay"
graphroot = "$HOME/.local/share/containers/storage"

[storage.options]
mount_program = "/usr/bin/fuse-overlayfs"
EOF

    echo "Podman configuration created: $HOME/.config/containers/containers.conf"
}

# Configure Buildah for rootless image building
configure_buildah() {
    echo "Configuring Buildah for rootless image building..."
    
    # Create buildah-specific configuration
    ensure_dir "$HOME/.config/containers"
    
    cat > "$HOME/.config/containers/buildah.conf" <<'EOF'
[build]
# Use user namespace for building
isolation = "chroot"

# Configure storage for rootless builds
[storage]
driver = "overlay"
graphroot = "$HOME/.local/share/containers/storage"
EOF

    echo "Buildah configuration created: $HOME/.config/containers/buildah.conf"
}

# Create OpenCode workspace helper script
create_workspace_helper() {
    echo "Creating OpenCode workspace helper script..."
    
    ensure_dir "$HOME/.local/bin"
    
    cat > "$HOME/.local/bin/opencode-container-helper" <<'EOF'
#!/bin/bash
# OpenCode Container Helper - Rootless container operations for CI/CD

set -e

OPERATION="${1:-help}"
IMAGE_NAME="${2:-}"
CONTAINER_NAME="${3:-opencode-workspace}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[opencode-helper]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[opencode-helper]${NC} WARNING: $1"
}

error() {
    echo -e "${RED}[opencode-helper]${NC} ERROR: $1"
    exit 1
}

# Check if we can use rootless containers
check_rootless_support() {
    if command -v podman >/dev/null 2>&1; then
        log "Podman available for rootless containers"
        return 0
    elif command -v buildah >/dev/null 2>&1; then
        log "Buildah available for rootless image building"
        return 0
    elif command -v docker >/dev/null 2>&1; then
        warn "Only Docker available - may encounter cgroup issues in restricted environments"
        return 1
    else
        error "No container runtime found (podman, buildah, or docker)"
    fi
}

# Build container image using rootless tools
build_image() {
    local dockerfile="${1:-Dockerfile}"
    local context="${2:-.}"
    
    if [ -z "$IMAGE_NAME" ]; then
        error "Image name required for build operation"
    fi
    
    log "Building image: $IMAGE_NAME"
    log "Using dockerfile: $dockerfile"
    log "Build context: $context"
    
    # Try Podman first (preferred for rootless)
    if command -v podman >/dev/null 2>&1; then
        log "Using Podman for rootless build"
        podman build -t "$IMAGE_NAME" -f "$dockerfile" "$context"
        return 0
    fi
    
    # Try Buildah as fallback
    if command -v buildah >/dev/null 2>&1; then
        log "Using Buildah for rootless build"
        
        # Create buildah container
        local container_id
        container_id=$(buildah from scratch)
        
        # Copy build context
        buildah copy "$container_id" "$context" /workspace/
        
        # If Dockerfile exists, process it manually
        if [ -f "$dockerfile" ]; then
            warn "Manual Dockerfile processing with Buildah - consider using Podman for full Dockerfile support"
            warn "Buildah requires manual step execution - refer to documentation"
        fi
        
        # Commit the image
        buildah commit "$container_id" "$IMAGE_NAME"
        buildah rm "$container_id"
        
        return 0
    fi
    
    # Fallback to Docker if available
    if command -v docker >/dev/null 2>&1; then
        warn "Using Docker - may fail in cgroup read-only environments"
        docker build -t "$IMAGE_NAME" -f "$dockerfile" "$context"
        return 0
    fi
    
    error "No suitable container builder found"
}

# Run container using rootless tools
run_container() {
    local image="${1:-$IMAGE_NAME}"
    local cmd="${2:-/bin/bash}"
    
    if [ -z "$image" ]; then
        error "Image name required for run operation"
    fi
    
    log "Running container from image: $image"
    
    # Try Podman first
    if command -v podman >/dev/null 2>&1; then
        log "Using Podman for rootless container execution"
        
        # Run with user namespace and cgroup workarounds
        podman run --rm -it \
            --userns=keep-id \
            --security-opt label=disable \
            --name "$CONTAINER_NAME" \
            "$image" "$cmd"
        return 0
    fi
    
    # Fallback to Docker
    if command -v docker >/dev/null 2>&1; then
        warn "Using Docker - may fail in cgroup read-only environments"
        docker run --rm -it --name "$CONTAINER_NAME" "$image" "$cmd"
        return 0
    fi
    
    error "No suitable container runtime found"
}

# Test rootless container functionality
test_rootless() {
    log "Testing rootless container functionality..."
    
    # Test with a simple alpine image
    local test_image="docker.io/alpine:latest"
    
    if command -v podman >/dev/null 2>&1; then
        log "Testing Podman rootless mode..."
        
        # Pull image
        podman pull "$test_image"
        
        # Test user namespace functionality
        podman run --rm --userns=keep-id "$test_image" /bin/sh -c '
            echo "=== Rootless Container Test ==="
            echo "Container UID: $(id -u)"
            echo "Container GID: $(id -g)"
            echo "User: $(whoami)"
            echo "Cgroup info:"
            if [ -r /sys/fs/cgroup/cgroup.controllers ]; then
                echo "Cgroup controllers: $(cat /sys/fs/cgroup/cgroup.controllers || echo "read-only or restricted")"
            else
                echo "Cgroup filesystem: read-only or restricted (expected in Kubernetes)"
            fi
            echo "=== Test completed successfully ==="
        '
        
        log "Podman rootless test completed successfully"
        return 0
    fi
    
    error "Podman not available for testing"
}

# Show usage information
show_help() {
    cat <<EOF
OpenCode Container Helper - Rootless container operations for CI/CD

USAGE:
    $0 <operation> [arguments]

OPERATIONS:
    check           - Check rootless container support
    build <image> [dockerfile] [context]
                   - Build container image using rootless tools
    run <image> [command]
                   - Run container using rootless tools
    test           - Test rootless container functionality
    help           - Show this help message

EXAMPLES:
    $0 check
    $0 build my-app:latest
    $0 build my-app:latest Dockerfile.prod ./src
    $0 run my-app:latest /bin/bash
    $0 run alpine:latest /bin/sh
    $0 test

ENVIRONMENT:
    This tool is designed to work around cgroup read-only filesystem
    issues in Kubernetes environments by using rootless container runtimes.

NOTES:
    - Podman is preferred for full Docker compatibility
    - Buildah provides lightweight image building
    - Falls back to Docker if rootless tools unavailable
EOF
}

# Main operation dispatcher
case "$OPERATION" in
    check)
        check_rootless_support
        ;;
    build)
        check_rootless_support
        build_image "${@:3}"
        ;;
    run)
        check_rootless_support
        run_container "${@:3}"
        ;;
    test)
        check_rootless_support
        test_rootless
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown operation: $OPERATION"
        show_help
        ;;
esac
EOF

    chmod +x "$HOME/.local/bin/opencode-container-helper"
    echo "OpenCode container helper created: $HOME/.local/bin/opencode-container-helper"
}

# Create enhanced GitHub workflow example
create_workflow_example() {
    echo "Creating enhanced GitHub workflow example..."
    
    ensure_dir "$HOME/.local/share/opencode-examples"
    
    cat > "$HOME/.local/share/opencode-examples/rootless-container-workflow.yml" <<'EOF'
name: OpenCode Workspace with Rootless Containers
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  rootless-container-job:
    runs-on: arc-runner-github-rkoster-rubionic-workspace
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
    
    - name: Set up rootless container environment
      run: |
        echo "=== Setting up rootless container environment ==="
        
        # Check available container runtimes
        if command -v podman >/dev/null 2>&1; then
          echo "✅ Podman available"
          podman --version
        else
          echo "❌ Podman not available"
        fi
        
        if command -v buildah >/dev/null 2>&1; then
          echo "✅ Buildah available"
          buildah --version
        else
          echo "❌ Buildah not available"
        fi
        
        if command -v docker >/dev/null 2>&1; then
          echo "✅ Docker available"
          docker --version
        else
          echo "❌ Docker not available"
        fi
        
        # Test cgroup filesystem status
        echo "=== Cgroup filesystem status ==="
        if [ -w /sys/fs/cgroup/cgroup.subtree_control ]; then
          echo "✅ Cgroup filesystem is writable"
        else
          echo "⚠️  Cgroup filesystem is read-only (expected in Kubernetes mode)"
          echo "Using rootless containers to work around this limitation"
        fi
    
    - name: Test rootless container functionality
      run: |
        echo "=== Testing rootless container functionality ==="
        
        # Use the helper script if available
        if [ -x "$HOME/.local/bin/opencode-container-helper" ]; then
          opencode-container-helper test
        else
          # Manual test with podman
          if command -v podman >/dev/null 2>&1; then
            echo "Testing Podman rootless mode manually..."
            
            # Pull a lightweight test image
            podman pull docker.io/alpine:latest
            
            # Run test container with rootless settings
            podman run --rm --userns=keep-id docker.io/alpine:latest /bin/sh -c '
              echo "=== Rootless Container Test ==="
              echo "Container UID: $(id -u)"
              echo "Container user: $(whoami)"
              echo "Working directory: $(pwd)"
              echo "Environment test: $HOME"
              echo "=== Test completed ==="
            '
          else
            echo "Podman not available for testing"
            exit 1
          fi
        fi
    
    - name: Build application with rootless containers
      run: |
        echo "=== Building application with rootless containers ==="
        
        # Create a simple test Dockerfile
        cat > Dockerfile <<'DOCKERFILE_EOF'
FROM alpine:latest
RUN apk add --no-cache bash curl
WORKDIR /app
COPY . .
CMD ["/bin/bash"]
DOCKERFILE_EOF
        
        # Build using rootless container tools
        if command -v podman >/dev/null 2>&1; then
          echo "Building with Podman (rootless mode)..."
          podman build -t test-app:latest .
          
          echo "Running built container..."
          podman run --rm --userns=keep-id test-app:latest /bin/sh -c 'echo "Application built successfully with rootless containers!"'
        else
          echo "Podman not available, cannot build with rootless containers"
          exit 1
        fi
    
    - name: OpenCode workspace action test
      uses: rkoster/opencode-workspace-action@main
      with:
        prompt: "Test the rootless container functionality and verify that container operations work correctly in this Kubernetes environment with read-only cgroup filesystem."
        use_rootless_containers: true  # This would be a new option
        container_runtime: "podman"    # Specify preferred runtime
EOF

    echo "Workflow example created: $HOME/.local/share/opencode-examples/rootless-container-workflow.yml"
}

# Main configuration function
main() {
    echo "Starting rootless container configuration..."
    
    # Check for required tools
    if ! command_exists "podman" && ! command_exists "buildah"; then
        error "Neither Podman nor Buildah is installed. Please install them first."
    fi
    
    # Configure tools
    configure_podman
    configure_buildah
    create_workspace_helper
    create_workflow_example
    
    echo ""
    echo "=== Configuration Complete ==="
    echo ""
    echo "Rootless container environment configured successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Test the configuration: opencode-container-helper test"
    echo "2. Use in workflows: see $HOME/.local/share/opencode-examples/rootless-container-workflow.yml"
    echo "3. Build images: opencode-container-helper build <image-name>"
    echo "4. Run containers: opencode-container-helper run <image-name>"
    echo ""
    echo "This configuration works around cgroup read-only filesystem issues"
    echo "commonly encountered in Kubernetes environments."
}

# Run main configuration
main "$@"