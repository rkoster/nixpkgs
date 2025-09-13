# GitHub Actions Runner with Firecracker

This module provides a GitHub Actions runner that runs in an isolated Firecracker VM for enhanced security.

## Usage

Add to your `home.nix` or role configuration:

```nix
{
  programs.github-runner-firecracker = {
    enable = true;
    repository = "myorg/myproject";
    token = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"; # Get from GitHub repo settings
    runnerName = "my-firecracker-runner";
    vmMemory = 4096; # 4GB RAM
    vmCpus = 4;
  };
}
```

## Getting a Runner Token

1. Go to your GitHub repository
2. Navigate to Settings → Actions → Runners
3. Click "New self-hosted runner"
4. Copy the token from the configuration command

## Features

- **True VM isolation**: Runs in Firecracker microVM
- **Docker-in-Docker support**: Full Docker daemon inside VM
- **Automatic setup**: Downloads Ubuntu image and configures runner
- **Systemd management**: Starts/stops with user session
- **Resource limits**: Configurable CPU and memory

## Security

The runner is completely isolated from the host system:
- Separate kernel and network stack
- No access to host filesystem
- Cannot escape VM boundaries
- Automatic cleanup on restart

## Requirements

- Linux x86_64 system
- KVM support enabled
- Network access for downloading images

## Manual Control

```bash
# Start the runner
systemctl --user start github-runner-firecracker

# Stop the runner
systemctl --user stop github-runner-firecracker

# Check status
systemctl --user status github-runner-firecracker

# View logs
journalctl --user -u github-runner-firecracker -f
```