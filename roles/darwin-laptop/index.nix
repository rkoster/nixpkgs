{ config, pkgs, ... }:

{
  home.username = config.home.username;
  home.homeDirectory = config.home.homeDirectory;

  imports = [
    ../../programs/zsh/sources.nix
    ../../programs/emacs/sources.nix
  ];

  home.language = {
    ctype = "en_US.UTF-8";
    base = "en_US.UTF-8";
  };

  home.packages = with pkgs; [
    jq
    lnav
    tree
    pwgen
    ipcalc
    openssh
    watch
    wget
    aria
    git-duet
    comma
    jless
    # microplane

    coreutils # so realpath is globally available
    gcc # needed for emacs-nix-mode (otherwise triggers osx developer tools promt)
    clang-tools

    # lang server
    gopls
    godef
    yaml-language-server
    rnix-lsp
    solargraph
    terraform-lsp
    terraform # dependecy of terraform-lsp

    # misc
    leftovers
    hub-tool
    # xca # ssl gui

    # nix
    manix

    _1password
    lastpass-cli

    dyff
    bosh
    smith
    om
    ytt
    cf
    spruce
    bundix
  ];

  programs.git = {
    enable = true;
    userName  = "rkoster";
    userEmail = "hi@rkoster.dev";
    extraConfig = {
      credential = { helper = "osxkeychain"; };
      pull = { rebase = true; };
      init = { defaultBranch = "main"; };
    };
    ignores = [ "*~" ];
    lfs.enable = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableNixDirenvIntegration = true;
  };

  programs.ssh = {
    enable = true;
    compression = true;
    forwardAgent = false;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.pazi = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.noti = {
    enable = true;
  };

  programs.starship = import ../../programs/starship/default.nix;
  programs.broot = import ../../programs/broot/default.nix;
  programs.alacritty = import ../../programs/alacritty/default.nix;
  programs.zsh = import ../../programs/zsh/default.nix { config = config; pkgs = pkgs; };
  programs.emacs = import ../../programs/emacs/default.nix { pkgs = pkgs; };
  programs.tmux = import ../../programs/tmux/default.nix { pkgs = pkgs; };

  home.stateVersion = "21.03";
}
