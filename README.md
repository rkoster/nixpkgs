# nixpkgs
Home Manager config

Install Nix
```
sh <(curl -L https://nixos.org/nix/install) --daemon --darwin-use-unencrypted-nix-store-volume
source ~/.zshrc
```

Install Home-Manager
```
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
export NIX_PATH=$HOME/.nix-defexpr/channels${NIX_PATH:+:}$NIX_PATH
nix-shell '<home-manager>' -A install
```

Install git
```
nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
nix-channel --update
nix-env -i git
export PATH=$PATH:$HOME/.nix-profile/bin
```

Clone config
```
cd ~/.config && rm -r nixpkgs
git clone https://github.com/rkoster/nixpkgs
```

Switch
```
nix-env -e git
home-manager switch
```
