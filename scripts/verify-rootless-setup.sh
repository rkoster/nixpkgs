#!/bin/bash
# OpenCode Workspace - Rootless Container Setup Verification
# This script verifies that the rootless container configuration is working correctly

set -e

echo "=== OpenCode Workspace - Rootless Container Verification ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if we're in a Kubernetes environment (common indicators)
check_kubernetes_env() {
    info "Checking environment..."
    
    if [ -n "$KUBERNETES_SERVICE_HOST" ] || [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
        success "Running in Kubernetes environment"
        export IN_KUBERNETES=1
    else
        info "Not detected as Kubernetes environment (local testing)"
        export IN_KUBERNETES=0
    fi
    
    # Check cgroup filesystem
    if [ -w /sys/fs/cgroup/cgroup.subtree_control ] 2>/dev/null; then
        success "Cgroup filesystem is writable"
        export CGROUP_WRITABLE=1
    else
        warning "Cgroup filesystem is read-only or restricted"
        warning "This is expected in Kubernetes environments"
        export CGROUP_WRITABLE=0
    fi
}

# Check available container runtimes
check_container_runtimes() {
    info "Checking available container runtimes..."
    
    local found_runtime=0
    
    if command -v podman >/dev/null 2>&1; then
        success "Podman is available"
        podman --version
        export HAS_PODMAN=1
        found_runtime=1
    else
        warning "Podman is not available"
        export HAS_PODMAN=0
    fi
    
    if command -v buildah >/dev/null 2>&1; then
        success "Buildah is available"
        buildah --version
        export HAS_BUILDAH=1
        found_runtime=1
    else
        warning "Buildah is not available"
        export HAS_BUILDAH=0
    fi
    
    if command -v docker >/dev/null 2>&1; then
        success "Docker is available"
        docker --version
        export HAS_DOCKER=1
        found_runtime=1
    else
        warning "Docker is not available"
        export HAS_DOCKER=0
    fi
    
    if [ $found_runtime -eq 0 ]; then
        error "No container runtime found!"
        exit 1
    fi
}

# Test rootless container functionality
test_rootless_containers() {
    if [ $HAS_PODMAN -eq 1 ]; then
        info "Testing Podman rootless functionality..."
        
        echo "Pulling test image..."
        if podman pull docker.io/alpine:latest >/dev/null 2>&1; then
            success "Successfully pulled Alpine Linux image"
        else
            error "Failed to pull test image"
            return 1
        fi
        
        echo "Testing rootless container execution..."
        local test_output
        if test_output=$(podman run --rm --userns=keep-id docker.io/alpine:latest /bin/sh -c '
            echo "Container UID: $(id -u)"
            echo "Container GID: $(id -g)"
            echo "User: $(whoami)"
            echo "PWD: $(pwd)"
            if [ -r /sys/fs/cgroup/cgroup.controllers ]; then
                echo "Cgroup controllers available: yes"
            else
                echo "Cgroup controllers available: no (expected in restricted environments)"
            fi
        ' 2>&1); then
            success "Rootless container test successful"
            echo "$test_output" | sed 's/^/    /'
        else
            error "Rootless container test failed"
            echo "$test_output" | sed 's/^/    /'
            return 1
        fi
        
        # Test user namespace mapping
        info "Testing user namespace mapping..."
        local host_uid=$(id -u)
        local container_uid
        if container_uid=$(podman run --rm --userns=keep-id docker.io/alpine:latest id -u 2>/dev/null); then
            if [ "$host_uid" = "$container_uid" ]; then
                success "User namespace mapping working correctly ($host_uid -> $container_uid)"
            else
                warning "User namespace mapping shows different UID (host: $host_uid, container: $container_uid)"
            fi
        else
            error "Failed to test user namespace mapping"
        fi
    else
        warning "Skipping Podman tests (not available)"
    fi
}

# Test Docker fallback (if available)
test_docker_fallback() {
    if [ $HAS_DOCKER -eq 1 ]; then
        info "Testing Docker functionality (fallback mode)..."
        
        if [ $CGROUP_WRITABLE -eq 0 ]; then
            warning "Docker may fail due to cgroup restrictions - this test verifies the issue"
        fi
        
        echo "Testing Docker container execution..."
        if docker run --rm alpine:latest /bin/sh -c 'echo "Docker test successful"' >/dev/null 2>&1; then
            if [ $CGROUP_WRITABLE -eq 0 ]; then
                warning "Docker worked despite cgroup restrictions - environment may have special configuration"
            else
                success "Docker test successful"
            fi
        else
            if [ $CGROUP_WRITABLE -eq 0 ]; then
                warning "Docker failed as expected due to cgroup restrictions - rootless containers needed"
            else
                error "Docker test failed unexpectedly"
            fi
        fi
    else
        info "Docker not available - this is fine for rootless-only setup"
    fi
}

# Test helper script
test_helper_script() {
    info "Testing OpenCode container helper script..."
    
    if [ -x "$HOME/.local/bin/opencode-container-helper" ]; then
        success "Helper script is available"
        
        echo "Running helper script check..."
        if $HOME/.local/bin/opencode-container-helper check >/dev/null 2>&1; then
            success "Helper script check passed"
        else
            warning "Helper script check had issues (may be expected)"
        fi
    else
        warning "Helper script not found at $HOME/.local/bin/opencode-container-helper"
        warning "Run: configure-rootless-containers to set up"
    fi
}

# Test build functionality
test_build_functionality() {
    if [ $HAS_PODMAN -eq 1 ]; then
        info "Testing container image building..."
        
        # Create a simple test Dockerfile
        local temp_dir=$(mktemp -d)
        cat > "$temp_dir/Dockerfile" <<'EOF'
FROM alpine:latest
RUN echo "Test build successful" > /test.txt
CMD cat /test.txt
EOF
        
        local test_image="opencode-test:$(date +%s)"
        
        echo "Building test image with Podman..."
        if podman build -t "$test_image" "$temp_dir" >/dev/null 2>&1; then
            success "Image build successful"
            
            echo "Testing built image..."
            if podman run --rm "$test_image" 2>/dev/null | grep -q "Test build successful"; then
                success "Built image works correctly"
            else
                warning "Built image test failed"
            fi
            
            # Clean up
            podman rmi "$test_image" >/dev/null 2>&1 || true
        else
            warning "Image build failed - check Podman configuration"
        fi
        
        # Clean up
        rm -rf "$temp_dir"
    else
        warning "Skipping build test (Podman not available)"
    fi
}

# Generate summary report
generate_summary() {
    echo
    echo "=== Summary Report ==="
    
    echo "Environment:"
    echo "  - Kubernetes: $([ $IN_KUBERNETES -eq 1 ] && echo "Yes" || echo "No")"
    echo "  - Cgroup writable: $([ $CGROUP_WRITABLE -eq 1 ] && echo "Yes" || echo "No")"
    
    echo "Container Runtimes:"
    echo "  - Podman: $([ $HAS_PODMAN -eq 1 ] && echo "Available" || echo "Not available")"
    echo "  - Buildah: $([ $HAS_BUILDAH -eq 1 ] && echo "Available" || echo "Not available")"
    echo "  - Docker: $([ $HAS_DOCKER -eq 1 ] && echo "Available" || echo "Not available")"
    
    echo
    if [ $HAS_PODMAN -eq 1 ]; then
        success "Rootless container setup is ready for OpenCode workspace"
        echo
        echo "Next steps:"
        echo "  1. Use 'opencode-container-helper' for container operations"
        echo "  2. Configure GitHub Actions runner with containerMode = 'rootless'"
        echo "  3. Test with OpenCode workspace action"
    elif [ $HAS_DOCKER -eq 1 ] && [ $CGROUP_WRITABLE -eq 1 ]; then
        warning "Only Docker available and cgroups are writable"
        warning "This may work but consider installing Podman for better rootless support"
    else
        error "Container environment not properly configured"
        echo
        echo "To fix this:"
        echo "  1. Install Podman: Add 'podman' to your Nix configuration"
        echo "  2. Run: configure-rootless-containers"
        echo "  3. Re-run this verification script"
    fi
}

# Main execution
main() {
    check_kubernetes_env
    echo
    check_container_runtimes
    echo
    test_rootless_containers
    echo
    test_docker_fallback
    echo
    test_helper_script
    echo
    test_build_functionality
    echo
    generate_summary
}

# Run main function
main "$@"