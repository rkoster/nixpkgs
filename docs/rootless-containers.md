# Rootless Containers for OpenCode Workspace

This configuration provides rootless container support to work around cgroup read-only filesystem issues in Kubernetes environments.

## Problem Statement

When running Docker containers inside Kubernetes job containers, you may encounter:

```
/sys/fs/cgroup/cgroup.subtree_control: Read-only file system
```

This occurs because Kubernetes mounts the cgroup filesystem as read-only for security reasons, preventing Docker from managing cgroups normally.

## Solution: Rootless Containers

This setup provides three complementary approaches:

### 1. Podman Rootless Mode
- **What**: Container runtime that uses user namespaces instead of requiring root privileges
- **Why**: Bypasses cgroup delegation requirements that cause the read-only filesystem error
- **How**: Configured automatically via `.config/containers/containers.conf`

### 2. Buildah Image Building
- **What**: Lightweight OCI container image builder
- **Why**: Can build images in restricted environments without requiring a full container daemon
- **How**: Works in user namespaces, avoiding cgroup conflicts

### 3. Enhanced GitHub Actions Runner
- **What**: Modified runner configuration with rootless container mode
- **Why**: Provides seamless integration with existing GitHub Actions workflows
- **How**: Uses `containerMode = "rootless"` in runner configuration

## Configuration

### Packages Added
- `podman`: Rootless container runtime
- `buildah`: OCI image builder
- `skopeo`: Container image tools

### Scripts Provided
- `configure-rootless-containers`: Sets up the complete rootless environment
- `opencode-container-helper`: Utility script for container operations

### GitHub Runner Modes

1. **Standard Kubernetes Mode** (`containerMode = "kubernetes"`)
   - Uses Docker with cgroup delegation
   - May fail with read-only cgroup filesystem

2. **Rootless Mode** (`containerMode = "rootless"`)
   - Uses Podman in user namespaces
   - Works around cgroup restrictions
   - Recommended for OpenCode workspace action

3. **DinD Mode** (`containerMode = "dind"`)
   - Docker-in-Docker with privileged access
   - Bypasses restrictions but requires privileged containers

## Usage

### Testing Rootless Functionality
```bash
# Test the rootless setup
opencode-container-helper test

# Check available runtimes
opencode-container-helper check
```

### Building Images
```bash
# Build with Podman (preferred)
opencode-container-helper build my-app:latest

# Build with custom Dockerfile
opencode-container-helper build my-app:latest Dockerfile.prod ./src
```

### Running Containers
```bash
# Run container with rootless mode
opencode-container-helper run alpine:latest /bin/sh

# Run with custom command
opencode-container-helper run my-app:latest /app/start.sh
```

### GitHub Actions Workflow

```yaml
name: OpenCode Workspace with Rootless Containers
on: [push, pull_request]

jobs:
  rootless-container-job:
    runs-on: arc-runner-opencode-workspace-action  # Uses rootless mode
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Test rootless containers
      run: opencode-container-helper test
    
    - name: Build application
      run: |
        # Create Dockerfile
        cat > Dockerfile <<EOF
        FROM alpine:latest
        RUN apk add --no-cache bash curl
        WORKDIR /app
        COPY . .
        CMD ["/bin/bash"]
        EOF
        
        # Build with rootless tools
        opencode-container-helper build test-app:latest
    
    - name: OpenCode workspace
      uses: rkoster/opencode-workspace-action@main
      with:
        prompt: "Test container functionality"
```

## Technical Details

### How Rootless Containers Solve the Problem

1. **User Namespaces**: Podman creates user namespaces that map container root to host user, eliminating need for real root privileges

2. **Cgroup Delegation Bypass**: Rootless containers don't require cgroup delegation, avoiding the read-only filesystem issue

3. **Overlay Storage**: Uses user-space overlay filesystem drivers that don't require kernel cgroup manipulation

4. **Network Namespaces**: Creates user network namespaces without requiring privileged operations

### Security Benefits

- **No Privileged Containers**: Eliminates security risks of privileged container execution
- **User Isolation**: Containers run with user privileges, not root
- **Namespace Isolation**: Better process and resource isolation
- **Reduced Attack Surface**: No daemon running as root

## Repository Configurations

Current setup uses different modes for different repositories:

- **rubionic-workspace**: Standard Kubernetes mode with caching
- **opencode-workspace-action**: **Rootless mode** for cgroup workaround
- **instant-bosh**: Standard Kubernetes mode

## Troubleshooting

### Common Issues

1. **Missing fuse-overlayfs**
   ```bash
   # Install on Ubuntu/Debian
   sudo apt install fuse-overlayfs
   ```

2. **Storage Driver Issues**
   ```bash
   # Check storage configuration
   podman info --format "{{.Store.GraphDriverName}}"
   ```

3. **Network Issues**
   ```bash
   # Reset Podman network configuration
   podman system reset --force
   ```

### Verification

```bash
# Verify rootless mode is working
podman run --rm alpine:latest id

# Check that we're not running as root in container
podman run --rm --userns=keep-id alpine:latest whoami

# Test cgroup access (should work even with read-only cgroups)
podman run --rm alpine:latest ls -la /sys/fs/cgroup/ || echo "Expected: cgroup access restricted"
```

## Performance Considerations

- **Rootless Mode**: Slight overhead due to user namespace mapping
- **Network**: Rootless networking may have different performance characteristics
- **Storage**: Overlay filesystem performance similar to privileged containers
- **Memory**: Lower memory overhead than Docker-in-Docker approaches

## Migration Path

To migrate from Docker to rootless containers:

1. **Update Configuration**: Change `containerMode` to `"rootless"`
2. **Test Workflows**: Verify container operations work correctly
3. **Update Scripts**: Replace `docker` commands with `podman` where needed
4. **Monitor Performance**: Check for any performance implications

This approach provides a robust solution for container operations in restricted Kubernetes environments while maintaining security and compatibility.