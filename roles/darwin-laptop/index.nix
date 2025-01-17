{ username, inputs, config, pkgs, ... }:

let
  homeDir = "/Users/" + username;
in {
  home.username = username;
  home.homeDirectory = homeDir;

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
    ripgrep
    # lnav
    tree
    pwgen
    ipcalc
    openssh
    jre_minimal # needed by Synopsys Detect
    watch
    hwatch
    wget
    nmap
    arp-scan
    aria
    git-duet
    comma
    jless
    openapi-tui
    packer
    colima
    docker
    kubectl
    gh
    devbox

    coreutils # so realpath is globally available
    gcc # needed for emacs-nix-mode (otherwise triggers osx developer tools promt)

    _1password-cli
    lastpass-cli

    # language server
    gopls # go
    yaml-language-server # yaml
    solargraph # ruby
    nodePackages.bash-language-server # bash

    ollama

    # inputs.ghostty.packages.x86_64-darwin.default

    dyff
    bosh
    # smith
    shepherd
    om
    # bosh-bootloader
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
      user = {
        signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFq2Q5tJbPHP1ignMYswvcqt16RVTiznVB6JFaz87fhc";
      };
      gpg = { format = "ssh"; };
      "gpg \"ssh\"" = {
        program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      };
      commit = { gpgsign = true; };
      tag = { gpgsign = true; };
    };
    ignores = [ "*~" ];
    lfs.enable = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.ssh = {
    enable = true;
    compression = true;
    forwardAgent = false;
    extraConfig = ''
      IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    '';
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
  programs.zsh = import ../../programs/zsh/default.nix { inherit config pkgs; };
  programs.emacs = import ../../programs/emacs/default.nix { inherit pkgs; };
  programs.tmux = import ../../programs/tmux/default.nix { inherit pkgs; };
  # programs.kitty = import ../../programs/kitty/default.nix { pkgs = pkgs; };
  programs.ghostty = import ../../programs/ghostty/default.nix { inherit homeDir pkgs; };

  home.stateVersion = "21.03";
}
