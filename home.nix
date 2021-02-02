{ config, pkgs, ... }:

let
  username = builtins.getEnv "USER";
  hmConfig = {
    home.username = username;
    home.homeDirectory = "/Users/" + username;
    xdg.configHome = "/Users/" + username + "/.config";
  };
in {

  imports = [ <home-manager/nix-darwin> ];

  home-manager = {
    useUserPackages = false;
    useGlobalPkgs = true;
    users = builtins.listToAttrs [{
      name = username;
      value  = import ./roles/darwin-laptop/index.nix { config = hmConfig; pkgs = pkgs; };
    }];
  };
}
