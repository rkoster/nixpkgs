{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.github-runner-container;
in
{
  options.programs.github-runner-container = {
    enable = mkEnableOption "GitHub Actions Runner with containers";

    repository = mkOption {
      type = types.str;
      description = "GitHub repository (owner/repo format)";
      example = "myorg/myproject";
    };

    tokenFile = mkOption {
      type = types.path;
      default = "${config.home.homeDirectory}/.github-runner-token";
      description = "Path to file containing GitHub runner registration token";
    };

    vmMemory = mkOption {
      type = types.str;
      default = "2048";
      description = "Memory for the container in MB";
    };

    vmCpus = mkOption {
      type = types.str;
      default = "2";
      description = "Number of CPUs for the container";
    };

    runnerName = mkOption {
      type = types.str;
      default = "podman-runner";
      description = "Name for the GitHub runner";
    };

    image = mkOption {
      type = types.str;
      default = "ghcr.io/actions/actions-runner:latest";
      description = "OCI image to use for the runner";
    };

    workDir = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.github-runner-data";
      description = "Host directory to mount for runner data persistence";
    };

    extraLabels = mkOption {
      type = types.listOf types.str;
      default = [ "podman" "container" "linux" "x64" "docker" ];
      description = "Additional labels for the runner";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      podman
      crun  # Base container runtime
      skopeo
      curl
    ];

    # Configure container registries and policies for podman
    home.file.".config/containers/registries.conf".text = ''
      [registries.search]
      registries = ["docker.io", "quay.io", "ghcr.io"]

      [registries.block]
      registries = []
    '';

    home.file.".config/containers/policy.json".text = ''
      {
        "default": [
          {
            "type": "insecureAcceptAnything"
          }
        ]
      }
    '';

    home.file.".config/containers/containers.conf".text = ''
      [containers]
      userns = "keep-id"
      
      [engine]
      cgroup_manager = "systemd"
      events_logger = "journald"
    '';

    # Create systemd user service that runs podman directly
    systemd.user.services.github-runner = {
      Unit = {
        Description = "GitHub Actions Runner with Podman";
        After = [ "network.target" ];
        Wants = [ "network.target" ];
      };

      Service = {
        Type = "exec";
        Restart = "always";
        RestartSec = "30";
        
        ExecStartPre = let
          setupScript = pkgs.writeShellScript "setup-github-runner.sh" ''
            #!/bin/bash
            set -euo pipefail
            
            # Create work directory
            mkdir -p "${cfg.workDir}"
            
            # Check if token file exists
            if [ ! -f "${cfg.tokenFile}" ]; then
              echo "Error: GitHub token file ${cfg.tokenFile} not found"
              exit 1
            fi
            
            # Copy token to workspace and make it readable by container
            cp "${cfg.tokenFile}" "${cfg.workDir}/token"
            chmod 644 "${cfg.workDir}/token"
            
            # Stop and remove any existing container
            ${pkgs.podman}/bin/podman stop ${cfg.runnerName} 2>/dev/null || true
            ${pkgs.podman}/bin/podman rm ${cfg.runnerName} 2>/dev/null || true
            
            echo "Setup completed"
          '';
        in "${setupScript}";
        
        ExecStart = let
          startScript = pkgs.writeShellScript "start-github-runner.sh" ''
            #!/bin/bash
            set -euo pipefail
            
            # Run the container with podman, using a bash command instead of external script
            exec ${pkgs.podman}/bin/podman run \
              --name ${cfg.runnerName} \
              --rm \
              --volume "${cfg.workDir}:/workspace:Z" \
              --workdir /workspace \
              --env GITHUB_TOKEN_FILE=/workspace/token \
              --env REPOSITORY="${cfg.repository}" \
              --env RUNNER_NAME="${cfg.runnerName}" \
              --env LABELS="${concatStringsSep "," cfg.extraLabels}" \
              ${cfg.image} \
              bash -c '
                set -euo pipefail
                
                log() {
                  echo "[$(date "+%Y-%m-%d %H:%M:%S")] $*"
                }
                
                # Check if token file exists
                if [ ! -f "/workspace/token" ]; then
                  log "Error: GitHub token file not found at /workspace/token"
                  exit 1
                fi
                
                # Read GitHub token
                GITHUB_TOKEN=$(cat "/workspace/token")
                
                # Wait for network to be available
                log "Waiting for network..."
                while ! curl -s --connect-timeout 5 https://github.com >/dev/null 2>&1; do
                  log "Network not ready, waiting..."
                  sleep 2
                done
                log "Network is ready"
                
                # Find the actions runner directory
                RUNNER_DIR=""
                for dir in /home/runner /actions-runner /runner /home/actions-runner; do
                  if [ -d "$dir" ] && [ -f "$dir/config.sh" ]; then
                    RUNNER_DIR="$dir"
                    break
                  fi
                done
                
                if [ -z "$RUNNER_DIR" ]; then
                  log "Error: Could not find actions-runner directory"
                  find / -name "config.sh" -type f 2>/dev/null | head -5
                  exit 1
                fi
                
                log "Using runner directory: $RUNNER_DIR"
                cd "$RUNNER_DIR"
                
                # Configure the runner
                log "Configuring GitHub Actions runner..."
                ./config.sh \
                  --url "https://github.com/$REPOSITORY" \
                  --token "$GITHUB_TOKEN" \
                  --name "$RUNNER_NAME" \
                  --labels "$LABELS" \
                  --ephemeral \
                  --unattended
                
                # Start the runner
                log "Starting GitHub Actions runner..."
                exec ./run.sh
              '
          '';
        in "${startScript}";
        
        ExecStop = let
          stopScript = pkgs.writeShellScript "stop-github-runner.sh" ''
            #!/bin/bash
            # Stop and remove the container
            ${pkgs.podman}/bin/podman stop ${cfg.runnerName} 2>/dev/null || true
            ${pkgs.podman}/bin/podman rm ${cfg.runnerName} 2>/dev/null || true
          '';
        in "${stopScript}";
        
        Environment = [
          "HOME=%h"
          "XDG_RUNTIME_DIR=%t"
        ];
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    # Create a simple management script
    home.file.".local/bin/github-runner-manage" = {
      text = let
        manageScript = pkgs.writeShellScript "github-runner-manage" ''
          #!/bin/bash
          set -euo pipefail
          
          case "''${1:-}" in
            start)
              systemctl --user start github-runner
              echo "GitHub runner started"
              ;;
            stop)
              systemctl --user stop github-runner
              echo "GitHub runner stopped"
              ;;
            status)
              systemctl --user status github-runner
              ;;
            logs)
              journalctl --user -u github-runner -f
              ;;
            *)
              echo "Usage: $0 {start|stop|status|logs}"
              echo ""
              echo "  start  - Start the GitHub runner service"
              echo "  stop   - Stop the GitHub runner service"
              echo "  status - Show service status"
              echo "  logs   - Follow service logs"
              exit 1
              ;;
          esac
        '';
      in "${manageScript}";
      executable = true;
    };

    # Create the work directory with proper permissions
    home.activation.github-runner-workdir = lib.hm.dag.entryAfter ["writeBoundary"] ''
      mkdir -p "${cfg.workDir}"
      chmod 755 "${cfg.workDir}"
      
      # Copy token file to workspace if it exists
      if [ -f "${cfg.tokenFile}" ]; then
        cp "${cfg.tokenFile}" "${cfg.workDir}/token"
        chmod 644 "${cfg.workDir}/token"
      fi
    '';
  };
}