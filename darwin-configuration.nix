{ username, pkgs, system, ... }:

{
  system.stateVersion = 5;
  ids.gids.nixbld = 30000;

  nix = {
    enable = true;
    # package = pkgs.nix_2_19;
    # does not work yet because https://github.com/LnL7/nix-darwin/issues/158
    # tmp workaround in ~/.zshrc
    nixPath = [
      { nixpkgs-overlays = "\$HOME/.config/nixpkgs/overlays"; }
      { darwin-config = "\$HOME/.config/nixpkgs/darwin-configuration.nix"; }
      "/nix/var/nix/profiles/per-user/root/channels"
      "\$HOME/.nix-defexpr/channels"
    ];
    gc.automatic = true;
    extraOptions = ''
      experimental-features = nix-command
    '';
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  fonts.packages = [
    pkgs.hack-font
  ];

  # to load darwin-rebuild via /etc/static/zshrc
  # further configuration via home-manager
  # programs.home-manager.enable = true;
  system.primaryUser = username;
  programs.zsh.enable = true;
  services.lorri.enable = true;

  services.postgresql = {
    package = pkgs.postgresql_13;
    enable = true;
    enableTCPIP = true;
    dataDir = "/Users/" + username + "/postgres";
    settings = {
      max_connections = 250;
      shared_buffers = "80MB";
    };
    authentication = pkgs.lib.mkOverride 10 ''
      # Generated file; do not edit!
      local all pivotal          trust
      local all postgres         trust
      local all all              peer
      host  all all 127.0.0.1/32 md5
      host  all all ::1/128      md5
    '';
  };

  users.users = builtins.listToAttrs [{
    name = username;
    value  = {
      home = "/Users/" + username;
      shell = pkgs.zsh;
    };
  }];

  environment.etc = {
  "sudoers.d/10-nix-commands".text = let
    commands = [
      "/run/current-system/sw/bin/darwin-rebuild"
      "/run/current-system/sw/bin/nix*"
      "/nix/var/nix/profiles/default/bin/nix*"
      "/run/current-system/sw/bin/ln"
      "/nix/store/*/activate"
      "/bin/launchctl"
    ];
    commandsString = builtins.concatStringsSep ", " commands;
  in ''
    %admin ALL=(ALL:ALL) NOPASSWD: ${commandsString}
  '';
  };
}
