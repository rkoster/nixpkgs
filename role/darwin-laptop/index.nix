{ config, pkgs, ... }:

let customPkgs = import ../../custom-packages.nix { pkgs = pkgs; };
in {
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;


  imports = [
#    ./program/zsh/sources.nix
    ../../program/emacs/sources.nix
  ];

  home.language = {
    ctype = "en_US.UTF-8";
    base = "en_US.UTF-8";
  };

  home.packages = [
    pkgs.jq
    pkgs.lnav
    pkgs.tree
    pkgs.pwgen
    pkgs.ipcalc
    pkgs.openssh
    pkgs.watch
    pkgs.wget

    # needed for emacs-nix-mode (otherwise triggers osx developer tools promt)
    pkgs.gcc
    pkgs.clang-tools
    pkgs.dasht

    # lang server
    pkgs.gopls
    pkgs.yaml-language-server
    pkgs.rnix-lsp

    pkgs.fly
    pkgs.lastpass-cli
    pkgs.google-cloud-sdk
    pkgs.vault

    customPkgs.ssoca
    customPkgs.leftovers
    customPkgs.bosh
    customPkgs.boshBootloader
    customPkgs.ytt
    customPkgs.vendir
    customPkgs.cf
    customPkgs.spruce
    customPkgs.safe
    customPkgs.genesis
  ];

  programs.git = {
    enable = true;
    userName  = "rkoster";
    userEmail = "rkoster@starkandwayne.com";
    extraConfig = {
      credential = { helper = "osxkeychain"; };
      pull = { rebase = true; };
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

  programs.broot = {
    enable = true;
    enableZshIntegration = true;
    skin = {
      # status_normal_fg = "grayscale(18)";
      # status_normal_bg = "grayscale(3)";
      # status_error_fg = "red";
      # status_error_bg = "yellow";
      # tree_fg = "red";
      # selected_line_bg = "grayscale(7)";
      # permissions_fg = "grayscale(12)";
      # size_bar_full_bg = "red";
      # size_bar_void_bg = "black";
      # directory_fg = "lightyellow";
      # input_fg = "cyan";
      # flag_value_fg = "lightyellow";
      # table_border_fg = "red";
      # code_fg = "lightyellow";
    };
    verbs = [
      { name = "line_down"; key = "ctrl-n"; execution = ":line_down" ; }
      { name = "line_up"; key = "ctrl-p"; execution = ":line_up" ; }
      { invocation = "open"; key = "enter"; execution = "emacsclient --no-wait {file}" ; }
    ];
  };

  programs.noti = {
    enable = true;
  };

  # programs.alacritty = {
  #   enable = true;
  # };

  programs.zsh = import ../../program/zsh/default.nix { config = config; pkgs = pkgs; };
  programs.emacs = import ../../program/emacs/default.nix { pkgs = pkgs; };
  programs.tmux = import ../../program/tmux/default.nix { pkgs = pkgs; };

  #  services.caffeine.enable = true;
  # services.emacs.enable = true;

  home.stateVersion = "21.03";
}
