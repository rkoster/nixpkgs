{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.github-runner-firecracker;
in
{
  options.programs.github-runner-firecracker = {
    enable = mkEnableOption "GitHub Actions Runner with Firecracker";

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
      type = types.int;
      default = 2048;
      description = "Memory allocation for the VM in MB";
    };

    vmCpus = mkOption {
      type = types.int;
      default = 2;
      description = "CPU allocation for the VM";
    };

    runnerName = mkOption {
      type = types.str;
      default = "firecracker-runner";
      description = "Name for the GitHub runner";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      firecracker
      curl
      e2fsprogs
    ];

    systemd.user.services.github-runner-firecracker = {
      Unit = {
        Description = "GitHub Actions Runner with Firecracker";
        After = [ "network.target" ];
        Wants = [ "network.target" ];
      };

      Service = {
        Type = "exec";
        ExecStartPre = let
          vmSetupScript = pkgs.writeShellScript "vm-setup.sh" ''
            #!/bin/bash
            set -euo pipefail
            
            VM_DIR="$HOME/.firecracker/${cfg.runnerName}"
            mkdir -p "$VM_DIR"
            cd "$VM_DIR"
            
            # Download Ubuntu cloud image if not exists
            if [ ! -f ubuntu-20.04.img ]; then
              echo "Downloading Ubuntu 20.04 cloud image..."
              curl -L https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img \
                -o ubuntu-20.04.qcow2
              qemu-img convert -f qcow2 -O raw ubuntu-20.04.qcow2 ubuntu-20.04.img
              rm ubuntu-20.04.qcow2
              
              # Resize image to 10GB
              truncate -s 10G ubuntu-20.04.img
              e2fsck -f ubuntu-20.04.img || true
              resize2fs ubuntu-20.04.img
            fi
            
            # Download kernel if not exists
            if [ ! -f vmlinux ]; then
              echo "Downloading kernel..."
              curl -L https://cdn.amazonlinux.com/os-images/2.0.20230719.0/kvm/vmlinux-5.10.184-175.731.amzn2.x86_64 \
                -o vmlinux
            fi
            
            # Read GitHub token from file
            GITHUB_TOKEN=$(cat ${cfg.tokenFile})
            
            # Create cloud-init config
            cat > user-data << EOF
#cloud-config
users:
  - name: runner
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys: []

packages:
  - curl
  - docker.io
  - git

runcmd:
  - systemctl enable --now docker
  - usermod -aG docker runner
  - sudo -u runner bash -c "cd /home/runner && mkdir actions-runner && cd actions-runner && curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz && tar xzf actions-runner.tar.gz && ./config.sh --url https://github.com/${cfg.repository} --token $GITHUB_TOKEN --name ${cfg.runnerName} --unattended --labels firecracker,docker,linux,x64 && nohup ./run.sh &"
EOF
            
            # Create network config
            cat > network-config << EOF
version: 2
ethernets:
  eth0:
    dhcp4: true
EOF
            
            # Generate cloud-init ISO
            if command -v cloud-localds >/dev/null 2>&1; then
              cloud-localds cloud-init.iso user-data network-config
            else
              echo "Warning: cloud-localds not found, VM may not configure properly"
              touch cloud-init.iso
            fi
          '';
        in "${vmSetupScript}";
        
        ExecStart = let
          firecrackerConfig = pkgs.writeText "firecracker-config.json" ''
            {
              "boot-source": {
                "kernel_image_path": "$HOME/.firecracker/${cfg.runnerName}/vmlinux",
                "boot_args": "console=ttyS0 reboot=k panic=1 pci=off"
              },
              "drives": [
                {
                  "drive_id": "rootfs",
                  "path_on_host": "$HOME/.firecracker/${cfg.runnerName}/ubuntu-20.04.img",
                  "is_root_device": true,
                  "is_read_only": false
                }
              ],
              "machine-config": {
                "vcpu_count": ${toString cfg.vmCpus},
                "mem_size_mib": ${toString cfg.vmMemory}
              },
              "network-interfaces": [
                {
                  "iface_id": "eth0",
                  "guest_mac": "AA:FC:00:00:00:01",
                  "host_dev_name": "tap0"
                }
              ]
            }
          '';
          startScript = pkgs.writeShellScript "start-firecracker.sh" ''
            #!/bin/bash
            set -euo pipefail
            
            VM_DIR="$HOME/.firecracker/${cfg.runnerName}"
            cd "$VM_DIR"
            
            # Expand variables in config
            envsubst < ${firecrackerConfig} > firecracker-config.json
            
            # Start Firecracker
            ${pkgs.firecracker}/bin/firecracker --api-sock firecracker.socket --config-file firecracker-config.json
          '';
        in "${startScript}";
        
        ExecStop = pkgs.writeShellScript "stop-firecracker.sh" ''
          #!/bin/bash
          pkill -f "firecracker.*${cfg.runnerName}" || true
          rm -f "$HOME/.firecracker/${cfg.runnerName}/firecracker.socket"
        '';
        
        Restart = "always";
        RestartSec = "30";
        
        Environment = [
          "HOME=%h"
        ];
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}