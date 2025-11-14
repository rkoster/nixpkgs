# GitHub Actions Runner Controller with kind

A Nix home-manager module for managing GitHub Actions Runner Controller (ARC) on a local kind (Kubernetes in Docker) cluster.

## Features

- Creates a local Kubernetes cluster using kind
- Installs GitHub Actions Runner Controller
- Manages runner scale sets for multiple repositories
- Auto-scaling runners based on workflow demand
- Simple CLI for management

## Prerequisites

- Docker running and accessible
- GitHub CLI (`gh`) authenticated
- Nix with home-manager

## Configuration

Add to your `home.nix`:

```nix
{
  programs.github-runner-kind = {
    enable = true;
    
    repositories = [
      {
        name = "myorg/myproject";
        maxRunners = 5;
        dockerCacheSize = "20Gi";  # Enable 20GB Docker layer cache
      }
      {
        name = "myorg/another-project";
        maxRunners = 10;
        minRunners = 1;
        containerMode = "kubernetes";
        instances = 3;  # Creates 3 separate runner scale sets
        dockerCacheSize = "50Gi";  # Enable 50GB Docker layer cache for each instance
      }
    ];
  };
}
```

## Configuration Options

### Repository Options

- `name` (required): GitHub repository in `owner/repo` format
- `instances` (default: 1): Number of separate runner scale set instances to create for this repository
- `installationName` (optional): Helm installation name (auto-generated from repo name if not specified)
- `minRunners` (default: 0): Minimum number of runners to keep available
- `maxRunners` (default: 5): Maximum number of runners to scale to
- `containerMode` (default: "kubernetes"): Container mode - "dind", "kubernetes", "kubernetes-novolume", "privileged-kubernetes", "rootless", or "rootless-docker"
- `dockerCacheSize` (optional): Docker layer cache size (e.g., "20Gi", "50Gi"). When set, enables Docker image layer caching for faster builds
- `dinDSidecar` (default: false): Enable Docker-in-Docker sidecar container for OpenCode workspace support
- `dinDImage` (default: "docker:24-dind"): Docker-in-Docker image to use for sidecar container  
- `dinDStorageSize` (optional): Docker storage size for DinD sidecar (e.g., "20Gi"). Uses emptyDir if not set

**Note on Multiple Instances**: When `instances > 1`, separate runner scale sets are created with instance suffixes (e.g., `arc-runner-myorg-myproject-1`, `arc-runner-myorg-myproject-2`). This allows you to have different runner pools for the same repository.

**Note on Docker Layer Caching**: When `dockerCacheSize` is specified, a persistent volume is attached to the Docker daemon for caching pulled and built image layers. This significantly speeds up subsequent builds by reusing Docker images across workflow runs.

### Global Options

- `clusterName` (default: "github-runners"): Name for the shared kind cluster
- `controllerNamespace` (default: "arc-systems"): Namespace for ARC controller pods
- `runnersNamespace` (default: "arc-runners"): Namespace for runner pods

## Usage

### Quick Start

```bash
# Complete setup (cluster + controller + all runner sets)
github-runner-kind-manage setup

# Check status
github-runner-kind-manage status

# View logs
github-runner-kind-manage logs controller
```

### Cluster Management

```bash
# Create kind cluster
github-runner-kind-manage create-cluster

# Delete kind cluster
github-runner-kind-manage delete-cluster

# Install ARC controller
github-runner-kind-manage install-controller

# Uninstall ARC controller
github-runner-kind-manage uninstall-controller
```

### Runner Scale Set Management

```bash
# Deploy runner scale set for specific repository (defaults to instance 1)
github-runner-kind-manage deploy myorg/myproject

# Deploy specific instance
github-runner-kind-manage deploy myorg/myproject:2

# Deploy all instances for a repository
github-runner-kind-manage deploy-repo-all myorg/myproject

# Deploy all configured runner scale sets
github-runner-kind-manage deploy-all

# Remove runner scale set for specific repository instance
github-runner-kind-manage remove myorg/myproject:2

# Remove all instances for a repository
github-runner-kind-manage remove-repo-all myorg/myproject

# Remove all runner scale sets
github-runner-kind-manage remove-all
```

### Monitoring

```bash
# Show cluster and all runner status
github-runner-kind-manage status

# Show status for specific repository instance
github-runner-kind-manage status myorg/myproject:2

# View controller logs
github-runner-kind-manage logs controller

# View listener pod logs
github-runner-kind-manage logs listener

# View runner pod logs
github-runner-kind-manage logs runners
```

### Complete Teardown

```bash
# Remove everything (runners + controller + cluster)
github-runner-kind-manage teardown
```

## Using Runners in Workflows

After deploying a runner scale set, use it in your GitHub Actions workflows:

```yaml
name: My Workflow
on: push

jobs:
  build:
    runs-on: arc-runner-myorg-myproject  # Use the installation name
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on ARC runner!"
  
  test:
    runs-on: arc-runner-myorg-myproject-2  # Use instance 2
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on instance 2!"
```

The `runs-on` label should match the installation name:
- Single instance: `arc-runner-{owner}-{repo}` (with `/` replaced by `-`)
- Multiple instances: `arc-runner-{owner}-{repo}-{instance-number}`

To see available runner labels, run:
```bash
github-runner-kind-manage status
```

## Docker Image Layer Caching

When `dockerCacheSize` is configured for a repository, runners will have a persistent volume mounted at `/var/lib/docker` in the Docker daemon container. This caches:

- **Pulled Docker images** from registries (docker.io, ghcr.io, etc.)
- **Built Docker images** from Dockerfiles in your workflows
- **Intermediate layers** created during multi-stage builds
- **Base image layers** shared across different images

### How It Works

The Docker daemon stores image layers in `/var/lib/docker`. By mounting a persistent volume here, layers persist across runner pod lifecycles, dramatically reducing:
- Image pull times (reuse cached layers)
- Build times (reuse unchanged layers)
- Network bandwidth usage
- Registry rate limiting issues

### Using Docker Layer Cache in Workflows

No changes needed in your workflows - the cache works automatically:

```yaml
name: Build Docker Image
on: push

jobs:
  build:
    runs-on: arc-runner-myorg-myproject
    steps:
      - uses: actions/checkout@v4
      
      # These will be much faster on subsequent runs
      - name: Pull base image
        run: docker pull node:18-alpine  # Cached after first pull
      
      - name: Build application image
        run: |
          docker build -t myapp .  # Reuses cached layers
      
      - name: Run tests in container
        run: docker run --rm myapp npm test
```

### Docker Cache Size Guidelines

Docker images can be large, especially for complex applications:

- **Small projects**: 20-30GB (basic Node.js, Python apps)
- **Medium projects**: 30-50GB (multiple services, different base images)
- **Large projects**: 50GB+ (complex microservices, ML workloads)
- **Multiple instances**: Each instance gets its own cache

**Tip**: Monitor cache usage with `docker system df` in your workflows to optimize sizing.

Example configuration for different project sizes:

```nix
repositories = [
  {
    name = "myorg/simple-api";
    dockerCacheSize = "20Gi";
  }
  {
    name = "myorg/microservices-monorepo";
    dockerCacheSize = "75Gi";
    instances = 2;  # 150GB total cache across instances
  }
];
```

## Docker-in-Docker (DinD) Sidecar for OpenCode Workspace

The DinD sidecar feature enables Docker access in workflows that use the `container:` directive, particularly important for OpenCode workspace actions. This solves compatibility issues where service containers don't work with job-level containers on self-hosted runners.

### When to Use DinD Sidecar

Enable DinD sidecar when your workflows use:
- **OpenCode workspace action** - Requires Docker for container management
- **Job-level containers** with `container:` in workflow files
- **Docker commands** inside containerized workflows
- **Service containers** that need Docker socket access

### Configuration

```nix
{
  programs.github-runner-kind = {
    enable = true;
    repositories = [
      {
        name = "myorg/opencode-project";
        maxRunners = 3;
        containerMode = "kubernetes";  # Keep kubernetes mode for job containers
        dinDSidecar = true;           # Enable DinD sidecar
        dinDImage = "docker:24-dind"; # Use specific Docker version
        dinDStorageSize = "30Gi";     # Persistent Docker storage
        dockerCacheSize = "20Gi";     # Additional runner cache
      }
    ];
  };
}
```

### How DinD Sidecar Works

```
┌─────────────────────────────────────────┐
│           Runner Pod                     │
│                                          │
│  ┌────────────────┐  ┌────────────────┐ │
│  │   Runner       │  │   DinD         │ │
│  │   Container    │  │   Sidecar      │ │
│  │                │  │                │ │
│  │ DOCKER_HOST=   │  │ :2375 ←────────│ │
│  │ tcp://         │  │ docker daemon  │ │
│  │ localhost:2375 │  │ privileged     │ │
│  └────────────────┘  └────────────────┘ │
│           │                   │          │
│           └─── TCP Socket ────┘          │
└─────────────────────────────────────────┘
```

1. **Runner Container**: Runs your workflow with `DOCKER_HOST=tcp://localhost:2375`
2. **DinD Sidecar**: Privileged container running Docker daemon on port 2375
3. **TCP Communication**: Runner accesses Docker via TCP instead of Unix socket
4. **Shared Network**: Both containers share the same pod network

### OpenCode Workspace Example

This configuration works perfectly with OpenCode workspace actions:

```yaml
name: OpenCode Development
on: 
  workflow_dispatch:
    inputs:
      opencode_token:
        required: true

jobs:
  code:
    runs-on: arc-runner-myorg-opencode-project  # Uses DinD sidecar
    container: ubuntu:22.04  # Job-level container supported
    steps:
      - uses: rkoster/opencode-workspace-action@main
        with:
          opencode_token: ${{ inputs.opencode_token }}
          # Action automatically detects Docker at tcp://localhost:2375
          # No additional configuration needed
```

The OpenCode workspace action automatically:
- Detects the `DOCKER_HOST` environment variable
- Uses Docker TCP socket for container management
- Works seamlessly with job-level containers

### DinD Storage Options

#### Temporary Storage (emptyDir)
```nix
{
  name = "myorg/project";
  dinDSidecar = true;
  # dinDStorageSize not set - uses emptyDir
}
```
- **Pros**: No persistent storage setup, simpler
- **Cons**: Docker cache lost when pod restarts
- **Use case**: Temporary workflows, testing

#### Persistent Storage
```nix
{
  name = "myorg/project";
  dinDSidecar = true;
  dinDStorageSize = "50Gi";  # Persistent Docker storage
}
```
- **Pros**: Docker images cached across pod restarts
- **Cons**: Uses cluster storage, slower initial pod startup
- **Use case**: Frequent workflows, large Docker images

### DinD vs Regular Docker Caching

| Feature | Regular Docker Cache | DinD Sidecar |
|---------|---------------------|---------------|
| **Purpose** | Speed up Docker builds | Enable Docker in containers |
| **Location** | `/var/lib/docker` mount | DinD container storage |
| **Compatibility** | All container modes | Works with job containers |
| **OpenCode Support** | Limited | Full support |
| **Storage** | `dockerCacheSize` | `dinDStorageSize` |

**Recommendation**: Use **both** for OpenCode workflows:
```nix
{
  name = "myorg/opencode-project";
  containerMode = "kubernetes";
  dinDSidecar = true;           # For OpenCode compatibility
  dinDStorageSize = "30Gi";     # DinD Docker storage
  dockerCacheSize = "20Gi";     # Additional runner cache
}
```

### Container Mode Compatibility

| Container Mode | Security | Job Containers | Docker API | Use Case |
|----------------|----------|----------------|------------|----------|
| `dind` | ❌ Privileged | ❌ Limited | ✅ Full | Legacy workflows |
| `kubernetes` | ✅ Secure | ✅ Full | ❌ No Docker | Standard runners |
| `kubernetes-novolume` | ✅ Secure | ✅ Full | ❌ No Docker | Minimal storage |
| `privileged-kubernetes` | ❌ Privileged | ✅ Full | ✅ Nested Docker | BOSH/systemd containers |
| `rootless` | ✅ Rootless | ✅ Full | ⚠️ Podman only | Container builds |
| `rootless-docker` | ✅ Rootless | ✅ Full | ✅ Full Docker API | Docker tools/BOSH CPI |

**Best Practice**: 
- Use `containerMode = "kubernetes"` with `dinDSidecar = true` for OpenCode workflows
- Use `containerMode = "privileged-kubernetes"` for BOSH deployments and systemd containers requiring nested Docker
- Use `containerMode = "rootless-docker"` for tools requiring Docker API (BOSH CPI, Docker Compose)
- Use `containerMode = "rootless"` for container builds with Podman

### Rootless Docker Mode

The `rootless-docker` mode provides full Docker API compatibility while maintaining security through user namespaces:

```nix
{
  name = "myorg/bosh-project";
  containerMode = "rootless-docker";
  dockerCacheSize = "15Gi";  # Persistent Docker cache
}
```

**Benefits of rootless-docker**:
- ✅ **Full Docker API compatibility** - works with BOSH Docker CPI, Docker Compose, etc.
- ✅ **Secure** - no privileged containers or root access required
- ✅ **Real Docker daemon** - `docker info`, `docker ps` work exactly as expected
- ✅ **Socket access** - tools can connect to `unix:///run/user/1000/docker.sock`
- ✅ **Layer caching** - persistent Docker layer cache with `dockerCacheSize`

**vs Podman (rootless mode)**:
- Podman is daemonless and may not work with tools expecting Docker API
- rootless-docker runs a real Docker daemon in user namespace
- Better compatibility with legacy Docker tools and scripts

**Example use cases**:
- BOSH Director with Docker CPI
- Docker Compose workflows  
- Testcontainers integration tests
- Any tool that expects `docker info` to work

### Privileged Kubernetes Mode

The `privileged-kubernetes` mode provides full privileged container support with nested Docker daemon capability, ideal for BOSH deployments and systemd-based containers:

```nix
{
  name = "myorg/bosh-project";
  containerMode = "privileged-kubernetes";
  dockerCacheSize = "30Gi";  # Docker layer cache
}
```

**Benefits of privileged-kubernetes**:
- ✅ **Full privileged access** - complete access to host kernel features
- ✅ **Nested Docker support** - can run Docker daemon inside job containers
- ✅ **Systemd compatibility** - supports systemd-based containers and services
- ✅ **cgroup access** - full access to control groups for container management
- ✅ **BOSH compatibility** - perfect for BOSH Director deployments
- ✅ **Hook-based configuration** - uses GitHub's official hook extension mechanism

**How privileged-kubernetes works**:
1. **Hook Extension**: Creates a ConfigMap with privileged security context
2. **Job Container Modification**: ARC applies privileged settings to job containers
3. **Host Resource Access**: Mounts `/sys/fs/cgroup`, `/proc`, `/sys`, `/dev`, and Docker socket
4. **Kernel Capabilities**: Adds all necessary capabilities (SYS_ADMIN, NET_ADMIN, MKNOD, etc.)

**Security considerations**:
- ⚠️ **Privileged containers** - job containers run with full host access
- ⚠️ **Host resource access** - containers can access host cgroup and Docker
- ⚠️ **Use with caution** - only for trusted workloads and controlled environments

**Example use cases**:
- **BOSH Director** deployments with Docker CPI or Garden containers
- **systemd-based** containers requiring full service management
- **Nested virtualization** workflows requiring Docker-in-Docker
- **Container runtime testing** that requires kernel-level features
- **Complex CI/CD** workflows with privileged system operations

**Configuration example**:
```nix
repositories = [
  {
    name = "myorg/bosh-deployment";
    containerMode = "privileged-kubernetes";
    maxRunners = 3;
    dockerCacheSize = "50Gi";  # Large cache for BOSH stemcells
  }
  {
    name = "myorg/systemd-services";
    containerMode = "privileged-kubernetes";
    maxRunners = 2;
    dockerCacheSize = "20Gi";
  }
];
```

**vs other container modes**:
- **vs dind**: Better job container isolation and scaling
- **vs kubernetes**: Adds privileged access and nested Docker support
- **vs rootless-docker**: Trades security for full privileged access
- **vs DinD sidecar**: Privileged containers vs separate Docker service

### Resource Configuration

DinD sidecars require additional resources:

```yaml
# Automatic resource limits applied by default:
resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    cpu: "1"
    memory: "2Gi"
```

Plan cluster capacity accordingly:
- **Small workflows**: 2-3 concurrent DinD pods
- **Medium workflows**: 4-6 concurrent DinD pods  
- **Large workflows**: 8+ concurrent DinD pods

### Troubleshooting DinD Sidecar

#### OpenCode workspace fails to start
```bash
# Check if DinD sidecar is running
kubectl get pods -n arc-runners
kubectl logs <runner-pod> -c dind

# Verify Docker TCP access
kubectl exec <runner-pod> -c runner -- curl tcp://localhost:2375/version
```

#### Docker commands fail in workflow
```bash
# Check DOCKER_HOST environment
kubectl exec <runner-pod> -c runner -- env | grep DOCKER_HOST
# Should show: DOCKER_HOST=tcp://localhost:2375

# Test Docker connectivity
kubectl exec <runner-pod> -c runner -- docker version
```

#### DinD container not starting
```bash
# Check if cluster supports privileged containers
kubectl describe pod <runner-pod>

# DinD requires privileged: true
# kind clusters support this by default
```

#### Storage issues
```bash
# Check PVC status
kubectl get pvc -n arc-runners

# Check storage usage
kubectl exec <runner-pod> -c dind -- df -h /var/lib/docker
```

### Migration from DIND Mode

If you're currently using `containerMode = "dind"`, migrate to DinD sidecar for better OpenCode support:

**Before** (DIND mode):
```nix
{
  name = "myorg/project";
  containerMode = "dind";  # Old approach
}
```

**After** (Kubernetes + DinD sidecar):
```nix
{
  name = "myorg/project";
  containerMode = "kubernetes";  # Better job container support
  dinDSidecar = true;           # Docker access via sidecar
  dinDStorageSize = "30Gi";     # Persistent Docker storage
}
```

**Benefits of migration**:
- ✅ Full OpenCode workspace support
- ✅ Better job container isolation
- ✅ More reliable scaling
- ✅ Persistent Docker caching
- ✅ Resource efficiency

## Advanced Docker Configuration

Combining both Docker layer caching and DinD sidecar for optimal performance:

```nix
repositories = [
  {
    name = "myorg/opencode-workspace";
    maxRunners = 5;
    containerMode = "kubernetes";     # Kubernetes mode for job containers
    dinDSidecar = true;              # Enable Docker via sidecar
    dinDImage = "docker:24-dind";    # Specific Docker version
    dinDStorageSize = "40Gi";        # Docker image storage (DinD)
    dockerCacheSize = "30Gi";        # Docker layer cache (runner)
  }
  {
    name = "myorg/regular-builds";
    maxRunners = 10;
    containerMode = "kubernetes";     # No DinD needed
    dockerCacheSize = "50Gi";        # Only Docker layer cache
  }
];
```

This setup provides:
- **DinD sidecar**: Docker access for OpenCode workspace (`tcp://localhost:2375`)
- **Docker layer cache**: Faster image pulls and builds (`dockerCacheSize`)
- **Persistent storage**: Both caches survive pod restarts
- **Kubernetes mode**: Full job container support

## Architecture
┌─────────────────────────────────────────┐
│           kind Cluster                   │
│                                          │
│  ┌────────────────────────────────┐     │
│  │   arc-systems namespace        │     │
│  │   - ARC Controller             │     │
│  └────────────────────────────────┘     │
│                                          │
│  ┌────────────────────────────────┐     │
│  │   arc-runners namespace        │     │
│  │   - Listener Pods              │     │
│  │   - Ephemeral Runner Pods      │     │
│  └────────────────────────────────┘     │
└─────────────────────────────────────────┘
```

## How It Works

1. **kind Cluster**: Creates a local Kubernetes cluster running in Docker
2. **ARC Controller**: Manages the lifecycle of runner scale sets
3. **Listener Pods**: Monitor GitHub for workflow jobs and request runners
4. **Runner Pods**: Ephemeral pods created on-demand to execute workflow jobs
5. **Auto-scaling**: Runners scale from `minRunners` to `maxRunners` based on demand

## Troubleshooting

### Docker not accessible
```bash
# Check Docker is running
docker ps

# Ensure user has Docker permissions
sudo usermod -aG docker $USER
# Then log out and back in
```

### GitHub authentication failed
```bash
# Authenticate GitHub CLI
gh auth login

# Verify authentication
gh auth status
```

### Cluster not found
```bash
# List kind clusters
kind get clusters

# Create cluster if missing
github-runner-kind-manage create-cluster
```

### Runner pods not starting
```bash
# Check controller logs
github-runner-kind-manage logs controller

# Check listener logs
github-runner-kind-manage logs listener

# Check pod status
kubectl get pods -n arc-runners
kubectl describe pod <pod-name> -n arc-runners
```

### Fresh start
```bash
# Complete teardown and setup
github-runner-kind-manage teardown
github-runner-kind-manage setup
```

## Comparison with Multipass Runner

| Feature | kind + ARC | Multipass |
|---------|------------|-----------|
| Platform | Linux/macOS/Windows | Linux/macOS/Windows |
| Isolation | Container (Kubernetes) | VM |
| Startup Time | Fast (~10s) | Slow (~30-60s) |
| Resource Usage | Lower | Higher |
| Scaling | Automatic | Manual |
| Architecture | Cloud-native | Traditional |
| Maintenance | Lower | Higher |

## References

- [Actions Runner Controller Documentation](https://github.com/actions/actions-runner-controller)
- [GitHub Actions Runner Controller Quickstart](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/quickstart)
- [kind Documentation](https://kind.sigs.k8s.io/)
- [Helm Documentation](https://helm.sh/docs/)
