{
  description = "Ruben's darwin system";

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";
    # nixpkgs.url = "github:NixOS/nixpkgs/master";
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixpkgs-unstable&shallow=1";
    # home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-25.05";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    community-emacs.url = "github:nix-community/emacs-overlay";
    community-emacs.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    ghostty.url = "github:ghostty-org/ghostty";
    # bosh-oci-builder.url = "github:rkoster/bosh-oci-builder";
    deskrun.url = "github:rkoster/deskrun";
    instant-bosh.url = "github:rkoster/instant-bosh";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
    ({ config, inputs, withSystem, ... }: {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;

      perSystem = { system, pkgs, ... }:
        let
          fly-overlay = import ./overlays/fly-versions.nix;
          local-pkgs-overlay = import ./overlays/local-pkgs.nix;
          external-flakes-overlay = import ./overlays/external-flakes.nix inputs;

          overlayedPkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              fly-overlay
              local-pkgs-overlay
              external-flakes-overlay
              inputs.community-emacs.overlay
            ];
            config = {
              allowUnfree = true;
              allowUnsupportedSystem = true;
              allowUnfreePredicate = pkg: true;
            };
          };

          nix2container = inputs.nix2container.packages.${system}.nix2container;

          # Container image configuration (only for x86_64-linux)
          containerConfig = if system == "x86_64-linux" then
            let
              containerUsername = "ruben";
              containerUid = "1000";
              containerGid = "1000";
              containerHome = "/home/${containerUsername}";

              # Build home-manager configuration for container
              homeConfig = inputs.home-manager.lib.homeManagerConfiguration {
                pkgs = overlayedPkgs;
                modules = [
                  ./roles/linux-container/index.nix
                  ({...}: {
                    home.username = containerUsername;
                    home.homeDirectory = containerHome;
                    home.stateVersion = "21.03";
                  })
                ];
                extraSpecialArgs = { inherit inputs; username = containerUsername; };
              };

              # Get the home-manager activation package (contains all dotfiles)
              hmActivation = homeConfig.activationPackage;

              # Get all packages from the home configuration
              containerPackages = import ./roles/linux-container/packages.nix { pkgs = overlayedPkgs; };

              # Layer 1: Base system utilities (rarely changes)
              baseLayer = nix2container.buildLayer {
                deps = with overlayedPkgs; [
                  bashInteractive
                  coreutils
                  gnugrep
                  gnused
                  gawk
                  gnutar
                  gzip
                  xz
                  findutils
                  cacert
                  zsh
                  less
                  ncurses
                  tzdata
                ];
              };

              # Layer 2: Nix and git (occasionally changes)
              nixLayer = nix2container.buildLayer {
                deps = with overlayedPkgs; [
                  nix
                  git
                  openssh
                  curl
                  wget
                ];
                layers = [ baseLayer ];
              };

              # Layer 3: Dev tools (changes more often)
              devToolsLayer = nix2container.buildLayer {
                deps = containerPackages;
                layers = [ nixLayer ];
              };

              # Layer 4: Home-manager dotfiles (changes most often)
              dotfilesLayer = nix2container.buildLayer {
                deps = [ hmActivation ];
                layers = [ devToolsLayer ];
              };

              # Create passwd/group files
              passwdFile = overlayedPkgs.writeText "passwd" ''
                root:x:0:0:root:/root:/bin/bash
                ${containerUsername}:x:${containerUid}:${containerGid}:${containerUsername}:${containerHome}:/bin/zsh
                nobody:x:65534:65534:Nobody:/nonexistent:/sbin/nologin
              '';

              groupFile = overlayedPkgs.writeText "group" ''
                root:x:0:
                ${containerUsername}:x:${containerGid}:
                nogroup:x:65534:
              '';

              shadowFile = overlayedPkgs.writeText "shadow" ''
                root:!:1::::::
                ${containerUsername}:!:1::::::
                nobody:!:1::::::
              '';

              nsswitch = overlayedPkgs.writeText "nsswitch.conf" ''
                passwd:    files
                group:     files
                shadow:    files
                hosts:     files dns
                networks:  files
              '';

              # Nix configuration for container
              nixConf = overlayedPkgs.writeText "nix.conf" ''
                experimental-features = nix-command flakes
                sandbox = false
                trusted-users = root ${containerUsername}
              '';

              # Setup script to activate home-manager on first boot
              setupScript = overlayedPkgs.writeShellScript "setup-home" ''
                #!/bin/sh
                # Create home directory if it doesn't exist
                mkdir -p ${containerHome}
                chown ${containerUid}:${containerGid} ${containerHome}

                # Run home-manager activation as the user
                if [ ! -f ${containerHome}/.hm-activated ]; then
                  su - ${containerUsername} -c "${hmActivation}/activate" || true
                  touch ${containerHome}/.hm-activated
                fi

                # Execute the original command
                exec "$@"
              '';

              # Create a root filesystem with all necessary files
              rootFsSetup = overlayedPkgs.runCommand "root-fs" {} ''
                mkdir -p $out/etc
                mkdir -p $out/tmp
                mkdir -p $out/var/tmp
                mkdir -p $out/root
                mkdir -p $out${containerHome}

                # Copy passwd/group files
                cp ${passwdFile} $out/etc/passwd
                cp ${groupFile} $out/etc/group
                cp ${shadowFile} $out/etc/shadow
                cp ${nsswitch} $out/etc/nsswitch.conf

                # SSL certificates
                mkdir -p $out/etc/ssl/certs
                ln -s ${overlayedPkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs/ca-bundle.crt
                ln -s ${overlayedPkgs.cacert}/etc/ssl/certs/ca-bundle.crt $out/etc/ssl/certs/ca-certificates.crt

                # Nix configuration
                mkdir -p $out/etc/nix
                cp ${nixConf} $out/etc/nix/nix.conf

                # Create nix database directory
                mkdir -p $out/nix/var/nix/db
                mkdir -p $out/nix/var/nix/gcroots
                mkdir -p $out/nix/var/nix/profiles

                # Setup script
                mkdir -p $out/usr/local/bin
                cp ${setupScript} $out/usr/local/bin/setup-home
                chmod +x $out/usr/local/bin/setup-home

                # Timezone
                mkdir -p $out/etc
                ln -s ${overlayedPkgs.tzdata}/share/zoneinfo/UTC $out/etc/localtime
                echo "UTC" > $out/etc/timezone

                # Create shells file
                echo "/bin/sh" > $out/etc/shells
                echo "/bin/bash" >> $out/etc/shells
                echo "/bin/zsh" >> $out/etc/shells

                # Link zsh and bash to /bin
                mkdir -p $out/bin
                ln -s ${overlayedPkgs.bashInteractive}/bin/bash $out/bin/bash
                ln -s ${overlayedPkgs.bashInteractive}/bin/bash $out/bin/sh
                ln -s ${overlayedPkgs.zsh}/bin/zsh $out/bin/zsh
              '';

              # Copy home-manager generated dotfiles
              dotfilesSetup = overlayedPkgs.runCommand "dotfiles-setup" {} ''
                mkdir -p $out${containerHome}
                
                # Copy all home-manager generated files
                if [ -d "${hmActivation}/home-files" ]; then
                  cp -rL ${hmActivation}/home-files/. $out${containerHome}/ || true
                fi
                
                # Ensure proper ownership markers (will be applied at runtime)
                # Create .profile to source nix
                cat > $out${containerHome}/.profile << 'EOF'
                if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
                  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
                fi
                export PATH="$HOME/.nix-profile/bin:$PATH"
                EOF
                
                # Create .zshenv
                cat > $out${containerHome}/.zshenv << 'EOF'
                export ZDOTDIR="$HOME"
                if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
                  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
                fi
                export PATH="$HOME/.nix-profile/bin:$PATH"
                EOF
              '';

            in {
              workspace-image = nix2container.buildImage {
                name = "ghcr.io/rkoster/workspace";
                tag = "latest";

                layers = [
                  baseLayer
                  nixLayer
                  devToolsLayer
                  dotfilesLayer
                ];

                copyToRoot = [
                  rootFsSetup
                  dotfilesSetup
                ];

                config = {
                  User = containerUsername;
                  WorkingDir = containerHome;
                  Env = [
                    "HOME=${containerHome}"
                    "USER=${containerUsername}"
                    "SHELL=/bin/zsh"
                    "TERM=xterm-256color"
                    "LANG=en_US.UTF-8"
                    "LC_ALL=en_US.UTF-8"
                    "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
                    "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
                    "PATH=/bin:${overlayedPkgs.nix}/bin:${overlayedPkgs.git}/bin:${containerHome}/.nix-profile/bin:/nix/var/nix/profiles/default/bin"
                  ];
                  Cmd = [ "/bin/zsh" ];
                };
              };
            }
          else {};
        in {
          # Make overlayed packages available via legacyPackages
          legacyPackages = overlayedPkgs;

          # Export container packages for x86_64-linux
          packages = containerConfig;
        };

      flake = let
        darwinUsername = "rubenkoster";
        darwinSystem = "x86_64-darwin";
        darwinWorkUsername = "Ruben.Koster";
        darwinWorkSystem = "aarch64-darwin";
        linuxUsername = "ruben";
        linuxSystem = "x86_64-linux";

        fly-overlay = import ./overlays/fly-versions.nix;
        local-pkgs-overlay = import ./overlays/local-pkgs.nix;
        external-flakes-overlay = import ./overlays/external-flakes.nix inputs;

        mkOverlayedPkgs = system: import inputs.nixpkgs {
          inherit system;
          overlays = [
            fly-overlay
            local-pkgs-overlay
            external-flakes-overlay
            inputs.community-emacs.overlay
          ];
          config = {
            allowUnfree = true;
            allowUnsupportedSystem = true;
            allowUnfreePredicate = pkg: true;
          };
        };

        darwinPkgs = mkOverlayedPkgs darwinSystem;
        darwinWorkPkgs = mkOverlayedPkgs darwinWorkSystem;
        linuxPkgs = mkOverlayedPkgs linuxSystem;
       in {
         darwinConfigurations = {
           "Rubens-MacBook-Pro" = inputs.nix-darwin.lib.darwinSystem {
             system = darwinSystem;
             modules = [
               ./darwin-configuration.nix
               inputs.home-manager.darwinModules.home-manager {
                 home-manager = {
                   useUserPackages = false;
                   useGlobalPkgs = true;
                   users = builtins.listToAttrs [{
                     name = darwinUsername;
                     value  = import ./roles/darwin-laptop/index.nix;
                   }];
                   extraSpecialArgs = { inherit inputs; username = darwinUsername; };
                 };
               }
             ];
             specialArgs = { pkgs = darwinPkgs; inherit inputs; system = darwinSystem; username = darwinUsername; };
           };

           # Add this new configuration for work laptop
           "Kosters-MacBook-Pro" = inputs.nix-darwin.lib.darwinSystem {
             system = darwinWorkSystem;
             modules = [
               ./darwin-configuration.nix
               inputs.home-manager.darwinModules. home-manager {
                 home-manager = {
                   useUserPackages = false;
                   useGlobalPkgs = true;
                   users = builtins.listToAttrs [{
                     name = darwinWorkUsername;
                     value  = import ./roles/darwin-work-laptop/index.nix;
                   }];
                   extraSpecialArgs = { inherit inputs; username = darwinWorkUsername; };
                 };
               }
               ({ ... }: {
                 zscaler = {
                   enable = true;
                   trustedUsers = [ "root" darwinWorkUsername ];
                 };
               })
             ];
              specialArgs = { pkgs = darwinWorkPkgs; inherit inputs; system = darwinWorkSystem; username = darwinWorkUsername; };
           };
         };

         homeConfigurations = {
           "ruben" = inputs.home-manager.lib.homeManagerConfiguration {
             pkgs = linuxPkgs;
             modules = [
               ./roles/linux-workstation/index.nix
               ({...}: {
                 home.username = linuxUsername;
                 home.homeDirectory = "/home/ruben";
                 home.stateVersion = "21.03";
               })
             ];
             extraSpecialArgs = { inherit inputs; username = linuxUsername; };
           };

           # Container-specific home configuration
           "container" = inputs.home-manager.lib.homeManagerConfiguration {
             pkgs = linuxPkgs;
             modules = [
               ./roles/linux-container/index.nix
               ({...}: {
                 home.username = "ruben";
                 home.homeDirectory = "/home/ruben";
                 home.stateVersion = "21.03";
               })
             ];
             extraSpecialArgs = { inherit inputs; username = "ruben"; };
           };
         };
    };
  });
}
