{ pkgs, lib, config, ... }:

let
  # Duplicate overlay definitions to include custom packages
  # This is necessary because devenv.sh operates independently from the flake system.
  # Keep these definitions in sync with overlays/local-pkgs.nix when packages are added, updated, or removed to avoid configuration drift.
  customPkgs = {
    dyff = pkgs.callPackage ./pkgs/dyff { };
    jless = pkgs.callPackage ./pkgs/jless { };
  };

  # Extend pkgs with custom packages before importing container packages
  extendedPkgs = pkgs // customPkgs;
  containerPackages = import ./roles/linux-container/packages.nix { pkgs = extendedPkgs; };

in {
  name = "nix-dev-container";

  packages = containerPackages ++ (with pkgs; [
    zsh
    tmux
    starship
    broot
    fzf
    direnv
    nix-direnv
    git
    emacs-nox
  ]);

  containers."workspace" = {
    name = "workspace";
    copyToRoot = null;
    startupCommand = "${pkgs.zsh}/bin/zsh -l";
  };
}
