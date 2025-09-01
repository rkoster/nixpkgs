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

### Install sudoers rule for Kinto (Mac-style keybindings)

After the first home-manager switch, install the sudoers rule to enable Mac-style keyboard shortcuts:

**Option 1: Use the installation script**
```bash
~/.config/kinto/install-sudoers.sh
```

**Option 2: Manual installation**
```bash
sudo cp ~/.config/kinto/10-kinto-xkeysnail /etc/sudoers.d/
sudo chmod 440 /etc/sudoers.d/10-kinto-xkeysnail
sudo chown root:root /etc/sudoers.d/10-kinto-xkeysnail
```

### Start Kinto service
```bash
systemctl --user enable --now kinto
```

This enables Mac-style keyboard shortcuts (Cmd+C/V, etc.) that work globally across all Linux applications.

## Updating Configuration

### macOS
```bash
darwin-rebuild switch
```

### Linux
```bash
nix run --extra-experimental-features flakes home-manager/master#home-manager -- switch --flake ~/.config/home-manager
```
