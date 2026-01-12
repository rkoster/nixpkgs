{ config, pkgs }:

let
  # Detect platform based on system
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  
  # Platform-specific nix-update command
  nixUpdateCommand = if isDarwin then ''
    sudo nix run --extra-experimental-features flakes nix-darwin/master#darwin-rebuild -- switch --flake ~/.config/nixpkgs && \
    source ~/.zshrc && \
    if [ -n "$TMUX" ]; then tmux source-file ~/.config/tmux/tmux.conf; fi
  '' else ''
    nix run --extra-experimental-features flakes home-manager/master#home-manager -- switch --flake ~/.config/home-manager && \
    source ~/.zshrc && \
    if [ -n "$TMUX" ]; then tmux source-file ~/.config/tmux/tmux.conf; fi
  '';
in

{
  enable = true;
  autosuggestion.enable = true;
  enableCompletion = true;
  defaultKeymap = "emacs";
  history = {
    save = 1000000000;
    share = true;
    size = 1000000000;
  };
  initContent =
    ''
    # Source nix profile (for container environments)
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    
    # Add ~/.opencode/bin to PATH to override nix-installed opencode
    export PATH="$HOME/.opencode/bin:$PATH"
    
    export XDG_CONFIG_HOME=${config.xdg.configHome}
    export XDG_RUNTIME_DIR="$HOME/Library/Caches/TemporaryItems"
    export EMACS_SOCKET_NAME="emacs-$(tmux display-message -p '#{window_id}' | tr -d @)-server"

    if [ -e "$HOME/.nix-defexpr/channels" ]; then
      export NIX_PATH="$HOME/.nix-defexpr/channels''${NIX_PATH:+:$NIX_PATH}"
    fi

    export ZSH_DISABLE_COMPFIX=true

    # Workaround till https://github.com/LnL7/nix-darwin/issues/158 is fixed
    export NIX_PATH="darwin-config=$HOME/.config/nixpkgs/darwin-configuration.nix:nixpkgs-overlays=$HOME/.config/nixpkgs/overlays:/nix/var/nix/profiles/per-user/root/channels''${NIX_PATH:+:$NIX_PATH}"

    fpath+=$XDG_CONFIG_HOME/zsh/snippets
    export fpath
    autoload -Uz $fpath[-1]/*(.:t)
    '';

  sessionVariables = {
    EDITOR = "emacs";
    LC_ALL = "en_US.UTF-8";
  };

  shellAliases = {
    emacs = "emacsclient -a '' -nw";
    es = "lsof -w $(ls $XDG_RUNTIME_DIR/emacs/*)";
    ek = "lsof -w $XDG_RUNTIME_DIR/emacs/\$EMACS_SOCKET_NAME | tail -n1 | awk '{print $2}' | xargs kill -9";
    e = "emacsclient --no-wait \${@}";
    brw = "br ~/workspace";
    be = "bundle exec ";
    ber = "bundle exec rspec ";
    intoto-inspect = "jq -r .payload | base64 -d | jq .";
    colima-start = "colima start --cpu 8 --memory 16 --disk 200 --arch x86_64 --vm-type vz --network-address --mount-type=virtiofs --mount $TMPDIR:w --mount $HOME:w; colima ssh -- sudo chmod 666 /var/run/docker.sock";
    colima-delete = "colima stop --force && colima delete --force";
    smith-auth = ''
      export TOOLSMITHS_API_TOKEN=$(lpass show --notes "Shared-BOSH Core (Pivotal Only)/toolsmiths-api-token" | head -n1 | cut -d'"' -f2)
      '';
    # Shepherd functions commented out - require internal Broadcom access
    # shepherd-tas-pools = ''
    #   shepherd list pool --namespace official --json | jq -r 'map(select(.template | contains("tas")) | .name).[]'
    #   echo -e "\nTo pick a pool: \nexport TAS_POOL=tas-5_0"
    # '';
    # shepherd-tas-claim = ''
    #   export ENVIRONMENT_LOCK_METADATA=$(mktemp --suffix=-tas-sheperd.json)
    #   export SHEPHERD_LEASE_ID=$(shepherd create lease \
    #     --namespace official --pool ''${TAS_POOL:=tas-10_0-lite} --duration 8h --json | jq -r '.id')
    #   shepherd get lease --namespace official ''${SHEPHERD_LEASE_ID} --interactive
    #   shepherd get lease --namespace official ''${SHEPHERD_LEASE_ID} --json | jq '.output' > ''${ENVIRONMENT_LOCK_METADATA}
    #   eval "$(smith bosh)"
    # '';
    # shepherd-tas-last-lease = ''
    #   export ENVIRONMENT_LOCK_METADATA=$(mktemp --suffix=-tas-sheperd.json)
    #   export SHEPHERD_LEASE_ID=$(shepherd get lease --namespace official --last-lease --json | jq -r '.id')
    #   shepherd get lease --namespace official ''${SHEPHERD_LEASE_ID} --json | jq '.output' > ''${ENVIRONMENT_LOCK_METADATA}
    #   eval "$(smith bosh)"
    # '';
    # shepherd-delete-my-leases = ''
    #   shepherd list lease --namespace official --json \
    #     | jq -r --arg user $(whoami) 'map(select(.user | contains($user)))[0].identifier' \
    #     | xargs -L1 shepherd delete lease --namespace official
    # '';
    nix-update = nixUpdateCommand;
    nix-flake-update = ''
      nix --extra-experimental-features flakes flake update --flake ~/.config/nixpkgs/
    '';
    incus-ws-start = ''
      incus start workspace 2>/dev/null || incus launch oci-ghcr:rkoster/workspace:latest workspace --network incusbr0
    '';
  };
}
