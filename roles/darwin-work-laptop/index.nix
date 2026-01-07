{ username, inputs, config, pkgs, ... }:

let
  homeDir = "/Users/" + username;
in {
  home.username = username;
  home.homeDirectory = homeDir;

  imports = [
    ../../programs/zsh/sources.nix
    ../../programs/emacs/sources.nix
    ../../modules/zscaler-home.nix
  ];

  home.language = {
    ctype = "en_US.UTF-8";
    base = "en_US.UTF-8";
  };

  home.packages = with pkgs; [
    jq
    ripgrep
    tree
    pwgen
    ipcalc
    openssh
    watch
    hwatch
    wget
    nmap
    arp-scan
    comma
    openapi-tui
    packer
    colima
    docker
    kubectl
    k9s
    gh
    devbox
    gnutar
    retry
    dive

    sshuttle
    sshpass

    coreutils # so realpath is globally available
    gcc # needed for emacs-nix-mode

    _1password-cli
    # lastpass-cli  # May not be needed at work

    # language server
    gopls # go
    yaml-language-server # yaml
    solargraph # ruby
    nodePackages. bash-language-server # bash

    opencode

    google-cloud-sdk

    kind

    dyff
    bosh
    ytt
    cf
    spruce
    bundix
    credhub
    # inputs.bosh-oci-builder.packages.${pkgs.system}.bob
    ibosh

    pget
    imgpkg
    vendir
    ytt
  ];

  programs.git = {
    enable = true;
    userName  = "Ruben Koster";
    userEmail = "hi@rkoster.dev";
    extraConfig = {
      credential = { helper = "osxkeychain"; };
      pull = { rebase = true; };
      init = { defaultBranch = "main"; };
      push = { autoSetupRemote = true; };
      
      # Git SSL configuration for corporate environment
      http = {
        sslCAInfo = "/etc/ssl/nix-certs.pem";
        sslBackend = "openssl";
      };
      
      user = {
        signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFq2Q5tJbPHP1ignMYswvcqt16RVTiznVB6JFaz87fhc";
      };
      gpg = { format = "ssh"; };
      "gpg \"ssh\"" = {
        program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
      };
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

  programs. direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs. ssh = {
    enable = true;
    compression = true;
    forwardAgent = false;
    extraConfig = ''
      Host *
        IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    '';
  };

  zscaler = {
    enable = true;
    certFile = "/etc/ssl/nix-certs.pem";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.pazi = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.starship = import ../../programs/starship/default.nix;
  programs.broot = import ../../programs/broot/default.nix;
  programs.zsh = import ../../programs/zsh/default.nix { inherit config pkgs; };
  programs.emacs = import ../../programs/emacs/default.nix { inherit pkgs; };
  programs.tmux = import ../../programs/tmux/default.nix { inherit pkgs; };
  programs.ghostty = import ../../programs/ghostty/default.nix { inherit homeDir pkgs; };

  home. stateVersion = "24.05";
}
