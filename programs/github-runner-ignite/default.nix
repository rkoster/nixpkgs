{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.github-runner-ignite;
in
{
  options.programs.github-runner-ignite = {
    enable = mkEnableOption "GitHub Actions Runner with Weave Ignite";

    repository = mkOption {
      type = types.str;
      description = "GitHub repository (owner/repo format)";
      example = "myorg/myproject";
    };

    token = mkOption {
      type = types.str;
      description = "GitHub runner registration token";
    };

    vmMemory = mkOption {
      type = types.str;
      default = "4GB";
      description = "Memory allocation for the VM";
    };

    vmCpus = mkOption {
      type = types.int;
      default = 2;
      description = "CPU allocation for the VM";
    };

    runnerName = mkOption {
      type = types.str;
      default = "ignite-runner";
      description = "Name for the GitHub runner";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      ignite
      firecracker
      containerd
      runc
      cni-plugins
    ];

    systemd.user.services.github-runner-ignite = {
      Unit = {
        Description = "GitHub Actions Runner with Weave Ignite";
        After = [ "network.target" ];
        Wants = [ "network.target" ];
      };

      Service = {
        Type = "exec";
        ExecStartPre = [
          # Clean up any existing VM
          "-${pkgs.ignite}/bin/ignite rm -f ${cfg.runnerName}"
          # Pull latest Ubuntu image
          "${pkgs.ignite}/bin/ignite image pull ubuntu:20.04"
        ];
        ExecStart = let
          runnerSetupScript = pkgs.writeShellScript "runner-setup.sh" ''
            #!/bin/bash
            set -euo pipefail
            
            # Wait for network
            until ping -c1 8.8.8.8 >/dev/null 2>&1; do
              echo "Waiting for network..."
              sleep 5
            done
            
            # Install Docker
            apt-get update
            apt-get install -y curl sudo
            curl -fsSL https://get.docker.com | sh
            systemctl enable --now docker
            
            # Create runner user and add to docker group
            useradd -m -s /bin/bash runner
            usermod -aG docker runner
            
            # Install GitHub runner as runner user
            sudo -u runner bash << 'RUNNER_EOF'
            cd /home/runner
            mkdir -p actions-runner && cd actions-runner
            curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
            tar xzf actions-runner-linux-x64.tar.gz
            ./config.sh --url https://github.com/${cfg.repository} --token ${cfg.token} --name ${cfg.runnerName} --unattended --labels ignite,docker,linux,x64
            ./run.sh
            RUNNER_EOF
          '';
        in "${pkgs.ignite}/bin/ignite run ubuntu:20.04 --name ${cfg.runnerName} --cpus ${toString cfg.vmCpus} --memory ${cfg.vmMemory} --copy-files ${runnerSetupScript}:/setup.sh --ssh";
        
        ExecStop = "${pkgs.ignite}/bin/ignite stop ${cfg.runnerName}";
        ExecStopPost = "${pkgs.ignite}/bin/ignite rm -f ${cfg.runnerName}";
        
        Restart = "always";
        RestartSec = "30";
        
        Environment = [
          "IGNITE_RUNTIME=containerd"
          "IGNITE_NETWORK_PLUGIN=cni"
        ];
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}