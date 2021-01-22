{ config, pkgs, ... }:

{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;


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
    hack-font

    # needed for emacs-nix-mode (otherwise triggers osx developer tools promt)
    gcc
    clang-tools
    dasht

    # lang server
    gopls
    yaml-language-server
    rnix-lsp

    fly
    lastpass-cli
    google-cloud-sdk
    vault

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
      {
        invocation = "open";
        key = "enter";
        leave_broot = false;
        execution = "emacsclient --no-wait {file}";
      }
    ];
  };

  programs.noti = {
    enable = true;
  };

  programs.alacritty = import ../../programs/alacritty/default.nix;
  # programs.alacritty = {
  #   enable = true;
  # };

  programs.zsh = import ../../programs/zsh/default.nix { config = config; pkgs = pkgs; };
  programs.emacs = import ../../programs/emacs/default.nix { pkgs = pkgs; };
  programs.tmux = import ../../programs/tmux/default.nix { pkgs = pkgs; };

  #  services.caffeine.enable = true;
  # services.emacs.enable = true;

  home.stateVersion = "21.03";

  home.file = {
    hackRegular = {
      source = ~/.nix-profile/share/fonts/hack/Hack-Regular.ttf;
      target = "Library/Fonts/Hack Regular.tff";
    };
  };
}
