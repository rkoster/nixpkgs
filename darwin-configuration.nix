{ config, pkgs, ... }:

let
  username = builtins.getEnv "USER";
in {

  services.nix-daemon.enable = true;

  nix = {
    # does not work yet because https://github.com/LnL7/nix-darwin/issues/158
    # tmp workaround in ~/.zshrc
    nixPath = [
      { nixpkgs-overlays = "\$HOME/.config/nixpkgs/overlays"; }
      { darwin-config = "\$HOME/.config/nixpkgs/darwin-configuration.nix"; }
      "/nix/var/nix/profiles/per-user/root/channels"
      "\$HOME/.nix-defexpr/channels"
    ];
    gc.automatic = true;
  };

  nixpkgs.overlays =
    let path = ./overlays; in with builtins;
          map (n: import (path + ("/" + n)))
            (filter (n: match ".*\\.nix" n != null )
              (attrNames (readDir path)));

  imports = [ ./home.nix ];

  fonts = {
    enableFontDir = true;
    fonts = [
      pkgs.hack-font
    ];
  };

  # to load darwin-rebuild via /etc/static/zshrc
  # further configuration via home-manager
  programs.zsh.enable = true;
  services.lorri.enable = true;

  users.users = builtins.listToAttrs [{
    name = username;
    value  = {
      home = "/Users/" + username;
      shell = pkgs.zsh;
    };
  }];
}
