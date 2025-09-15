{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.github-runner-multipass;
in
{
  options.programs.github-runner-multipass = {
    enable = mkEnableOption "GitHub Actions Runner with Multipass VM";

    repository = mkOption {
      type = types.str;
      description = "GitHub repository (owner/repo format)";
      example = "myorg/myproject";
    };

    vmName = mkOption {
      type = types.str;
      default = "github-runner";
      description = "Name for the Multipass VM";
    };

    runnerName = mkOption {
      type = types.str;
      default = "multipass-runner";
      description = "Name for the GitHub runner";
    };

    vmMemory = mkOption {
      type = types.str;
      default = "4G";
      description = "Memory for the VM";
    };

    vmCpus = mkOption {
      type = types.int;
      default = 2;
      description = "Number of CPUs for the VM";
    };

    vmDisk = mkOption {
      type = types.str;
      default = "20G";
      description = "Disk size for the VM";
    };

    ubuntuImage = mkOption {
      type = types.str;
      default = "22.04";
      description = "Ubuntu image to use for the VM";
    };

    extraLabels = mkOption {
      type = types.listOf types.str;
      default = [ "multipass" "vm" "linux" "x64" "docker" "ubuntu" ];
      description = "Additional labels for the runner";
    };

    enableDocker = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Docker support in the VM";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      cloud-utils
    ];

    # Create cloud-init user-data configuration
    home.file.".config/github-runner-multipass/cloud-init-user-data.yaml" = {
      text = ''
        #cloud-config
        hostname: ${cfg.vmName}
        
        users:
          - name: runner
            uid: 1001
            shell: /bin/bash
            groups: [sudo, docker]
            lock_passwd: false

        packages:
          - curl
          - wget
          - git
          - jq
          - build-essential
          - ca-certificates
          - gnupg
          - lsb-release
          ${optionalString cfg.enableDocker "- docker.io"}
          ${optionalString cfg.enableDocker "- docker-compose"}

        package_update: true
        package_upgrade: true

        runcmd:
          # Configure sudo to match upstream Dockerfile
          - echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers
          - echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers
          ${optionalString cfg.enableDocker "# Configure Docker if enabled"}
          ${optionalString cfg.enableDocker "- systemctl enable docker"}
          ${optionalString cfg.enableDocker "- systemctl start docker"}
          ${optionalString cfg.enableDocker "- usermod -aG docker runner"}
          # Download and install GitHub Actions runner
          - mkdir -p /home/runner/actions-runner
          - cd /home/runner/actions-runner
          - curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
          - tar xzf actions-runner-linux-x64.tar.gz
          - chown -R runner:runner /home/runner/actions-runner
          - rm actions-runner-linux-x64.tar.gz
          
          # Install dependencies
          - /home/runner/actions-runner/bin/installdependencies.sh
          
          # Set proper permissions for svc.sh scripts and ensure runner user can access everything
          - chmod +x /home/runner/actions-runner/svc.sh
          - chmod +x /home/runner/actions-runner/runsvc.sh
          - chmod 755 /home/runner
          - chmod 755 /home/runner/actions-runner
          
          # Create work directory for runner with proper permissions
          - mkdir -p /home/runner/work
          - mkdir -p /home/runner/work/_temp
          - mkdir -p /home/runner/work/_temp/_runner_file_commands
          - chown -R runner:runner /home/runner/work
          - chmod -R 755 /home/runner/work
          
          # Ensure runner user owns its home directory completely
          - chown -R runner:runner /home/runner

        final_message: "GitHub runner VM setup complete. Ready for token injection and service installation."
      '';
    };

    # Create systemd user service to manage the Multipass VM lifecycle
    systemd.user.services.github-runner-multipass = {
      Unit = {
        Description = "GitHub Actions Runner Multipass VM";
        After = [ "network.target" ];
        Wants = [ "network.target" ];
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        TimeoutStartSec = "600";  # 10 minutes for VM creation and setup
        TimeoutStopSec = "300";   # 5 minutes for cleanup
        
        ExecStart = let
          startScript = pkgs.writeShellScript "start-github-runner-multipass.sh" ''
            #!/bin/bash
            set -euo pipefail
            
            echo "Starting GitHub Actions Runner Multipass service..."
            
            # Check if gh CLI is available and authenticated
            if ! command -v gh >/dev/null 2>&1; then
              echo "Error: GitHub CLI (gh) not found"
              echo "Install with: nix-env -iA nixpkgs.gh"
              echo "Cannot start runner without GitHub CLI"
              exit 1
            fi
            
            if ! gh auth status >/dev/null 2>&1; then
              echo "Error: GitHub CLI not authenticated"
              echo "Run: gh auth login"
              echo "Cannot start runner without authentication"
              exit 1
            fi
            
            # Start the runner using the management script
            exec ${config.home.homeDirectory}/.local/bin/github-runner-multipass-manage start
          '';
        in "${startScript}";
        
        ExecStop = let
          stopScript = pkgs.writeShellScript "stop-github-runner-multipass.sh" ''
            #!/bin/bash
            set -euo pipefail
            
            echo "Stopping GitHub Actions Runner Multipass service..."
            
            # Stop the runner using the management script
            exec ${config.home.homeDirectory}/.local/bin/github-runner-multipass-manage stop
          '';
        in "${stopScript}";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Create management script
    home.file.".local/bin/github-runner-multipass-manage" = {
      text = ''
        #!/bin/bash
        set -euo pipefail
        
        VM_NAME="${cfg.vmName}"
        CONFIG_DIR="${config.home.homeDirectory}/.config/github-runner-multipass"
        
        check_multipass_ready() {
          if ! command -v multipass >/dev/null 2>&1; then
            echo "Error: Multipass command not found. Please ensure Multipass is installed."
            echo "Install with: sudo snap install multipass"
            exit 1
          fi
          
          # Check if Multipass daemon is running
          if ! multipass version >/dev/null 2>&1; then
            echo "Error: Multipass daemon not running."
            echo "Please start multipass service: sudo snap restart multipass"
            exit 1
          fi
        }
        
        case "''${1:-}" in
          start)
            echo "Starting GitHub runner Multipass VM..."
            check_multipass_ready
            
            # Get fresh GitHub registration token using gh CLI
            echo "Getting fresh GitHub registration token..."
            if command -v gh >/dev/null 2>&1; then
              if gh auth status >/dev/null 2>&1; then
                echo "Generating new registration token with gh CLI..."
                GITHUB_TOKEN=$(gh api -X POST repos/${cfg.repository}/actions/runners/registration-token --jq '.token')
                if [ -z "$GITHUB_TOKEN" ]; then
                  echo "✗ Failed to get registration token from GitHub API"
                  echo "Please ensure you have proper permissions for repository: ${cfg.repository}"
                  exit 1
                fi
                echo "✓ Fresh registration token obtained"
              else
                echo "Error: GitHub CLI not authenticated"
                echo "Please run: gh auth login"
                exit 1
              fi
            else
              echo "Error: GitHub CLI (gh) not found"
              echo "Please install gh CLI: nix-env -iA nixpkgs.gh"
              exit 1
            fi
            
            # Stop existing VM if it exists
            if multipass info "$VM_NAME" >/dev/null 2>&1; then
              echo "Stopping existing VM..."
              multipass stop "$VM_NAME" || true
              multipass delete "$VM_NAME" || true
              multipass purge || true
            fi
            
            echo "Creating Multipass VM $VM_NAME..."
            multipass launch ${cfg.ubuntuImage} \
              --name "$VM_NAME" \
              --memory ${cfg.vmMemory} \
              --cpus ${toString cfg.vmCpus} \
              --disk ${cfg.vmDisk} \
              --cloud-init <(cat "$CONFIG_DIR/cloud-init-user-data.yaml")
            
            echo "Waiting for VM to be ready..."
            sleep 30
            
            # Wait for cloud-init to complete
            echo "Waiting for cloud-init to complete..."
            timeout=300
            elapsed=0
            while [ $elapsed -lt $timeout ]; do
              if multipass exec "$VM_NAME" -- cloud-init status --format=json 2>/dev/null | grep -q '"status": "done"'; then
                echo "Cloud-init completed successfully"
                break
              fi
              echo "Still waiting for cloud-init... (''${elapsed}s)"
              sleep 10
              elapsed=$((elapsed + 10))
            done
            
            if [ $elapsed -ge $timeout ]; then
              echo "Warning: Cloud-init may not have completed within timeout"
            fi
            
            # Debug: Check VM setup
            echo "Checking VM setup..."
            echo "VM status:"
            multipass info "$VM_NAME" || echo "Warning: could not get VM info"
            
            echo "Checking if runner user exists:"
            multipass exec "$VM_NAME" -- id runner 2>/dev/null || echo "Warning: runner user not found"
            
            echo "Cloud-init status:"
            multipass exec "$VM_NAME" -- cloud-init status --long 2>/dev/null || echo "Warning: cloud-init status check failed"
            
            echo "VM file system structure:"
            multipass exec "$VM_NAME" -- ls -la /home/ 2>/dev/null || echo "Warning: could not list /home"
            
            echo "Copying GitHub token..."
            
            # Verify we have a valid token
            if [ -z "$GITHUB_TOKEN" ]; then
              echo "Error: GitHub token is empty"
              exit 1
            fi
            
             # Create work directory for runner with proper permissions
             echo "Creating runner work directory..."
             multipass exec "$VM_NAME" -- sudo mkdir -p /home/runner/work || {
               echo "Error: Failed to create /home/runner/work directory"
               exit 1
             }
             
             multipass exec "$VM_NAME" -- sudo mkdir -p /home/runner/work/_temp || {
               echo "Error: Failed to create /home/runner/work/_temp directory"
               exit 1
             }
             
             multipass exec "$VM_NAME" -- sudo mkdir -p /home/runner/work/_temp/_runner_file_commands || {
               echo "Error: Failed to create /home/runner/work/_temp/_runner_file_commands directory"
               exit 1
             }
             
             echo "Setting ownership and permissions of work directory..."
             multipass exec "$VM_NAME" -- sudo chown -R runner:runner /home/runner/work || {
               echo "Error: Failed to set ownership of /home/runner/work"
               exit 1
             }
             
             multipass exec "$VM_NAME" -- sudo chmod -R 755 /home/runner/work || {
               echo "Error: Failed to set permissions of /home/runner/work"
               exit 1
             }
            
            # Copy the token directly to VM using multipass exec
            echo "Copying token to VM..."
            if echo "$GITHUB_TOKEN" | multipass exec "$VM_NAME" -- sudo -u runner bash -c "cat > /home/runner/github-token"; then
              echo "✓ Token copied successfully to VM"
            else
              echo "✗ Failed to copy token to VM"
              echo "Debugging VM state:"
              multipass info "$VM_NAME"
              exit 1
            fi
            
            echo "Setting token file permissions..."
            multipass exec "$VM_NAME" -- sudo chmod 600 /home/runner/github-token || {
              echo "Error: Failed to set token file permissions"  
              exit 1
            }
            
            echo "Verifying token in VM..."
            multipass exec "$VM_NAME" -- sudo -u runner ls -la /home/runner/github-token || {
              echo "Error: Token file not found in VM after copy"
              exit 1
            }
            
            echo "Getting fresh token for service start..."
            FRESH_TOKEN=$(gh api -X POST repos/${cfg.repository}/actions/runners/registration-token --jq '.token')
            if [ -z "$FRESH_TOKEN" ]; then
              echo "Warning: Could not get fresh token, using original token"
            else
              echo "Updating token in VM with fresh token..."
              echo "$FRESH_TOKEN" | multipass exec "$VM_NAME" -- sudo -u runner bash -c "cat > /home/runner/github-token"
            fi
            
            echo "Starting GitHub runner service..."
            
            # Configure the runner first
            echo "Configuring GitHub runner..."
            multipass exec "$VM_NAME" -- sudo -u runner bash -c "cd /home/runner/actions-runner && ./config.sh --url https://github.com/${cfg.repository} --token \$(cat /home/runner/github-token) --name ${cfg.runnerName} --labels ${concatStringsSep "," cfg.extraLabels} --work /home/runner/work --unattended --replace"
            
            # Install and start the service using the official svc.sh script
            echo "Installing GitHub runner service..."
            multipass exec "$VM_NAME" -- sudo -u runner bash -c "cd /home/runner/actions-runner && sudo ./svc.sh install runner"
            
            echo "Starting GitHub runner service..."
            multipass exec "$VM_NAME" -- sudo bash -c "cd /home/runner/actions-runner && ./svc.sh start"
            
            echo "GitHub runner started successfully!"
            echo "VM IP: $(multipass info "$VM_NAME" --format csv | tail -n +2 | cut -d, -f3)"
            ;;
            
           stop)
             if multipass info "$VM_NAME" >/dev/null 2>&1; then
               echo "Checking if runner directory exists..."
               if multipass exec "$VM_NAME" -- test -d /home/runner/actions-runner 2>/dev/null; then
                 echo "Stopping GitHub runner service..."
                 multipass exec "$VM_NAME" -- sudo bash -c "cd /home/runner/actions-runner && test -f ./svc.sh && ./svc.sh stop" || echo "Warning: Could not stop service (may not be running)"
                 
                 echo "Uninstalling GitHub runner service..."
                 multipass exec "$VM_NAME" -- sudo bash -c "cd /home/runner/actions-runner && test -f ./svc.sh && ./svc.sh uninstall" || echo "Warning: Could not uninstall service"
                 
                 echo "Deregistering GitHub runner..."
                 # Get fresh token for deregistration
                 if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                   FRESH_TOKEN=$(gh api -X POST repos/${cfg.repository}/actions/runners/registration-token --jq '.token' 2>/dev/null || echo "")
                   if [ -n "$FRESH_TOKEN" ]; then
                     echo "$FRESH_TOKEN" | multipass exec "$VM_NAME" -- sudo -u runner bash -c "cat > /home/runner/github-token"
                   fi
                 fi
                 multipass exec "$VM_NAME" -- sudo -u runner bash -c "cd /home/runner/actions-runner && test -f ./config.sh && ./config.sh remove --token \$(cat /home/runner/github-token)" || echo "Warning: Failed to deregister runner"
               else
                 echo "Runner directory not found - skipping service cleanup"
               fi
               
               echo "Stopping Multipass VM..."
               multipass stop "$VM_NAME" || true
               
               echo "Deleting Multipass VM..."
               multipass delete "$VM_NAME" || true
               multipass purge || true
               
               echo "GitHub runner Multipass VM stopped and removed"
             else
               echo "VM $VM_NAME does not exist"
             fi
             ;;
            
          restart)
            $0 stop
            sleep 5
            $0 start
            ;;
            
          status)
            echo "=== Multipass VM Status ==="
            if multipass info "$VM_NAME" >/dev/null 2>&1; then
              multipass info "$VM_NAME"
              echo ""
               echo "=== GitHub Runner Service Status ==="
               # The service name will be dynamically generated by svc.sh, so check for actions.runner.* services
               multipass exec "$VM_NAME" -- sudo systemctl status "actions.runner.*" 2>/dev/null || multipass exec "$VM_NAME" -- sudo systemctl status github-runner 2>/dev/null || echo "Service not found"
              echo ""
              echo "=== Cloud-init Status ==="
              multipass exec "$VM_NAME" -- cloud-init status || true
            else
              echo "VM $VM_NAME does not exist"
              echo "Run 'github-runner-multipass-manage start' to create it"
            fi
            ;;
            
           logs)
             if multipass info "$VM_NAME" >/dev/null 2>&1; then
               echo "=== GitHub Runner Logs ==="
               # Try to find the service name created by svc.sh
               SERVICE_NAME=$(multipass exec "$VM_NAME" -- sudo systemctl list-units --type=service --state=active | grep "actions.runner" | head -1 | awk '{print $1}' || echo "")
               if [ -n "$SERVICE_NAME" ]; then
                 multipass exec "$VM_NAME" -- sudo journalctl -u "$SERVICE_NAME" -f
               else
                 echo "GitHub runner service not found or not active"
                 multipass exec "$VM_NAME" -- sudo systemctl list-units --type=service | grep -E "(github|actions|runner)" || echo "No runner services found"
               fi
             else
               echo "VM $VM_NAME does not exist"
               exit 1
             fi
             ;;
            
          shell)
            if multipass info "$VM_NAME" >/dev/null 2>&1; then
              multipass exec "$VM_NAME" -- sudo -u runner -i
            else
              echo "VM $VM_NAME does not exist"
              exit 1
            fi
            ;;
            
          ip)
            if multipass info "$VM_NAME" >/dev/null 2>&1; then
              multipass info "$VM_NAME" --format csv | tail -n +2 | cut -d, -f3
            else
              echo "VM $VM_NAME does not exist"
              exit 1
            fi
            ;;
            
          *)
            echo "Usage: $0 {start|stop|restart|status|logs|shell|ip}"
            echo ""
            echo "  start   - Create and start the GitHub runner VM"
            echo "  stop    - Stop and remove the Multipass VM"
            echo "  restart - Restart the Multipass VM"
            echo "  status  - Show VM and service status"
            echo "  logs    - Follow GitHub runner logs"
            echo "  shell   - Open shell in the VM as runner user"
            echo "  ip      - Show VM IP address"
            echo ""
            echo "First time setup:"
            echo "  1. Ensure Multipass is running: sudo snap restart multipass"
            echo "  2. Authenticate with GitHub: gh auth login"
            echo "  3. github-runner-multipass-manage start"
            echo ""
            echo "Note: Registration tokens are automatically generated using gh CLI"
            exit 1
            ;;
        esac
      '';
      executable = true;
    };
  };
}