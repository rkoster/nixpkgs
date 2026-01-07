{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.zscaler;
in {
  options.zscaler = {
    enable = mkEnableOption "Zscaler SSL certificate configuration for Nix";

    certFile = mkOption {
      type = types.path;
      default = "/etc/ssl/nix-certs.pem";
      description = "Path to the Zscaler SSL certificate file";
    };

    trustedUsers = mkOption {
      type = types.listOf types.str;
      default = [ "root" ];
      description = "List of trusted users for Nix daemon";
      example = [ "root" "username" ];
    };
  };

  config = mkIf cfg.enable {
    nix.settings = {
      ssl-cert-file = cfg.certFile;
      trusted-users = cfg.trustedUsers;
    };

    # Activation script to generate the certificate bundle from macOS keychains
    system.activationScripts.postActivation.text = mkAfter ''
      echo "Setting up Zscaler SSL certificates..."
      
      # Create /etc/ssl directory if it doesn't exist
      if [ ! -d /etc/ssl ]; then
        mkdir -p /etc/ssl
      fi
      
      # Generate certificate bundle from macOS keychains
      security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain > /tmp/nix-certs.pem 2>/dev/null || true
      security find-certificate -a -p /Library/Keychains/System.keychain >> /tmp/nix-certs.pem 2>/dev/null || true
      
      # Move to final location and set permissions
      if [ -f /tmp/nix-certs.pem ]; then
        mv /tmp/nix-certs.pem ${cfg.certFile}
        chmod 644 ${cfg.certFile}
        echo "SSL certificates updated at ${cfg.certFile}"
      else
        echo "Warning: Failed to generate SSL certificate bundle"
      fi
    '';
  };
}
