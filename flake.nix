{
  description = "Ruben's darwin system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.url = "github:LnL7/nix-darwin/nix-darwin-24.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    community-emacs.url = "github:nix-community/emacs-overlay";
    community-emacs.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    ghostty.url = "github:ghostty-org/ghostty";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
    ({ config, inputs, withSystem, ... }: {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;
      flake = let
        username = "rubenk";
        system = "x86_64-darwin";
        fly-overlay = import ./overlays/fly-versions.nix;
        local-pkgs-overlay = import ./overlays/local-pkgs.nix;
        overlayedPkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [
            fly-overlay
            local-pkgs-overlay
            inputs.community-emacs.overlay
          ];
          config.allowUnfree = true;
        };
      in {
        darwinConfigurations = {
          "C02F12Y8MD6R" = inputs.nix-darwin.lib.darwinSystem {
            inherit system;
            modules = [
              ./darwin-configuration.nix
              inputs.home-manager.darwinModules.home-manager {
                home-manager = {
                  useUserPackages = false;
                  useGlobalPkgs = true;
                  users = builtins.listToAttrs [{
                    name = username;
                    value  = import ./roles/darwin-laptop/index.nix;
                  }];
                  extraSpecialArgs = { inherit inputs username; };
                };
              }
            ];
            specialArgs = { pkgs = overlayedPkgs; inherit inputs system username; };
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
