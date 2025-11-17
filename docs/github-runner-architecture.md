# GitHub Actions Runner Architecture

## Overview

This document describes the multi-AutoscalingRunnerSet architecture used for GitHub Actions runners in this home-manager configuration. This approach provides simplified cache management and automatic load balancing for containerized workflows.

## Architecture Design

### Multi-AutoscalingRunnerSet Pattern

Instead of a single large AutoscalingRunnerSet with complex cache partitioning, we deploy multiple small AutoscalingRunnerSets for each repository:

```
Repository: rkoster/rubionic-workspace
├── arc-runner-rkoster-rubionic-workspace-0 (maxRunners: 1)
├── arc-runner-rkoster-rubionic-workspace-1 (maxRunners: 1)  
└── arc-runner-rkoster-rubionic-workspace-2 (maxRunners: 1)
```

Each AutoscalingRunnerSet has:
- **Dedicated cache partition** with isolated storage
- **Independent scaling** from 0-1 runners
- **Clean PVC management** via workVolumeClaimTemplate
- **No cross-set coordination** required

### Benefits Over Single Large Set

#### **1. Simplified Cache Management**
- **No subPath coordination** → Each set has dedicated volumes
- **No cache locks** → Complete isolation between sets
- **No partition logic** → Clean hostPath per set
- **Predictable cache behavior** → No coordination complexity

#### **2. Better Cache Locality**
- **Issue-based affinity** → Related work uses same cache
- **Deterministic distribution** → Same issue always uses same runner
- **Improved cache hit rates** → Follow-up work benefits from warm caches

#### **3. Operational Simplicity**
- **Easy debugging** → "Issue 123 problems? Check runner-0"
- **Clear resource attribution** → Each set has dedicated resources  
- **Independent scaling** → Sets scale based on individual demand

## Load Balancing Strategy

### Issue Number Modulo Distribution

Workflow selection uses issue number modulo operation for automatic, deterministic load balancing:

```yaml
jobs:
  opencode:
    runs-on: arc-runner-rkoster-rubionic-workspace-${{ github.event.issue.number % 3 }}
```

### Distribution Examples

```
Issue #1 → (1 % 3) + 1 = 2 → arc-runner-rkoster-rubionic-workspace-2
Issue #2 → (2 % 3) + 1 = 3 → arc-runner-rkoster-rubionic-workspace-3  
Issue #3 → (3 % 3) + 1 = 1 → arc-runner-rkoster-rubionic-workspace-1
Issue #4 → (4 % 3) + 1 = 2 → arc-runner-rkoster-rubionic-workspace-2
...
```

**Result**: Perfect even distribution over time with cache affinity for related work.

### Cache Affinity Benefits

- **Same Issue → Same Runner → Same Cache**
- **Follow-up comments** use the same cache partition
- **Related iterations** benefit from previous builds
- **Debugging sessions** have warm caches from initial runs

## Technical Implementation

### Nix Configuration

```nix
programs.github-runner-kind = {
  repositories = [{
    name = "rkoster/rubionic-workspace";
    instances = 3;  # Creates 3 separate AutoscalingRunnerSets
    maxRunners = 1; # Each set scales 0-1 runners
    containerMode = "kubernetes";
    workVolumeClaimTemplate = {
      storageClassName = "standard";
      accessModes = ["ReadWriteOnce"];
      storage = "10Gi";
    };
  }];
};
```

### Kubernetes Resources Created

For each instance, the system creates:
- **AutoscalingRunnerSet**: `arc-runner-rkoster-rubionic-workspace-{1,2,3}`
- **ServiceAccount**: For runner pod permissions
- **RBAC**: Role and RoleBinding for job container creation
- **Secret**: GitHub token for runner registration
- **Listener Pod**: Webhook receiver for job events

### Volume Management

Each AutoscalingRunnerSet gets dedicated storage:

```yaml
# Instance 0:
volumes:
  - name: work
    ephemeral:
      volumeClaimTemplate:
        spec:
          storageClassName: "standard"
          resources:
            requests:
              storage: "10Gi"

# Instance 1: (separate PVC)
# Instance 2: (separate PVC)
```

## Workflow Integration

### Repository Workflow Configuration

Workflows in target repositories should use the modulo selection pattern:

```yaml
name: OpenCode Bot
on:
  issue_comment:
    types: [created]

jobs:
  opencode:
    # Issue number modulo distribution across 3 runners
    runs-on: arc-runner-rkoster-rubionic-workspace-${{ github.event.issue.number % 3 + 1 }}
    container:
      image: ghcr.io/rkoster/opencode-runner:latest
    steps:
      - name: Run OpenCode
        run: opencode "${{ github.event.comment.body }}"
```

**Note**: The `+ 1` is needed because our runner instances are numbered 1, 2, 3 (not 0, 1, 2).

### Alternative Selection Strategies

For non-issue-based workflows, other distribution methods can be used:

```bash
# Time-based distribution
runs-on: arc-runner-rkoster-rubionic-workspace-${{ github.run_number % 3 + 1 }}

# Hash-based distribution  
runs-on: arc-runner-rkoster-rubionic-workspace-${{ hashFiles('**/package.json') % 3 + 1 }}

# Manual selection for specific workloads
runs-on: arc-runner-rkoster-rubionic-workspace-1  # Always use cache partition 1
```

## Monitoring and Debugging

### Runner Set Status

Check all runner sets for a repository:

```bash
# View all sets
kubectl get AutoscalingRunnerSet -n arc-runners -l actions.github.com/repository=rubionic-workspace

# Check specific set
kubectl get pods -n arc-runners -l app.kubernetes.io/instance=arc-runner-rkoster-rubionic-workspace-1
```

### Issue-to-Runner Mapping

To determine which runner handled a specific issue:

```bash
ISSUE_NUMBER=123
RUNNER_INDEX=$(((ISSUE_NUMBER % 3) + 1))
echo "Issue $ISSUE_NUMBER → Runner arc-runner-rkoster-rubionic-workspace-$RUNNER_INDEX"
```

### Cache Investigation

Each runner set has dedicated cache storage that can be inspected:

```bash
# For kind cluster (hostPath storage)
ls -la /tmp/github-runner-cache/arc-runner-rkoster-rubionic-workspace-1/
ls -la /tmp/github-runner-cache/arc-runner-rkoster-rubionic-workspace-2/
ls -la /tmp/github-runner-cache/arc-runner-rkoster-rubionic-workspace-3/
```

## Migration from Single Set

When migrating from a single AutoscalingRunnerSet with complex partitioning:

1. **Document current cache state** and important cached data
2. **Deploy new multi-set configuration** alongside existing setup  
3. **Update workflow** to use modulo selection pattern
4. **Verify functionality** with new architecture
5. **Remove old single set** after confirming success
6. **Clean up legacy cache partitions** and coordination logic

## Best Practices

### Configuration
- **Keep maxRunners = 1** per set to maintain cache isolation
- **Use consistent instance counts** across repository configurations
- **Monitor total resource usage** across all sets

### Workflow Design
- **Use issue number modulo** for natural load balancing
- **Implement fallback logic** for non-issue events
- **Consider cache warming strategies** for cold starts

### Operations
- **Monitor all runner sets** during troubleshooting
- **Check correct runner assignment** when debugging specific issues
- **Verify cache affinity** is working as expected

## Future Considerations

- **Dynamic instance scaling** based on repository activity
- **Cross-repository runner sharing** for similar workloads  
- **Cache pre-warming strategies** for improved performance
- **Integration with GitHub's ephemeral runner features**

This architecture provides a clean, scalable approach to self-hosted GitHub Actions runners with excellent cache management and operational simplicity.