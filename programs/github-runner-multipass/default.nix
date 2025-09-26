{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.github-runner-multipass;
  
  # Repository configuration type
  repositoryType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "GitHub repository (owner/repo format)";
        example = "myorg/myproject";
      };
      
      vmName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Name for the Multipass VM (auto-generated if not specified)";
      };
      
      runnerName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Name for the GitHub runner (auto-generated if not specified)";
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
      
      instances = mkOption {
        type = types.int;
        default = 1;
        description = "Number of runner instances to create for this repository";
      };
    };
  };
  
  # Process repositories to add auto-generated names
  processedRepos = map (repo: 
    let
      repoSlug = replaceStrings ["/"] ["-"] repo.name;
    in
    repo // {
      vmName = if repo.vmName != null then repo.vmName else "runner-${repoSlug}";
      runnerName = if repo.runnerName != null then repo.runnerName else "multipass-${repoSlug}";
    }
  ) cfg.repositories;
  
  # Expand repositories into individual instances
  expandedInstances = builtins.concatLists (map (repo: 
    if repo.instances > 1 then
      # Create multiple instances with numbered suffixes
      (map (instanceNum: 
        repo // {
          instanceId = instanceNum;
          vmName = "${repo.vmName}-${toString instanceNum}";
          runnerName = "${repo.runnerName}-${toString instanceNum}";
        }
      ) (builtins.genList (x: x + 1) repo.instances))
    else
      # Single instance, no suffix needed
      [ (repo // { instanceId = 1; }) ]
  ) processedRepos);
  
  # Legacy single repository support
  legacyRepo = optionalAttrs (cfg.repository != null) {
    name = cfg.repository;
    vmName = cfg.vmName;
    runnerName = cfg.runnerName;
    vmMemory = cfg.vmMemory;
    vmCpus = cfg.vmCpus;
    vmDisk = cfg.vmDisk;
    ubuntuImage = cfg.ubuntuImage;
    extraLabels = cfg.extraLabels;
    enableDocker = cfg.enableDocker;
    instances = 1;  # Legacy always has 1 instance
    instanceId = 1;
  };
  
  # Combine legacy and new repository configurations
  allRepos = if cfg.repository != null 
             then [ legacyRepo ]
             else expandedInstances;
in
{
  options.programs.github-runner-multipass = {
    enable = mkEnableOption "GitHub Actions Runner with Multipass VM";

    # New multi-repository configuration
    repositories = mkOption {
      type = types.listOf repositoryType;
      default = [];
      description = "List of GitHub repositories to create runners for";
      example = literalExpression ''
        [
          {
            name = "myorg/project1";
            vmMemory = "2G";
            extraLabels = [ "small" ];
          }
          {
            name = "myorg/project2";
            vmMemory = "8G";
            vmCpus = 4;
            extraLabels = [ "large" "gpu" ];
          }
        ]
      '';
    };

    # Legacy single repository options (deprecated but maintained for compatibility)
    repository = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "DEPRECATED: Use repositories instead. GitHub repository (owner/repo format)";
      example = "myorg/myproject";
    };

    vmName = mkOption {
      type = types.str;
      default = "github-runner";
      description = "DEPRECATED: Use repositories instead. Name for the Multipass VM";
    };

    runnerName = mkOption {
      type = types.str;
      default = "multipass-runner";
      description = "DEPRECATED: Use repositories instead. Name for the GitHub runner";
    };

    vmMemory = mkOption {
      type = types.str;
      default = "4G";
      description = "DEPRECATED: Use repositories instead. Memory for the VM";
    };

    vmCpus = mkOption {
      type = types.int;
      default = 2;
      description = "DEPRECATED: Use repositories instead. Number of CPUs for the VM";
    };

    vmDisk = mkOption {
      type = types.str;
      default = "20G";
      description = "DEPRECATED: Use repositories instead. Disk size for the VM";
    };

    ubuntuImage = mkOption {
      type = types.str;
      default = "22.04";
      description = "DEPRECATED: Use repositories instead. Ubuntu image to use for the VM";
    };

    extraLabels = mkOption {
      type = types.listOf types.str;
      default = [ "multipass" "vm" "linux" "x64" "docker" "ubuntu" ];
      description = "DEPRECATED: Use repositories instead. Additional labels for the runner";
    };

    enableDocker = mkOption {
      type = types.bool;
      default = true;
      description = "DEPRECATED: Use repositories instead. Enable Docker support in the VM";
    };
    
    instances = mkOption {
      type = types.int;
      default = 1;
      description = "DEPRECATED: Use repositories instead. Number of runner instances (always 1 for legacy mode)";
    };
  };

  config = mkIf cfg.enable {
    # Validation
    assertions = [
      {
        assertion = (cfg.repository != null) != (cfg.repositories != []);
        message = "Either use legacy 'repository' option OR new 'repositories' list, but not both";
      }
      {
        assertion = cfg.repository != null || cfg.repositories != [];
        message = "Must specify either 'repository' (legacy) or 'repositories' list";
      }
    ];

    home.packages = with pkgs; [
      cloud-utils
    ];

    # Create cloud-init user-data configuration for each repository and management script
    home.file = listToAttrs (map (repo: {
      name = ".config/github-runner-multipass/${repo.vmName}-cloud-init-user-data.yaml";
      value = {
        text = ''
          #cloud-config
          hostname: ${repo.vmName}
          
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
            ${optionalString repo.enableDocker "- docker.io"}
            ${optionalString repo.enableDocker "- docker-compose"}

          package_update: true
          package_upgrade: true

          runcmd:
            # Configure sudo to match upstream Dockerfile
            - echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers
            - echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers
            ${optionalString repo.enableDocker "# Configure Docker if enabled"}
            ${optionalString repo.enableDocker "- systemctl enable docker"}
            ${optionalString repo.enableDocker "- systemctl start docker"}
            ${optionalString repo.enableDocker "- usermod -aG docker runner"}
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
    }) allRepos) // {
      ".local/bin/github-runner-multipass-manage" = {
        text = ''
          #!/bin/bash
          set -euo pipefail
          
          CONFIG_DIR="${config.home.homeDirectory}/.config/github-runner-multipass"
          
          # Repository and Instance configurations (generated from Nix)
          declare -A INSTANCE_KEYS
          declare -A REPOS
          declare -A VM_NAMES
          declare -A RUNNER_NAMES  
          declare -A VM_MEMORY
          declare -A VM_CPUS
          declare -A VM_DISK
          declare -A UBUNTU_IMAGE
          declare -A EXTRA_LABELS
          declare -A ENABLE_DOCKER
          declare -A INSTANCE_IDS
          
          ${concatStringsSep "\n" (map (instance: 
            let
              instanceKey = "${instance.name}:${toString instance.instanceId}";
            in ''
            INSTANCE_KEYS["${instanceKey}"]="${instanceKey}"
            REPOS["${instanceKey}"]="${instance.name}"
            VM_NAMES["${instanceKey}"]="${instance.vmName}"
            RUNNER_NAMES["${instanceKey}"]="${instance.runnerName}"
            VM_MEMORY["${instanceKey}"]="${instance.vmMemory}"
            VM_CPUS["${instanceKey}"]="${toString instance.vmCpus}"
            VM_DISK["${instanceKey}"]="${instance.vmDisk}"
            UBUNTU_IMAGE["${instanceKey}"]="${instance.ubuntuImage}"
            EXTRA_LABELS["${instanceKey}"]="${concatStringsSep "," instance.extraLabels}"
            ENABLE_DOCKER["${instanceKey}"]="${if instance.enableDocker then "true" else "false"}"
            INSTANCE_IDS["${instanceKey}"]="${toString instance.instanceId}"
          '') allRepos)}
          
          # Get all unique repository names
          get_unique_repos() {
            printf '%s\n' "''${REPOS[@]}" | sort -u
          }
          
          # Get all instances for a repository
          get_repo_instances() {
            local repo="$1"
            for key in "''${!REPOS[@]}"; do
              if [[ "''${REPOS[$key]}" == "$repo" ]]; then
                echo "$key"
              fi
            done | sort
          }
          
          # Get instance key from repo and instance number
          get_instance_key() {
            local repo="$1"
            local instance_num="''${2:-1}"
            echo "$repo:$instance_num"
          }
          
          # Validate instance key exists
          validate_instance() {
            local key="$1"
            if [[ ! ''${INSTANCE_KEYS["$key"]+_} ]]; then
              echo "Error: Instance '$key' not configured"
              echo "Available instances:"
              printf '%s\n' "''${!INSTANCE_KEYS[@]}" | sort
              exit 1
            fi
          }
          
          # Parse repo and instance from argument
          parse_repo_instance() {
            local arg="$1"
            local repo instance_num
            
            if [[ "$arg" == *":"* ]]; then
              # Format: repo:instance (e.g., myorg/project:2)
              repo="''${arg%:*}"
              instance_num="''${arg#*:}"
            else
              # Format: just repo (defaults to instance 1)
              repo="$arg"
              instance_num="1"
            fi
            
            echo "$repo:$instance_num"
          }
          
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
          
          start_runner() {
            local arg="$1"
            local instance_key
            instance_key=$(parse_repo_instance "$arg")
            validate_instance "$instance_key"
            
            local repo="''${REPOS[$instance_key]}"
            local vm_name="''${VM_NAMES[$instance_key]}"
            local runner_name="''${RUNNER_NAMES[$instance_key]}"
            local vm_memory="''${VM_MEMORY[$instance_key]}"
            local vm_cpus="''${VM_CPUS[$instance_key]}"
            local vm_disk="''${VM_DISK[$instance_key]}"
            local ubuntu_image="''${UBUNTU_IMAGE[$instance_key]}"
            local extra_labels="''${EXTRA_LABELS[$instance_key]}"
            local enable_docker="''${ENABLE_DOCKER[$instance_key]}"
            local instance_id="''${INSTANCE_IDS[$instance_key]}"
            
            echo "Starting GitHub runner for repository: $repo (instance $instance_id)"
            echo "VM Name: $vm_name"
            echo "Runner Name: $runner_name"
            
            check_multipass_ready
            
            # Get fresh GitHub registration token using gh CLI
            echo "Getting fresh GitHub registration token..."
            if command -v gh >/dev/null 2>&1; then
              if gh auth status >/dev/null 2>&1; then
                echo "Generating new registration token with gh CLI..."
                GITHUB_TOKEN=$(gh api -X POST repos/$repo/actions/runners/registration-token --jq '.token')
                if [ -z "$GITHUB_TOKEN" ]; then
                  echo "✗ Failed to get registration token from GitHub API"
                  echo "Please ensure you have proper permissions for repository: $repo"
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
            if multipass info "$vm_name" >/dev/null 2>&1; then
              echo "Stopping existing VM..."
              multipass stop "$vm_name" || true
              multipass delete "$vm_name" || true
              multipass purge || true
            fi
            
            echo "Creating Multipass VM $vm_name..."
            multipass launch $ubuntu_image \
              --name "$vm_name" \
              --memory $vm_memory \
              --cpus $vm_cpus \
              --disk $vm_disk \
              --cloud-init <(cat "$CONFIG_DIR/$vm_name-cloud-init-user-data.yaml")
            
            echo "Waiting for VM to be ready..."
            sleep 30
            
            # Wait for cloud-init to complete
            echo "Waiting for cloud-init to complete..."
            timeout=300
            elapsed=0
            while [ $elapsed -lt $timeout ]; do
              if multipass exec "$vm_name" -- cloud-init status --format=json 2>/dev/null | grep -q '"status": "done"'; then
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
            multipass info "$vm_name" || echo "Warning: could not get VM info"
            
            echo "Checking if runner user exists:"
            multipass exec "$vm_name" -- id runner 2>/dev/null || echo "Warning: runner user not found"
            
            echo "Cloud-init status:"
            multipass exec "$vm_name" -- cloud-init status --long 2>/dev/null || echo "Warning: cloud-init status check failed"
            
            echo "VM file system structure:"
            multipass exec "$vm_name" -- ls -la /home/ 2>/dev/null || echo "Warning: could not list /home"
            
            echo "Copying GitHub token..."
            
            # Verify we have a valid token
            if [ -z "$GITHUB_TOKEN" ]; then
              echo "Error: GitHub token is empty"
              exit 1
            fi
            
            # Create work directory for runner with proper permissions
            echo "Creating runner work directory..."
            multipass exec "$vm_name" -- sudo mkdir -p /home/runner/work || {
              echo "Error: Failed to create /home/runner/work directory"
              exit 1
            }
            
            multipass exec "$vm_name" -- sudo mkdir -p /home/runner/work/_temp || {
              echo "Error: Failed to create /home/runner/work/_temp directory"
              exit 1
            }
            
            multipass exec "$vm_name" -- sudo mkdir -p /home/runner/work/_temp/_runner_file_commands || {
              echo "Error: Failed to create /home/runner/work/_temp/_runner_file_commands directory"
              exit 1
            }
            
            echo "Setting ownership and permissions of work directory..."
            multipass exec "$vm_name" -- sudo chown -R runner:runner /home/runner/work || {
              echo "Error: Failed to set ownership of /home/runner/work"
              exit 1
            }
            
            multipass exec "$vm_name" -- sudo chmod -R 755 /home/runner/work || {
              echo "Error: Failed to set permissions of /home/runner/work"
              exit 1
            }
            
            # Copy the token directly to VM using multipass exec
            echo "Copying token to VM..."
            if echo "$GITHUB_TOKEN" | multipass exec "$vm_name" -- sudo -u runner bash -c "cat > /home/runner/github-token"; then
              echo "✓ Token copied successfully to VM"
            else
              echo "✗ Failed to copy token to VM"
              echo "Debugging VM state:"
              multipass info "$vm_name"
              exit 1
            fi
            
            echo "Setting token file permissions..."
            multipass exec "$vm_name" -- sudo chmod 600 /home/runner/github-token || {
              echo "Error: Failed to set token file permissions"  
              exit 1
            }
            
            echo "Verifying token in VM..."
            multipass exec "$vm_name" -- sudo -u runner ls -la /home/runner/github-token || {
              echo "Error: Token file not found in VM after copy"
              exit 1
            }
            
            echo "Getting fresh token for service start..."
            FRESH_TOKEN=$(gh api -X POST repos/$repo/actions/runners/registration-token --jq '.token')
            if [ -z "$FRESH_TOKEN" ]; then
              echo "Warning: Could not get fresh token, using original token"
            else
              echo "Updating token in VM with fresh token..."
              echo "$FRESH_TOKEN" | multipass exec "$vm_name" -- sudo -u runner bash -c "cat > /home/runner/github-token"
            fi
            
            echo "Starting GitHub runner service..."
            
            # Configure the runner first
            echo "Configuring GitHub runner..."
            multipass exec "$vm_name" -- sudo -u runner bash -c "cd /home/runner/actions-runner && ./config.sh --url https://github.com/$repo --token \$(cat /home/runner/github-token) --name $runner_name --labels $extra_labels --work /home/runner/work --unattended --replace"
            
            # Install and start the service using the official svc.sh script
            echo "Installing GitHub runner service..."
            multipass exec "$vm_name" -- sudo -u runner bash -c "cd /home/runner/actions-runner && sudo ./svc.sh install runner"
            
            echo "Starting GitHub runner service..."
            multipass exec "$vm_name" -- sudo bash -c "cd /home/runner/actions-runner && ./svc.sh start"
            
            echo "GitHub runner started successfully for $repo!"
            echo "VM IP: $(multipass info "$vm_name" --format csv | tail -n +2 | cut -d, -f3)"
          }
          
          stop_runner() {
            local arg="$1"
            local instance_key
            instance_key=$(parse_repo_instance "$arg")
            validate_instance "$instance_key"
            
            local repo="''${REPOS[$instance_key]}"
            local vm_name="''${VM_NAMES[$instance_key]}"
            local instance_id="''${INSTANCE_IDS[$instance_key]}"
            
            echo "Stopping GitHub runner for repository: $repo (instance $instance_id)"
            echo "VM Name: $vm_name"
            
            if multipass info "$vm_name" >/dev/null 2>&1; then
              echo "Checking if runner directory exists..."
              if multipass exec "$vm_name" -- test -d /home/runner/actions-runner 2>/dev/null; then
                echo "Stopping GitHub runner service..."
                multipass exec "$vm_name" -- sudo bash -c "cd /home/runner/actions-runner && test -f ./svc.sh && ./svc.sh stop" || echo "Warning: Could not stop service (may not be running)"
                
                echo "Uninstalling GitHub runner service..."
                multipass exec "$vm_name" -- sudo bash -c "cd /home/runner/actions-runner && test -f ./svc.sh && ./svc.sh uninstall" || echo "Warning: Could not uninstall service"
                
                echo "Deregistering GitHub runner..."
                # Get fresh token for deregistration
                if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                  FRESH_TOKEN=$(gh api -X POST repos/$repo/actions/runners/registration-token --jq '.token' 2>/dev/null || echo "")
                  if [ -n "$FRESH_TOKEN" ]; then
                    echo "$FRESH_TOKEN" | multipass exec "$vm_name" -- sudo -u runner bash -c "cat > /home/runner/github-token"
                  fi
                fi
                multipass exec "$vm_name" -- sudo -u runner bash -c "cd /home/runner/actions-runner && test -f ./config.sh && ./config.sh remove --token \$(cat /home/runner/github-token)" || echo "Warning: Failed to deregister runner"
              else
                echo "Runner directory not found - skipping service cleanup"
              fi
              
              echo "Stopping Multipass VM..."
              multipass stop "$vm_name" || true
              
              echo "Deleting Multipass VM..."
              multipass delete "$vm_name" || true
              multipass purge || true
              
              echo "GitHub runner Multipass VM stopped and removed for $repo"
            else
              echo "VM $vm_name does not exist"
            fi
          }
          
          show_status() {
            local arg="''${1:-}"
            
            if [ -n "$arg" ]; then
              # Show status for specific instance
              local instance_key
              instance_key=$(parse_repo_instance "$arg")
              validate_instance "$instance_key"
              
              local repo="''${REPOS[$instance_key]}"
              local vm_name="''${VM_NAMES[$instance_key]}"
              local instance_id="''${INSTANCE_IDS[$instance_key]}"
              
              echo "=== Status for Repository: $repo (instance $instance_id) ==="
              echo "VM Name: $vm_name"
              echo ""
              echo "=== Multipass VM Status ==="
              if multipass info "$vm_name" >/dev/null 2>&1; then
                multipass info "$vm_name"
                echo ""
                echo "=== GitHub Runner Service Status ==="
                # The service name will be dynamically generated by svc.sh, so check for actions.runner.* services
                multipass exec "$vm_name" -- sudo systemctl status "actions.runner.*" 2>/dev/null || multipass exec "$vm_name" -- sudo systemctl status github-runner 2>/dev/null || echo "Service not found"
                echo ""
                echo "=== Cloud-init Status ==="
                multipass exec "$vm_name" -- cloud-init status || true
              else
                echo "VM $vm_name does not exist"
                echo "Run 'github-runner-multipass-manage start $arg' to create it"
              fi
            else
              echo "=== All GitHub Runners Status ==="
              
              # Group by repository
              for repo in $(get_unique_repos); do
                echo ""
                echo "--- Repository: $repo ---"
                
                # Show all instances for this repository
                for instance_key in $(get_repo_instances "$repo"); do
                  vm_name="''${VM_NAMES[$instance_key]}"
                  instance_id="''${INSTANCE_IDS[$instance_key]}"
                  
                  echo "  Instance $instance_id:"
                  echo "    VM Name: $vm_name"
                  if multipass info "$vm_name" >/dev/null 2>&1; then
                    echo "    Status: $(multipass info "$vm_name" --format csv | tail -n +2 | cut -d, -f2)"
                    echo "    IP: $(multipass info "$vm_name" --format csv | tail -n +2 | cut -d, -f3)"
                  else
                    echo "    Status: Not created"
                  fi
                done
              done
              echo ""
              echo "Use 'github-runner-multipass-manage status <repository[:instance]>' for detailed status"
            fi
          }
          
          show_logs() {
            local arg="$1"
            local instance_key
            instance_key=$(parse_repo_instance "$arg")
            validate_instance "$instance_key"
            
            local repo="''${REPOS[$instance_key]}"
            local vm_name="''${VM_NAMES[$instance_key]}"
            local instance_id="''${INSTANCE_IDS[$instance_key]}"
            
            if multipass info "$vm_name" >/dev/null 2>&1; then
              echo "=== GitHub Runner Logs for $repo (instance $instance_id) ==="
              # Try to find the service name created by svc.sh
              SERVICE_NAME=$(multipass exec "$vm_name" -- sudo systemctl list-units --type=service --state=active | grep "actions.runner" | head -1 | awk '{print $1}' || echo "")
              if [ -n "$SERVICE_NAME" ]; then
                multipass exec "$vm_name" -- sudo journalctl -u "$SERVICE_NAME" -f
              else
                echo "GitHub runner service not found or not active"
                multipass exec "$vm_name" -- sudo systemctl list-units --type=service | grep -E "(github|actions|runner)" || echo "No runner services found"
              fi
            else
              echo "VM $vm_name does not exist"
              exit 1
            fi
          }
          
          open_shell() {
            local arg="$1"
            local instance_key
            instance_key=$(parse_repo_instance "$arg")
            validate_instance "$instance_key"
            
            local vm_name="''${VM_NAMES[$instance_key]}"
            
            if multipass info "$vm_name" >/dev/null 2>&1; then
              multipass exec "$vm_name" -- sudo -u runner -i
            else
              echo "VM $vm_name does not exist"
              exit 1
            fi
          }
          
          show_ip() {
            local arg="$1"
            local instance_key
            instance_key=$(parse_repo_instance "$arg")
            validate_instance "$instance_key"
            
            local vm_name="''${VM_NAMES[$instance_key]}"
            
            if multipass info "$vm_name" >/dev/null 2>&1; then
              multipass info "$vm_name" --format csv | tail -n +2 | cut -d, -f3
            else
              echo "VM $vm_name does not exist"
              exit 1
            fi
          }
          
          start_all() {
            echo "Starting all GitHub runner instances..."
            for instance_key in "''${!INSTANCE_KEYS[@]}"; do
              repo="''${REPOS[$instance_key]}"
              instance_id="''${INSTANCE_IDS[$instance_key]}"
              echo ""
              echo "=== Starting $repo:$instance_id ==="
              start_runner "$instance_key"
            done
          }
          
          stop_all() {
            echo "Stopping all GitHub runner instances..."
            for instance_key in "''${!INSTANCE_KEYS[@]}"; do
              repo="''${REPOS[$instance_key]}"
              instance_id="''${INSTANCE_IDS[$instance_key]}"
              echo ""
              echo "=== Stopping $repo:$instance_id ==="
              stop_runner "$instance_key"
            done
          }
          
          restart_all() {
            stop_all
            sleep 5
            start_all
          }
          
          # Repository-level bulk operations
          start_repo_all() {
            local repo="$1"
            echo "Starting all instances for repository: $repo"
            for instance_key in $(get_repo_instances "$repo"); do
              instance_id="''${INSTANCE_IDS[$instance_key]}"
              echo ""
              echo "=== Starting $repo:$instance_id ==="
              start_runner "$instance_key"
            done
          }
          
          stop_repo_all() {
            local repo="$1"
            echo "Stopping all instances for repository: $repo"
            for instance_key in $(get_repo_instances "$repo"); do
              instance_id="''${INSTANCE_IDS[$instance_key]}"
              echo ""
              echo "=== Stopping $repo:$instance_id ==="
              stop_runner "$instance_key"
            done
          }
          
          restart_repo_all() {
            local repo="$1"
            stop_repo_all "$repo"
            sleep 5
            start_repo_all "$repo"
          }
          
          show_usage() {
            echo "Usage: $0 <command> [repository[:instance]]"
            echo ""
            echo "Commands:"
            echo "  start <repo[:inst]>     - Create and start GitHub runner VM for repository instance"
            echo "  start-all               - Start all configured runner instances"
            echo "  start-repo-all <repo>   - Start all instances for a specific repository"
            echo "  stop <repo[:inst]>      - Stop and remove Multipass VM for repository instance"
            echo "  stop-all                - Stop and remove all Multipass VMs"
            echo "  stop-repo-all <repo>    - Stop all instances for a specific repository"
            echo "  restart <repo[:inst]>   - Restart Multipass VM for repository instance"
            echo "  restart-all             - Restart all Multipass VMs"
            echo "  restart-repo-all <repo> - Restart all instances for a specific repository"
            echo "  status [repo[:inst]]    - Show VM and service status"
            echo "  logs <repo[:inst]>      - Follow GitHub runner logs for repository instance"
            echo "  shell <repo[:inst]>     - Open shell in VM as runner user"
            echo "  ip <repo[:inst]>        - Show VM IP address for repository instance"
            echo "  list                    - List all configured repository instances"
            echo ""
            echo "Available repository instances:"
            if [ ''${#INSTANCE_KEYS[@]} -eq 0 ]; then
              echo "  None configured"
            else
              # Group by repository
              for repo in $(get_unique_repos); do
                echo "  $repo:"
                for instance_key in $(get_repo_instances "$repo"); do
                  instance_id="''${INSTANCE_IDS[$instance_key]}"
                  vm_name="''${VM_NAMES[$instance_key]}"
                  runner_name="''${RUNNER_NAMES[$instance_key]}"
                  echo "    Instance $instance_id: VM=$vm_name, Runner=$runner_name"
                done
              done
            fi
            echo ""
            echo "Examples:"
            echo "  $0 start myorg/myproject       # Start instance 1 (default)"
            echo "  $0 start myorg/myproject:2     # Start instance 2"
            echo "  $0 start-repo-all myorg/myproject  # Start all instances for repo"
            echo "  $0 start-all                   # Start all instances for all repos"
            echo "  $0 status myorg/myproject:2    # Status for specific instance"
            echo "  $0 logs myorg/myproject        # Logs for instance 1"
            echo ""
            echo "Note: If no instance number is specified, defaults to instance 1"
            echo ""
            echo "First time setup:"
            echo "  1. Ensure Multipass is running: sudo snap restart multipass"
            echo "  2. Authenticate with GitHub: gh auth login"
            echo "  3. github-runner-multipass-manage start <repository[:instance]>"
          }
          
          case "''${1:-}" in
            start)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository[:instance] required for start command"
                show_usage
                exit 1
              fi
              start_runner "$2"
              ;;
              
            start-all)
              start_all
              ;;
              
            start-repo-all)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository name required for start-repo-all command"
                show_usage
                exit 1
              fi
              start_repo_all "$2"
              ;;
              
            stop)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository[:instance] required for stop command"
                show_usage
                exit 1
              fi
              stop_runner "$2"
              ;;
              
            stop-all)
              stop_all
              ;;
              
            stop-repo-all)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository name required for stop-repo-all command"
                show_usage
                exit 1
              fi
              stop_repo_all "$2"
              ;;
              
            restart)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository[:instance] required for restart command"
                show_usage
                exit 1
              fi
              stop_runner "$2"
              sleep 5
              start_runner "$2"
              ;;
              
            restart-all)
              restart_all
              ;;
              
            restart-repo-all)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository name required for restart-repo-all command"
                show_usage
                exit 1
              fi
              restart_repo_all "$2"
              ;;
              
            status)
              show_status "''${2:-}"
              ;;
              
            logs)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository[:instance] required for logs command"
                show_usage
                exit 1
              fi
              show_logs "$2"
              ;;
              
            shell)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository[:instance] required for shell command"
                show_usage
                exit 1
              fi
              open_shell "$2"
              ;;
              
            ip)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository[:instance] required for ip command"
                show_usage
                exit 1
              fi
              show_ip "$2"
              ;;
              
            list)
              echo "Configured repository instances:"
              if [ ''${#INSTANCE_KEYS[@]} -eq 0 ]; then
                echo "  None configured"
              else
                # Group by repository
                for repo in $(get_unique_repos); do
                  echo "  $repo:"
                  for instance_key in $(get_repo_instances "$repo"); do
                    instance_id="''${INSTANCE_IDS[$instance_key]}"
                    vm_name="''${VM_NAMES[$instance_key]}"
                    runner_name="''${RUNNER_NAMES[$instance_key]}"
                    echo "    Instance $instance_id: VM=$vm_name, Runner=$runner_name"
                  done
                done
              fi
              ;;
              
            *)
              show_usage
              exit 1
              ;;
          esac
        '';
        executable = true;
      };
    };

    # Create systemd user services for each instance
    systemd.user.services = listToAttrs (map (instance: {
      name = "github-runner-multipass-${replaceStrings ["/"] ["-"] instance.name}-${toString instance.instanceId}";
      value = {
        Unit = {
          Description = "GitHub Actions Runner Multipass VM for ${instance.name} (instance ${toString instance.instanceId})";
          After = [ "network.target" ];
          Wants = [ "network.target" ];
        };

        Service = {
          Type = "oneshot";
          RemainAfterExit = "yes";
          TimeoutStartSec = "600";  # 10 minutes for VM creation and setup
          TimeoutStopSec = "300";   # 5 minutes for cleanup
          
          ExecStart = let
            startScript = pkgs.writeShellScript "start-github-runner-multipass-${replaceStrings ["/"] ["-"] instance.name}-${toString instance.instanceId}.sh" ''
              #!/bin/bash
              set -euo pipefail
              
              echo "Starting GitHub Actions Runner Multipass service for ${instance.name} (instance ${toString instance.instanceId})..."
              
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
              exec ${config.home.homeDirectory}/.local/bin/github-runner-multipass-manage start "${instance.name}:${toString instance.instanceId}"
            '';
          in "${startScript}";
          
          ExecStop = let
            stopScript = pkgs.writeShellScript "stop-github-runner-multipass-${replaceStrings ["/"] ["-"] instance.name}-${toString instance.instanceId}.sh" ''
              #!/bin/bash
              set -euo pipefail
              
              echo "Stopping GitHub Actions Runner Multipass service for ${instance.name} (instance ${toString instance.instanceId})..."
              
              # Stop the runner using the management script
              exec ${config.home.homeDirectory}/.local/bin/github-runner-multipass-manage stop "${instance.name}:${toString instance.instanceId}"
            '';
          in "${stopScript}";
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    }) allRepos);
  };
}