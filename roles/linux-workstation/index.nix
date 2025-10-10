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
    ../../programs/github-runner-kind
    (import ../../programs/kinto/default.nix { inherit config pkgs homeDir; })
    (import ../../programs/git/default.nix { inherit pkgs homeDir; })
    (import ../../programs/1password/default.nix { inherit pkgs; })
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
    kind
    k9s
    gh
    devbox
    earthly
    gnutar
    retry
    dive

    sshuttle
    sshpass

    coreutils # so realpath is globally available
    gcc # needed for emacs-nix-mode

    lastpass-cli

    # language server
    gopls # go
    yaml-language-server # yaml
    solargraph # ruby
    nodePackages.bash-language-server # bash

    # ollama
    # aider-chat-full
    opencode
    token-count

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

    # Mac-style keybindings
    kinto

    # For input device configuration
    xorg.xinput
    
    # VM management with Firecracker
    firecracker
  ];

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.pazi = {
    enable = true;
    enableZshIntegration = true;
  };

  home.file.".local/bin/1password-launcher" = {
    text = ''
      #!/bin/sh
      # Disable sandbox to avoid Chrome sandbox permission issues
      exec ${config.home.profileDirectory}/bin/1password --no-sandbox "$@"
    '';
    executable = true;
  };

  home.file.".local/share/applications/1password.desktop".text = ''
    [Desktop Entry]
    Name=1Password
    Exec=${homeDir}/.local/bin/1password-launcher %U
    Terminal=false
    Type=Application
    Icon=1password
    StartupWMClass=1Password
    Comment=Password manager and secure wallet
    MimeType=x-scheme-handler/onepassword;
    Categories=Office;
  '';

  home.file.".local/bin/configure-docker" = {
    source = ../../scripts/configure-docker.sh;
    executable = true;
  };

  programs.noti = {
    enable = true;
  };

  services.ollama = {
    enable = true;
  };

  # Enable natural scrolling (reverse scroll direction)
  home.pointerCursor = {
    package = pkgs.vanilla-dmz;
    name = "Vanilla-DMZ";
    x11.enable = true;
  };

  # Configure xinput for natural scrolling
  home.sessionVariables = {
    XINPUT_NATURAL_SCROLLING = "1";
  };

  # Script to set natural scrolling on session start
  home.file.".local/bin/setup-natural-scrolling" = {
    text = ''
      #!/bin/bash
      # Find all pointer devices and enable natural scrolling
      xinput list --id-only | while read -r id; do
        if xinput list-props "$id" 2>/dev/null | grep -q "Natural Scrolling Enabled"; then
          xinput set-prop "$id" "libinput Natural Scrolling Enabled" 1
        fi
      done
    '';
    executable = true;
  };

  programs.starship = import ../../programs/starship/default.nix;
  programs.broot = import ../../programs/broot/default.nix;
  programs.zsh = import ../../programs/zsh/default.nix { inherit config pkgs; };
  programs.emacs = import ../../programs/emacs/default.nix { inherit pkgs; };
  programs.tmux = import ../../programs/tmux/default.nix { inherit pkgs; };
  # programs.kitty = import ../../programs/kitty/default.nix { pkgs = pkgs; };
  programs.ghostty = import ../../programs/ghostty/default.nix { inherit homeDir pkgs; };

  # GitHub Actions Runner with kind
  programs.github-runner-kind = {
    enable = true;
    repositories = [
      {
        name = "rkoster/rubionic-workspace";
        maxRunners = 5;
        cacheSize = "10Gi";
      }
      {
        name = "rkoster/opencode-workspace-action";
        maxRunners = 3;
      }
    ];
  };

  home.stateVersion = "21.03";
}
