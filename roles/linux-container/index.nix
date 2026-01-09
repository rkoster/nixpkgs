{ username, config, pkgs, ... }:

let
  homeDir = "/home/" + username;
  containerPackages = import ./packages.nix { inherit pkgs; };
in {
  home.username = username;
  home.homeDirectory = homeDir;

  imports = [
    ../../programs/zsh/sources.nix
    ../../programs/emacs/sources.nix
    ../../programs/opencode
    (import ../../programs/git/default.nix { inherit pkgs homeDir; })
  ];

  home.language = {
    ctype = "en_US.UTF-8";
    base = "en_US.UTF-8";
  };

  home.packages = containerPackages;

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.pazi = {
    enable = true;
    enableZshIntegration = true;
  };

  home.file.".local/bin/configure-docker" = {
    source = ../../scripts/configure-docker.sh;
    executable = true;
  };

  home.file.".local/bin/configure-rootless-containers" = {
    source = ../../scripts/configure-rootless-containers.sh;
    executable = true;
  };

  home.file.".local/bin/verify-rootless-setup" = {
    source = ../../scripts/verify-rootless-setup.sh;
    executable = true;
  };

  home.file.".local/share/doc/rootless-containers.md" = {
    source = ../../docs/rootless-containers.md;
  };

  programs.noti = {
    enable = true;
  };

  programs.starship = import ../../programs/starship/default.nix;
  programs.broot = import ../../programs/broot/default.nix;
  programs.zsh = import ../../programs/zsh/default.nix { inherit config pkgs; };
  programs.emacs = import ../../programs/emacs/default.nix { inherit pkgs; };
  programs.tmux = import ../../programs/tmux/default.nix { inherit pkgs; };

  home.stateVersion = "21.03";
}
