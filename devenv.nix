{ pkgs, lib, config, inputs, ... }:

let
  # Allow unfree packages (required for packer)
  unfree-pkgs = import inputs.nixpkgs {
    system = pkgs.stdenv.system;
    config.allowUnfree = true;
  };
  
  # Duplicate overlay definitions to include custom packages
  # This is necessary because devenv.sh operates independently from the flake system.
  # Keep these definitions in sync with overlays/local-pkgs.nix when packages are added, updated, or removed to avoid configuration drift.
  customPkgs = {
    dyff = pkgs.callPackage ./pkgs/dyff { };
    jless = pkgs.callPackage ./pkgs/jless { };
    git-duet = pkgs.callPackage ./pkgs/git-duet { };
  };

  # Extend pkgs with custom packages before importing container packages
  # Use unfree-pkgs for packages that might need unfree licenses
  extendedPkgs = unfree-pkgs // customPkgs;
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
    startupCommand = "${unfree-pkgs.zsh}/bin/zsh -l";
  };
}
