{ pkgs }:

{
  enable = true;
  package = (pkgs.emacsWithPackagesFromUsePackage {
    config = ./emacs.el;
    defaultInitFile = true;
    package = pkgs.emacs29-nox;
    alwaysEnsure = true;
    extraEmacsPackages = epkgs: [
      epkgs.treesit-grammars.with-all-grammars
    ];
  });
}
