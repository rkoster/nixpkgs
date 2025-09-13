# GitHub Actions Runner with Podman

This module provides a containerized GitHub Actions runner using [Podman](https://podman.io/), offering secure isolation and easy management through systemd.

## Features

- **Container isolation**: Each runner executes in a dedicated container
- **OCI image support**: Uses standard container images (GitHub's official runner image)
- **Resource control**: Configurable CPU and memory limits
- **Rootless operation**: Runs entirely in userspace without requiring root privileges
- **Systemd integration**: Managed as a systemd user service
- **Auto-restart**: Automatically restarts on failure with configurable delay
- **Docker-in-Docker**: Supports workflows that need Docker/container builds

## Security Benefits

- **Process isolation**: Containers provide strong process and filesystem isolation
- **Minimal attack surface**: Podman is a mature, security-focused container runtime
- **No daemon**: Podman runs without a privileged daemon
- **Clean environment**: Each run starts with a fresh container instance

## Current Implementation Status

✅ **Completed:**
- Migration from krunvm to Podman for better compatibility
- Systemd user service configuration
- Management script for easy control
- Container configuration and networking setup
- Token management and security

⚠️ **Known Issue:**
The implementation currently faces a limitation with rootless containers requiring `newuidmap`/`newgidmap` tools with setuid capabilities. This is a common challenge in Nix environments where setuid binaries aren't supported for security reasons.

**Current Error:** `Error: command required for rootless mode with multiple IDs: exec: "newuidmap": executable file not found in $PATH`

**Potential Solutions:**
1. Install system uidmap packages outside of Nix
2. Use rootful Podman (requires system-level setup)
3. Consider alternative container runtimes
4. Use crun-vm approach for true VM isolation (requires additional setup)

## Configuration

### Basic Setup

```nix
{
  programs.github-runner-container = {
    enable = true;
    repository = "owner/repository";
    runnerName = "my-podman-runner";
  };
}
```

### Advanced Configuration

```nix
{
  programs.github-runner-container = {
    enable = true;
    repository = "myorg/myproject";
    
    # Container resource allocation
    vmMemory = "4096";  # MB (for future VM support)
    vmCpus = "4";
    
    # Runner configuration
    runnerName = "production-runner";
    image = "ghcr.io/actions/actions-runner:latest";
    extraLabels = [ "podman" "container" "high-memory" "docker" ];
    
    # Storage
    workDir = "/home/user/runner-workspace";
    tokenFile = "/home/user/.secrets/github-token";
  };
}
```

## Setup Requirements

1. **GitHub Token**: Create a personal access token or use a GitHub App token with repository permissions
2. **Token File**: Store the token in the configured file path (default: `~/.github-runner-token`)
3. **System uidmap tools**: For rootless containers (see troubleshooting section)

```bash
echo "your-github-token" > ~/.github-runner-token
chmod 600 ~/.github-runner-token
```

## Usage

After configuring and rebuilding your home-manager configuration:

```bash
# Use the management script
~/.local/bin/github-runner-manage start
~/.local/bin/github-runner-manage status
~/.local/bin/github-runner-manage logs
~/.local/bin/github-runner-manage stop

# Or use systemctl directly
systemctl --user status github-runner
systemctl --user start github-runner
journalctl --user -u github-runner -f
```

## Troubleshooting

### Common Issues

1. **newuidmap not found error**
   ```bash
   # Install system uidmap tools (Ubuntu/Debian)
   sudo apt update && sudo apt install -y uidmap
   
   # Verify installation
   which newuidmap newgidmap
   ```

2. **Token file not found**
   - Ensure the token file exists at the configured path
   - Check file permissions (should be readable by your user)

3. **Container fails to start**
   - Check available memory and CPU resources
   - Verify the OCI image is accessible
   - Review logs with `journalctl --user -u github-runner`

4. **Runner not appearing in GitHub**
   - Verify the repository name format (owner/repo)
   - Check token permissions
   - Ensure network connectivity

### Resource Requirements

- **Memory**: Minimum 1GB, recommended 2GB+ for Docker builds
- **CPU**: At least 1 vCPU, 2+ recommended for performance
- **Disk**: Sufficient space for the work directory and container storage

## Architecture

```
┌─────────────────────────────────────────┐
│ Home Manager Service (systemd)          │
│ ┌─────────────────────────────────────┐ │
│ │ Podman                              │ │
│ │ ┌─────────────────────────────────┐ │ │
│ │ │ Container                       │ │ │
│ │ │ ┌─────────────────────────────┐ │ │ │
│ │ │ │ GitHub Actions Runner       │ │ │ │
│ │ │ │ (from OCI image)            │ │ │ │
│ │ │ └─────────────────────────────┘ │ │ │
│ │ └─────────────────────────────────┘ │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

The runner operates in a containerized environment, providing process-level isolation while maintaining compatibility with existing container tooling.

## Getting a Runner Token

1. Go to your GitHub repository
2. Navigate to Settings → Actions → Runners
3. Click "New self-hosted runner"
4. Copy the token from the configuration command
5. Save it to a file (default: `~/.github-runner-token`)

## Migration from krunvm

This implementation was migrated from krunvm to Podman for better compatibility with systemd and reduced dependency complexity. The krunvm approach required buildah unshare and faced similar rootless container challenges.

**Future Considerations:**
- Consider implementing crun-vm support for true VM isolation
- Explore rootful container options for production deployments
- Add support for multiple runner instances