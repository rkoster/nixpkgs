{ username, inputs, config, pkgs, ... }:

let
  homeDir = "/Users/" + username;
in {
  # Import the base darwin-laptop role
  imports = [
    ../darwin-laptop/index.nix
    ../../modules/zscaler-home.nix
  ];

  # Enable Zscaler configuration
  zscaler = {
    enable = true;
    certFile = "/etc/ssl/nix-certs.pem";
  };

  # Add any other work-specific configurations here
}
