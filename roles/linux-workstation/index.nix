{ username, inputs, config, pkgs, ... }:

let
  homeDir = "/home/" + username;
in {
  home.username = username;
  home.homeDirectory = homeDir;

  imports = [
    ../../programs/zsh/sources.nix
    ../../programs/emacs/sources.nix
    ../../programs/opencode
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
    # jless
    openapi-tui
    packer
    docker
    kubectl
    gh
    devbox
    earthly
    gnutar
    retry

    sshuttle
    sshpass

    coreutils # so realpath is globally available
    gcc # needed for emacs-nix-mode

    _1password-cli
    lastpass-cli

    # language server
    gopls # go
    yaml-language-server # yaml
    solargraph # ruby
    nodePackages.bash-language-server # bash

    # ollama
    # aider-chat-full
    opencode

    # inputs.ghostty.packages.x86_64-linux.default
    google-cloud-sdk

    kind
    cloud-provider-kind

    dyff
    bosh
    # smith
    # shepherd
    # sheepctl
    om
    bosh-bootloader
    ytt
    cf
    # spruce  # Temporarily disabled due to network issues
    bundix
    # kiln
    credhub

    pget
    imgpkg
    vendir
    ytt
  ];

  programs.git = {
    enable = true;
    userName  = "rkoster";
    userEmail = "hi@rkoster.dev";
    extraConfig = {
      pull = { rebase = true; };
      init = { defaultBranch = "main"; };
      push = { autoSetupRemote = true; };
      user = {
        signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFq2Q5tJbPHP1ignMYswvcqt16RVTiznVB6JFaz87fhc";
      };
      gpg = { format = "ssh"; };
      commit = { gpgsign = true; };
      tag = { gpgsign = true; };
      safe = { directory = "*"; };
    };
    ignores = [
      "*~"
      ".aider*"
    ];
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

  services.ollama = {
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