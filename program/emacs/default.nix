{ pkgs }:

{
  enable = true;
  package = pkgs.emacs-nox;
  extraPackages = epkgs: [
    epkgs.use-package
    # util
    epkgs.magit
    epkgs.wgrep
    epkgs.company
    epkgs.flycheck
    epkgs.which-key
    epkgs.projectile
    epkgs.whitespace-cleanup-mode
    
    # lang
    epkgs.lsp-mode
    epkgs.lsp-ui    
    epkgs.go-mode
    epkgs.nix-mode
    epkgs.yaml-mode

    # visual
    epkgs.gruvbox-theme
    epkgs.powerline
    epkgs.powerline-evil
   ];
}

