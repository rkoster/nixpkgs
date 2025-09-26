# GitHub Actions Runner with Multipass

This module provides a GitHub Actions self-hosted runner using Multipass VMs instead of LXD containers. Multipass is generally more reliable and easier to set up than LXD.

## Features

- **Multi-Repository Support**: Create independent runners for multiple GitHub repositories
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

### Multi-Repository Configuration (Recommended)

Add to your `home.nix` for multiple repositories:

```nix
{
  programs.github-runner-multipass = {
    enable = true;
    repositories = [
      {
        name = "myorg/project1";
        instances = 2;           # Run 2 instances for parallel jobs
        vmMemory = "2G";
        vmCpus = 1;
        extraLabels = [ "small" "project1" ];
      }
      {
        name = "myorg/project2";
        instances = 1;           # Single instance (default)
        vmMemory = "8G";
        vmCpus = 4;
        vmDisk = "30G";
        extraLabels = [ "large" "gpu" "project2" ];
        ubuntuImage = "20.04";
      }
      {
        name = "anotherorg/different-repo";
        instances = 3;           # High availability setup
        # Uses default values for unspecified options
      }
    ];
  };
}
```

Each repository entry can specify:
- `name`: Repository in "owner/repo" format (required)
- `instances`: Number of runner instances for this repository (default: 1)
- `vmName`: VM name (auto-generated if not specified)
- `runnerName`: Runner name in GitHub (auto-generated if not specified)
- `vmMemory`: VM memory (default: "4G")
- `vmCpus`: VM CPU cores (default: 2)
- `vmDisk`: VM disk size (default: "20G")
- `ubuntuImage`: Ubuntu version (default: "22.04")
- `extraLabels`: Additional runner labels (default: ["multipass", "vm", "linux", "x64", "docker", "ubuntu"])
- `enableDocker`: Enable Docker support (default: true)

### Multi-Instance Configuration

You can run multiple isolated instances of the runner for the same repository. This is useful for parallel job execution or high-availability setups:

```nix
{
  programs.github-runner-multipass = {
    enable = true;
    repositories = [
      {
        name = "myorg/high-traffic-project";
        instances = 3;           # Run 3 runner instances
        vmMemory = "4G";
        vmCpus = 2;
        extraLabels = [ "parallel" "high-load" ];
      }
      {
        name = "myorg/dev-project";
        instances = 1;           # Single instance (default)
        vmMemory = "2G";
        vmCpus = 1;
      }
    ];
  };
}
```

With multiple instances:
- Each instance gets a unique VM name: `runner-myorg-high-traffic-project-1`, `runner-myorg-high-traffic-project-2`, etc.
- Each instance gets a unique runner name: `multipass-myorg-high-traffic-project-1`, `multipass-myorg-high-traffic-project-2`, etc.
- Each instance runs in complete isolation with dedicated resources
- Jobs are distributed across available instances by GitHub

### Single Repository Configuration (Legacy)

For backward compatibility, you can still configure a single repository:

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

### Multi-Repository and Multi-Instance Commands

#### Instance-Specific Commands

Control individual instances using the `repository[:instance]` format:

```bash
# Start specific instances
github-runner-multipass-manage start myorg/project         # Start instance 1 (default)
github-runner-multipass-manage start myorg/project:1       # Start instance 1 (explicit)
github-runner-multipass-manage start myorg/project:2       # Start instance 2

# Stop specific instances  
github-runner-multipass-manage stop myorg/project:2
github-runner-multipass-manage restart myorg/project:1

# Status for specific instances
github-runner-multipass-manage status myorg/project:2
github-runner-multipass-manage logs myorg/project:1
github-runner-multipass-manage shell myorg/project:3
github-runner-multipass-manage ip myorg/project:1
```

#### Repository-Level Bulk Operations

Control all instances for a specific repository:

```bash
# Start all instances for a repository
github-runner-multipass-manage start-repo-all myorg/project

# Stop all instances for a repository  
github-runner-multipass-manage stop-repo-all myorg/project

# Restart all instances for a repository
github-runner-multipass-manage restart-repo-all myorg/project
```

#### Global Operations

Control all instances across all repositories:

```bash
# Start all configured instances
github-runner-multipass-manage start-all

# Stop all instances
github-runner-multipass-manage stop-all

# Restart all instances
github-runner-multipass-manage restart-all
```

#### Status and Monitoring

```bash
# Show status of all instances across all repositories
github-runner-multipass-manage status

# Show status of specific repository (all instances)
github-runner-multipass-manage status myorg/project1

# Show status of specific instance
github-runner-multipass-manage status myorg/project1:2

# List all configured repositories and instances
github-runner-multipass-manage list

# Follow logs for a specific instance
github-runner-multipass-manage logs myorg/project1:1
```

#### VM Access

```bash
# Open shell in specific instance VM
github-runner-multipass-manage shell myorg/project1:2

# Get VM IP address for specific instance
github-runner-multipass-manage ip myorg/project1:1
```

### Legacy Single Repository Commands

For backward compatibility with single repository configuration:

```bash
# These work with legacy single repository setup
github-runner-multipass-manage start
github-runner-multipass-manage stop
github-runner-multipass-manage restart
github-runner-multipass-manage status
github-runner-multipass-manage logs
github-runner-multipass-manage shell
github-runner-multipass-manage ip
```

## Architecture

### Multi-Repository and Multi-Instance Setup
```
Host System → Multipass → Multiple Ubuntu VMs → Each VM: systemd → GitHub Runner + Docker
                     ├─ VM1: org/repo1 runner (instance 1)
                     ├─ VM2: org/repo1 runner (instance 2)
                     ├─ VM3: org/repo1 runner (instance 3)
                     ├─ VM4: org/repo2 runner (instance 1)  
                     └─ VM5: org/repo3 runner (instance 1)
```

Each repository instance gets:
- Its own isolated Ubuntu VM with unique name
- Independent systemd service
- Separate GitHub runner registration  
- Isolated Docker environment
- Custom resource allocation
- Parallel job execution capability

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

### Multi-Repository Configuration

```nix
programs.github-runner-multipass = {
  enable = true;
  repositories = [
    {
      name = "owner/repo";               # Required: GitHub repository
      instances = 1;                     # Optional: Number of instances (default: 1)
      vmName = "custom-vm-name";         # Optional: VM name (auto-generated)
      runnerName = "custom-runner";      # Optional: Runner name (auto-generated)
      vmMemory = "4G";                   # Optional: VM memory (default: "4G")
      vmCpus = 2;                        # Optional: VM CPU cores (default: 2)
      vmDisk = "20G";                    # Optional: VM disk size (default: "20G")
      ubuntuImage = "22.04";             # Optional: Ubuntu version (default: "22.04")
      extraLabels = [ "custom" ];        # Optional: Additional runner labels
      enableDocker = true;               # Optional: Enable Docker support (default: true)
    }
  ];
};
```

### Legacy Single Repository Configuration

```nix
programs.github-runner-multipass = {
  enable = true;                    # Enable the module
  repository = "owner/repo";        # GitHub repository (DEPRECATED)
  vmName = "github-runner";         # VM name (DEPRECATED)
  runnerName = "multipass-runner";  # Runner name in GitHub (DEPRECATED)
  vmMemory = "4G";                  # VM memory (DEPRECATED)
  vmCpus = 2;                       # VM CPU cores (DEPRECATED)
  vmDisk = "20G";                   # VM disk size (DEPRECATED)
  ubuntuImage = "22.04";            # Ubuntu version (DEPRECATED)
  extraLabels = [ "custom" ];       # Additional runner labels (DEPRECATED)
  enableDocker = true;              # Enable Docker support (DEPRECATED)
};
```

## Migration from LXD

If migrating from the LXD module:

1. Stop the LXD runner:
   ```bash
   github-runner-lxd-manage stop
   ```

2. Update your configuration to use `github-runner-multipass` with the new multi-repository format:
   ```nix
   programs.github-runner-multipass = {
     enable = true;
     repositories = [
       {
         name = "your-org/your-repo";  # Your existing repository
         # Add any custom settings
       }
     ];
   };
   ```

3. Rebuild your home-manager configuration:
   ```bash
   home-manager switch
   ```

4. Start the Multipass runner:
   ```bash
   github-runner-multipass-manage start your-org/your-repo
   ```

## Multi-Repository and Multi-Instance Benefits

- **Resource Isolation**: Each repository and instance gets dedicated resources
- **Independent Scaling**: Configure different CPU/memory per repository and instance count
- **Failure Isolation**: One repository's or instance's issues don't affect others
- **Custom Environments**: Different Ubuntu versions, Docker configs per repo
- **Parallel Execution**: Multiple builds can run simultaneously across instances
- **High Availability**: Multiple instances provide redundancy for critical repositories
- **Load Distribution**: GitHub automatically distributes jobs across available instances
- **Easier Management**: Start/stop runners per repository or specific instances as needed