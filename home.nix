{ username, inputs, ... }:

inputs.home-manager.darwinModules.home-manager {
  home-manager = {
    useUserPackages = false;
    useGlobalPkgs = true;
    users = builtins.listToAttrs [{
      name = username;
      value  = import ./roles/darwin-laptop/index.nix { inherit pkgs system; };
    }];
  };
}
