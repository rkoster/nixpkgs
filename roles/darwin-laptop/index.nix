{ config, pkgs, ... }:

{
  home.username = config.home.username;
  home.homeDirectory = config.home.homeDirectory;

  imports = [
#    ./program/zsh/sources.nix
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

    gcc # needed for emacs-nix-mode (otherwise triggers osx developer tools promt)
    clang-tools
    dasht

    # lang server
    gopls
    godef
    yaml-language-server
    rnix-lsp
    manix_master
    fzf

    lastpass-cli
    _1password
    google-cloud-sdk
    terraformer
    vault
    nodePackages.snyk

    ssoca
    leftovers
    bosh
    boshBootloader
    ytt
    vendir
    cf
    spruce
    safe
    genesis
    gojson
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
#    extraConfig =
  };


#   programs.fzf = {
#     enable = true;
# #    enableZshIntegration = true;
#   };

#   programs.zoxide = {
#     enable = true;
#     enableZshIntegration = true;
  #   };

#   programs.skim = {
#     enable = true;
#     enableZshIntegration = true;
  #   };


  programs.pazi = {
    enable = true;
    enableZshIntegration = true;
  };


  programs.mcfly = {
    enable = true;
    enableZshIntegration = true;
    keyScheme = "emacs";
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

  #  services.caffeine.enable = true;
  # services.emacs.enable = true;

  home.stateVersion = "21.03";
}
