# nixpkgs
Home Manager config

## macOS Installation

### Install Nix
```bash
sh <(curl -L https://nixos.org/nix/install) --daemon --darwin-use-unencrypted-nix-store-volume
source ~/.zshrc
```

### Add Home-Manager channel
```bash
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
export NIX_PATH=$HOME/.nix-defexpr/channels${NIX_PATH:+:}$NIX_PATH
```

### Install git
```bash
nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
nix-channel --update
nix-env -i git
export PATH=$PATH:$HOME/.nix-profile/bin
```

### Clone config
```bash
mkdir -p ~/.config
cd ~/.config && rm -rf nixpkgs
git clone https://github.com/rkoster/nixpkgs
```

### Install nix-darwin
```bash
export NIX_PATH="$NIX_PATH:darwin-config=$HOME/.config/nixpkgs/darwin-configuration.nix"
yes | nix run -f https://github.com/LnL7/nix-darwin/archive/master.tar.gz installer -c darwin-installer
source /etc/static/zshrc
```

### Apply configuration
```bash
darwin-rebuild switch
```

## Linux Installation

### Install Nix
```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
source ~/.zshrc
```

### Clone config
```bash
mkdir -p ~/.config
cd ~/.config && git clone https://github.com/rkoster/nixpkgs home-manager
```

### Install Home Manager and apply configuration
```bash
cd ~/.config/home-manager
nix run --extra-experimental-features flakes home-manager/master#home-manager -- switch --flake ~/.config/home-manager
```

### Setup Kinto (Mac-style keyboard shortcuts)

**⚠️ Important:** After the initial Home Manager setup, run the Kinto post-installation script to configure input permissions and enable Mac-style keyboard shortcuts.

```bash
~/.local/bin/post-install-kinto
```

This script will:
- Add you to the input group for device access
- Setup udev rules for uinput device permissions
- Verify Kinto service status
- Provide clear feedback on what needs to be done

**🔄 Important:** Follow any logout/reboot instructions shown by the script for changes to take effect.

**Manual verification (if needed):**
```bash
groups | grep input      # Should show 'input' in your groups
ls -la /dev/uinput      # Should show group 'input' with rw- permissions
systemctl --user status kinto  # Should show 'active (running)'
```

### Configure Docker daemon (required for kind and Kubernetes)

After installing Docker, configure it to use systemd as the cgroup driver:

```bash
~/.local/bin/configure-docker
```

This script will:
- Configure Docker daemon to use `native.cgroupdriver=systemd`
- Backup any existing Docker daemon configuration
- Restart the Docker service if it's running

This is required for proper operation of kind (Kubernetes in Docker) and other container runtimes.

### Start Kinto service
```bash
systemctl --user enable --now kinto
```

This enables Mac-style keyboard shortcuts (Cmd+C/V, etc.) and Emacs-style text editing keybindings that work globally across all Linux applications, with terminals properly excluded.

### Natural Scrolling (Reverse Scroll Direction)

Natural scrolling is enabled by default on Linux. If you need to manually apply it after login, run:

```bash
~/.local/bin/setup-natural-scrolling
```

This configures all pointing devices to use natural scrolling (scroll down moves content down, matching macOS behavior).

## Updating Configuration

### macOS
```bash
darwin-rebuild switch
```

### Linux
```bash
nix run --extra-experimental-features flakes home-manager/master#home-manager -- switch --flake ~/.config/home-manager
```
