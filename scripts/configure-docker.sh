#!/bin/bash

set -e

echo "Configuring Docker daemon to use systemd cgroup driver..."

sudo mkdir -p /etc/docker

if [ -f /etc/docker/daemon.json ]; then
  echo "Backing up existing /etc/docker/daemon.json to /etc/docker/daemon.json.backup"
  sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
fi

sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

echo "Docker daemon configuration updated."

if systemctl is-active --quiet docker; then
  echo "Restarting Docker daemon..."
  sudo systemctl restart docker
  echo "Docker daemon restarted successfully."
else
  echo "Docker daemon is not running. Start it with: sudo systemctl start docker"
fi

echo "Configuration complete!"
