{ config, pkgs, ... }:

let customPkgs = import ./custom-packages.nix { pkgs = pkgs; };
in {
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

  home.packages = [
    pkgs.jq
    pkgs.lnav
    pkgs.tree
    # needed for emacs-nix-mode (otherwise triggers osx developer tools promt)
    pkgs.gcc
    pkgs.dasht
    pkgs.fly
    pkgs.lastpass-cli
    pkgs.fasd
    pkgs.vault

    customPkgs.ssoca
    customPkgs.leftovers
    customPkgs.bosh
    customPkgs.boshBootloader
    customPkgs.ytt
    customPkgs.cf
    customPkgs.spruce
    customPkgs.safe
    customPkgs.genesis
  ];

  programs.git = {
    enable = true;
    userName  = "rkoster";
    userEmail = "rkoster@starkandwayne.com";
    extraConfig = { credential = { helper = "osxkeychain"; } ; } ;
    ignores = [ "*~" ];
    lfs.enable = true;
  };


  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableNixDirenvIntegration = true;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;
      scan_timeout = 10;      
      format = "$directory$git_branch$line_break$character";    
      character = {
        success_symbol = "[❯](bold #d33682)";
        error_symbol = "[❯](bold #d33682)";        
      };
      directory.style	 = "bold #268bd2";
      git_branch = {
        format = "[$branch*]($style) ";
        style = "#839496";
      };
    };
  };
  programs.zsh = import ./program/zsh/default.nix { config = config; };
  programs.emacs = import ./program/emacs/default.nix { pkgs = pkgs; };
  programs.tmux = import ./program/tmux/default.nix { pkgs = pkgs; };

  home.stateVersion = "20.09";
}
