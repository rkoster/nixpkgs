# GitHub Actions Runner with Multipass

This module provides a GitHub Actions self-hosted runner using Multipass VMs instead of LXD containers. Multipass is generally more reliable and easier to set up than LXD.

## Features

- **Isolated VM Environment**: Each runner runs in its own Ubuntu VM
- **Docker Support**: Includes Docker installation and configuration
- **Auto-configuration**: Uses cloud-init for automated setup
- **Management Scripts**: Easy VM lifecycle management
- **Monitoring**: Systemd service for monitoring
- **Cross-platform**: Works on Linux, macOS, and Windows

## Prerequisites

1. **Install Multipass**:
   ```bash
   # Ubuntu/Debian
   sudo snap install multipass
   
   # macOS
   brew install multipass
   
   # Windows
   # Download from https://multipass.run/
   ```

2. **Authenticate with GitHub CLI**:
   ```bash
   # Install GitHub CLI if not already available
   # (Usually included in the Nix configuration)
   
   # Authenticate with GitHub
   gh auth login
   ```

   The module will automatically generate fresh registration tokens using `gh` CLI when starting the runner. No token files are stored on disk.

## Configuration

Add to your `home.nix`:

```nix
{
  programs.github-runner-multipass = {
    enable = true;
    repository = "your-org/your-repo";
    runnerName = "my-multipass-runner";
    vmMemory = "4G";
    vmCpus = 2;
    vmDisk = "20G";
    extraLabels = [ "multipass" "vm" "linux" "x64" "docker" "ubuntu" ];
  };
}
```

## Usage

### Start the Runner
```bash
github-runner-multipass-manage start
```

### Stop the Runner
```bash
github-runner-multipass-manage stop
```

### Check Status
```bash
github-runner-multipass-manage status
```

### View Logs
```bash
github-runner-multipass-manage logs
```

### Access VM Shell
```bash
github-runner-multipass-manage shell
```

### Get VM IP
```bash
github-runner-multipass-manage ip
```

## Architecture

```
Host System → Multipass → Ubuntu VM → systemd → GitHub Runner + Docker
```

## Advantages over LXD

1. **Reliability**: Multipass is more stable and less prone to silent failures
2. **Ease of Setup**: No complex storage pool or profile configuration needed
3. **Cross-platform**: Works on macOS and Windows, not just Linux
4. **Better Error Handling**: Clear error messages when something goes wrong
5. **Snap Integration**: Easy installation and updates via snap

## Troubleshooting

### Multipass Not Found
```bash
# Install multipass
sudo snap install multipass

# Or on macOS
brew install multipass
```

### Multipass Commands Hanging
If multipass commands hang without output:
```bash
# Restart multipass service
sudo snap restart multipass

# Check multipass daemon logs
sudo journalctl -u snap.multipass.multipassd -f

# If still hanging, try:
sudo snap remove multipass
sudo snap install multipass

# As a last resort, reboot the system
```

### VM Creation Fails
```bash
# Check multipass status
multipass version

# Restart multipass if needed
sudo snap restart multipass
```

### Token Issues
```bash
# Check GitHub CLI authentication
gh auth status

# Re-authenticate if needed
gh auth login

# Test token generation
gh api -X POST repos/your-org/your-repo/actions/runners/registration-token
```

### VM Won't Start
```bash
# Check available resources
multipass info --all

# Clean up old VMs
multipass delete --all --purge
```

### Cloud-init Issues
```bash
# Check cloud-init status in VM
multipass exec github-runner -- cloud-init status --long

# View cloud-init logs
multipass exec github-runner -- cat /var/log/cloud-init-output.log
```

## Monitoring

The module includes a systemd user service that monitors the runner:

```bash
# Check monitor service
systemctl --user status github-runner-multipass

# Follow monitor logs
journalctl --user -u github-runner-multipass -f
```

## Security Considerations

- VMs provide better isolation than containers
- Docker runs inside the VM, not on the host
- Registration tokens are auto-generated, short-lived, and never stored on host disk
- GitHub CLI authentication uses secure token storage
- Runner user has sudo access only within the VM

## Performance

- **Memory**: Default 4GB (configurable)
- **CPU**: Default 2 cores (configurable) 
- **Disk**: Default 20GB (configurable)
- **Network**: NAT with port forwarding support

## Comparison with Other Approaches

| Feature | Multipass | LXD | Podman |
|---------|-----------|-----|---------|
| Reliability | ✅ High | ⚠️ Medium | ✅ High |
| Setup Complexity | ✅ Simple | ❌ Complex | ✅ Simple |
| Cross-platform | ✅ Yes | ❌ Linux only | ✅ Yes |
| Resource Usage | ⚠️ Medium | ✅ Low | ✅ Low |
| Isolation | ✅ Full VM | ⚠️ Container | ⚠️ Container |

## Configuration Options

All configuration options:

```nix
programs.github-runner-multipass = {
  enable = true;                    # Enable the module
  repository = "owner/repo";        # GitHub repository
  vmName = "github-runner";         # VM name
  runnerName = "multipass-runner";  # Runner name in GitHub
  vmMemory = "4G";                  # VM memory
  vmCpus = 2;                       # VM CPU cores  
  vmDisk = "20G";                   # VM disk size
  ubuntuImage = "22.04";            # Ubuntu version
  extraLabels = [ "custom" ];       # Additional runner labels
  enableDocker = true;              # Enable Docker support
};
```

## Migration from LXD

If migrating from the LXD module:

1. Stop the LXD runner:
   ```bash
   github-runner-lxd-manage stop
   ```

2. Update your configuration to use `github-runner-multipass`

3. Rebuild your home-manager configuration:
   ```bash
   home-manager switch
   ```

4. Start the Multipass runner:
   ```bash
   github-runner-multipass-manage start
   ```