# Agent Guidelines for Nix Configuration Repository

## Build/Test Commands
- **Full rebuild**: `darwin-rebuild switch` (macOS) or `nix run --extra-experimental-features flakes home-manager/master#home-manager -- switch --flake ~/.config/home-manager` (Linux)
- **Flake update**: `nix flake update`
- **Test single package**: `nix build .#<package-name>` (e.g., `nix build .#bosh`)
- **Check flake**: `nix flake check`
- **Dry run**: `darwin-rebuild switch --dry-run` (macOS) or `nix run --extra-experimental-features flakes home-manager/master#home-manager -- switch --dry-run --flake ~/.config/home-manager` (Linux)
- **Search packages**: `nix search nixpkgs <package-name> 2>/dev/null` (e.g., `nix search nixpkgs krunvm 2>/dev/null`)
- **Manual package access**: If packages aren't in PATH, find them with `find /nix/store -name "bin" -type d | xargs -I {} sh -c 'ls -la {}/<package> >/dev/null 2>&1 && echo {}'`

## Code Style Guidelines

### Nix Language Conventions
- Use 2-space indentation consistently
- Prefer `let ... in` for complex expressions
- Use `with lib;` for library functions
- Follow `callPackage` pattern for package definitions
- Use descriptive variable names (e.g., `darwinUsername`, `linuxSystem`)

### File Organization
- Package definitions: `pkgs/<name>/default.nix`
- Program configs: `programs/<name>/default.nix`
- Role configs: `roles/<platform>/index.nix`
- Overlays: `overlays/<name>.nix`

### Naming Conventions
- Use kebab-case for file names and directories
- Use camelCase for Nix variable names
- Package names should match upstream repository names
- Use descriptive commit messages following conventional commits

### Imports and Dependencies
- Group imports by type (inputs, overlays, modules)
- Use relative paths for local imports (`../` or `./`)
- Prefer `inputs.<name>.packages.<system>.default` for external packages
- Document version pins and why they're chosen

### Error Handling
- Use `lib.mkIf` for conditional configurations
- Provide fallback values with `lib.mkDefault`
- Use `lib.mkMerge` for combining configurations
- Validate inputs with `lib.types` where appropriate

### Security
- Never commit secrets or sensitive configuration
- Use `config.age` or similar for secrets management
- Review package hashes before updating
- Follow principle of least privilege in service configurations</content>
</xai:function_call
</xai:function_call name="read">
<parameter name="filePath">/home/ruben/.config/nixpkgs/AGENTS.md