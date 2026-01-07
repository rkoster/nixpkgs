{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.zscaler;
in {
  options.zscaler = {
    enable = mkEnableOption "Zscaler SSL certificate configuration for Nix user config";

    certFile = mkOption {
      type = types.path;
      default = "/etc/ssl/nix-certs.pem";
      description = "Path to the Zscaler SSL certificate file";
    };
  };

  config = mkIf cfg.enable {
    home.file.".config/nix/nix.conf".text = ''
      ssl-cert-file = ${cfg.certFile}
    '';

    programs.git.extraConfig = {
      http = {
        sslCAInfo = cfg.certFile;
      };
    };
  };
}
