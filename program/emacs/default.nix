{ pkgs }:

{
  enable = true;
  package = pkgs.emacs-nox;
  extraPackages = epkgs: [
    epkgs.magit
    epkgs.go-mode
    epkgs.go-guru
    epkgs.nix-mode
    epkgs.nixpkgs-fmt
    epkgs.yaml-mode
    epkgs.flycheck-yamllint
    epkgs.gruvbox-theme
    epkgs.powerline
    epkgs.powerline-evil
  ];
}

