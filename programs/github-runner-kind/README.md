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
        cacheSize = "10Gi";  # Enable 10GB cache
      }
      {
        name = "myorg/another-project";
        maxRunners = 10;
        minRunners = 1;
        containerMode = "kubernetes";
        instances = 3;  # Creates 3 separate runner scale sets
        cacheSize = "5Gi";  # Enable 5GB cache for each instance
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
- `containerMode` (default: "dind"): Container mode - either "dind" (Docker-in-Docker) or "kubernetes"
- `cacheSize` (optional): Cache size for runners (e.g., "10Gi", "5Gi"). When set, enables cache overlay for persistent storage across workflow runs

**Note on Multiple Instances**: When `instances > 1`, separate runner scale sets are created with instance suffixes (e.g., `arc-runner-myorg-myproject-1`, `arc-runner-myorg-myproject-2`). This allows you to have different runner pools for the same repository.

**Note on Caching**: When `cacheSize` is specified, a persistent volume is attached to runners for caching dependencies, build artifacts, and other data across workflow runs. This can significantly speed up subsequent builds.

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

## Caching

When `cacheSize` is configured for a repository, runners will have a persistent cache volume mounted that survives across workflow runs. This cache can be used to store:

- Package manager caches (npm, pip, cargo, etc.)
- Build artifacts
- Downloaded dependencies
- Docker layers (in dind mode)

### Using Cache in Workflows

The cache is automatically mounted at `/cache` in the runner container:

```yaml
name: Build with Cache
on: push

jobs:
  build:
    runs-on: arc-runner-myorg-myproject
    steps:
      - uses: actions/checkout@v4
      
      # Use cache for npm dependencies
      - name: Cache node modules
        run: |
          if [ -d /cache/node_modules ]; then
            cp -r /cache/node_modules ./
          fi
      
      - name: Install dependencies
        run: npm install
      
      # Save to cache
      - name: Save cache
        run: |
          mkdir -p /cache
          cp -r node_modules /cache/
      
      - name: Build
        run: npm run build
```

### Cache Size Guidelines

- **Small projects**: 5-10GB
- **Medium projects**: 10-20GB  
- **Large projects**: 20GB+
- **Multiple instances**: Consider total storage when using multiple instances per repository

Example configuration for different project sizes:

```nix
repositories = [
  {
    name = "myorg/small-frontend";
    cacheSize = "5Gi";
  }
  {
    name = "myorg/large-monorepo";
    cacheSize = "25Gi";
    instances = 2;  # 50GB total cache across instances
  }
];
```

## Architecture

```
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
