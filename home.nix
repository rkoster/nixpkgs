{ config, pkgs, ... }:

{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "rubenkoster";
  home.homeDirectory = "/Users/rubenkoster";

  imports = [
    ./program/zsh/sources.nix
    ./program/emacs/sources.nix
  ];

  home.packages = with pkgs; [
    jq
    lnav
    tree
    zsh-powerlevel10k
    # needed for emacs-nix-mode (otherwise triggers osx developer tools promt)
    gcc                  
  ];

  programs.git = {
    enable = true;
    userName  = "rkoster";
    userEmail = "rkoster@starkandwayne.com";
  };

  programs.emacs = {
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
    ];
  };

  programs.tmux = {
    enable = true; 
    keyMode = "emacs";
    clock24 = true;
    historyLimit = 5000;
    terminal = "screen-256color";
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableNixDirenvIntegration = true;
  };

  programs.zsh = import ./program/zsh/default.nix { config = config; };

  home.stateVersion = "20.09";
}
