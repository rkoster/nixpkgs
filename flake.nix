{
  description = "Ruben's darwin system";

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";
    nixpkgs.url = "github:NixOS/nixpkgs/master";
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
    git-credential-1password.url = "github:ethrgeist/git-credential-1password";
    git-credential-1password.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
    ({ config, inputs, withSystem, ... }: {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      flake = let
        darwinUsername = "rubenkoster";
        darwinSystem = "x86_64-darwin";
        linuxUsername = "ruben";
        linuxSystem = "x86_64-linux";

        fly-overlay = import ./overlays/fly-versions.nix;
        local-pkgs-overlay = import ./overlays/local-pkgs.nix;
        # libfaketime-fix-overlay = import ./overlays/libfaketime-fix.nix;
        # texlive-fix-overlay = import ./overlays/texlive-fix.nix;

        mkOverlayedPkgs = system: import inputs.nixpkgs {
          inherit system;
          overlays = [
            fly-overlay
            local-pkgs-overlay
            # libfaketime-fix-overlay
            # texlive-fix-overlay
            inputs.community-emacs.overlay
          ];
          config = {
            allowUnfree = true;
            allowUnsupportedSystem = true;
          };
        };

        darwinPkgs = mkOverlayedPkgs darwinSystem;
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
         };
      #   homeConfigurations.rubenk = inputs.home.lib.homeManagerConfiguration {
      #     pkgs = overlayedPkgs;
      #     modules = [
      #       ./home.nix
      #       ({...}:
      #         {
      #           home.username = username;
      #           home.homeDirectory = "/Users/" + username;
      #           xdg.configHome = "/Users/" + username + "/.config";
      #           xdg.runtimeDir = "/Users/" + username + "/Library/Caches/TemporaryItems";
      #           home.stateVersion = "22.11";
      #         })
      #     ];
      #     extraSpecialArgs = { inherit inputs username; };
      # };
    };
  });
}
