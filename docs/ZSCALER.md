# Zscaler Configuration for Work Machines

This configuration supports optional Zscaler SSL certificate setup for corporate environments that use Zscaler proxy.

## What This Does

When enabled, the Zscaler module automatically:
1. Extracts all SSL certificates from macOS system keychains
2. Creates a combined certificate bundle at `/etc/ssl/nix-certs.pem`
3. Configures Nix to use these certificates
4. Configures Git to use these certificates
5. Adds your user to the Nix trusted users list

## Configuration for Work Machines

### 1. Update flake.nix

Add a new darwinConfiguration for your work machine in `flake.nix`:

```nix
darwinConfigurations = {
  # ... existing configurations ...
  
  "Work-MacBook-Pro" = inputs.nix-darwin.lib.darwinSystem {
    system = darwinSystem;
    modules = [
      ./darwin-configuration.nix
      inputs.home-manager.darwinModules.home-manager {
        home-manager = {
          useUserPackages = false;
          useGlobalPkgs = true;
          users = builtins.listToAttrs [{
            name = "Work.Username";  # Replace with your work username
            value = import ./roles/darwin-work/index.nix;
          }];
          extraSpecialArgs = { inherit inputs; username = "Work.Username"; };
        };
      }
      # Enable Zscaler at system level
      ({ ... }: {
        zscaler = {
          enable = true;
          trustedUsers = [ "root" "Work.Username" ];  # Replace with your work username
        };
      })
    ];
    specialArgs = { pkgs = darwinPkgs; inherit inputs; system = darwinSystem; username = "Work.Username"; };
  };
};
```

### 2. Certificate Generation

The certificate bundle is automatically generated during system activation by extracting certificates from:
- `/System/Library/Keychains/SystemRootCertificates.keychain` (System root certificates)
- `/Library/Keychains/System.keychain` (Including Zscaler certificates)

The bundle is created at `/etc/ssl/nix-certs.pem` with proper permissions (644).

### 3. System-level Configuration

The Zscaler module automatically configures `/etc/nix/nix.conf` with:
- `ssl-cert-file = /etc/ssl/nix-certs.pem`
- `trusted-users = root <your-username>`

### 4. User-level Configuration

The `darwin-work` role imports the `zscaler-home` module which configures:
- `~/.config/nix/nix.conf` with `ssl-cert-file = /etc/ssl/nix-certs.pem`
- Git global configuration with `http.sslCAInfo = /etc/ssl/nix-certs.pem`

### 5. Customization

You can customize the Zscaler configuration in your role or system configuration:

```nix
zscaler = {
  enable = true;
  certFile = "/path/to/custom/cert.pem";  # Optional: custom certificate path
  trustedUsers = [ "root" "username" ];    # System-level only
};
```

## Applying the Configuration

On your work machine, run:

```bash
darwin-rebuild switch --flake .#Work-MacBook-Pro
```

Replace `Work-MacBook-Pro` with whatever hostname you chose in your flake.nix.

## Disabling Zscaler Configuration

To disable Zscaler configuration (e.g., on personal machines), simply:

1. Use the `darwin-laptop` role instead of `darwin-work`, or
2. Set `zscaler.enable = false;` in your configuration

## Files Created/Modified

- `/etc/ssl/nix-certs.pem` - Combined certificate bundle (auto-generated from macOS keychains)
- `/etc/nix/nix.conf` - System-level Nix configuration (managed by nix-darwin)
  - Contains `ssl-cert-file` and `trusted-users` settings
- `~/.config/nix/nix.conf` - User-level Nix configuration (managed by home-manager)
  - Contains `ssl-cert-file` setting
- `~/.gitconfig` - Git configuration (managed by home-manager)
  - Contains `http.sslCAInfo` setting

## How It Works

On each `darwin-rebuild switch`, the activation script:
1. Extracts all certificates from macOS system keychains using the `security` command
2. Combines them into a single PEM file
3. Places the file at `/etc/ssl/nix-certs.pem` with appropriate permissions

This ensures that whenever Zscaler updates its certificates (stored in the System keychain), 
they will be automatically included the next time you rebuild your system.
