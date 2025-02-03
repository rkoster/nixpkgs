{ config, pkgs }:

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
  initExtra =
    ''
    export XDG_CONFIG_HOME=${config.xdg.configHome}
    export XDG_RUNTIME_DIR="$HOME/Library/Caches/TemporaryItems"
    export EMACS_SOCKET_NAME="emacs-$(tmux display-message -p '#{window_id}' | tr -d @)-server"

    if [ -e "$HOME/.nix-defexpr/channels" ]; then
      export NIX_PATH="$HOME/.nix-defexpr/channels''${NIX_PATH:+:$NIX_PATH}"
    fi

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
    colima-start = "colima start --cpu 8 --memory 16 --disk 200 --arch x86_64 --vm-type vz --mount-type=virtiofs --mount $TMPDIR; colima ssh -- sudo chmod 666 /var/run/docker.sock";
    colima-delete = "colima stop --force && colima delete --force";
    smith-auth = ''
      export TOOLSMITHS_API_TOKEN=$(lpass show --notes "Shared-BOSH Core (Pivotal Only)/toolsmiths-api-token" | head -n1 | cut -d'"' -f2)
      '';
    shepherd-tas-pools = ''
      shepherd list pool --namespace official --json | jq -r 'map(select(.template | contains("tas")) | .name).[]'
      echo -e "\nTo pick a pool: \nexport TAS_POOL=tas-5_0"
    '';
    shepherd-tas-claim = ''
      export ENVIRONMENT_LOCK_METADATA=$(mktemp --suffix=-tas-sheperd.json)
      export SHEPHERD_LEASE_ID=$(shepherd create lease \
        --namespace official --pool ''${TAS_POOL:=tas-5_0} --duration 8h --json | jq -r '.id')
      shepherd get lease --namespace official ''${SHEPHERD_LEASE_ID} --interactive
      shepherd get lease --namespace official ''${SHEPHERD_LEASE_ID} --json | jq '.output' > ''${ENVIRONMENT_LOCK_METADATA}
      eval "$(smith bosh)"
    '';
    shepherd-tas-last-lease = ''
      export ENVIRONMENT_LOCK_METADATA=$(mktemp --suffix=-tas-sheperd.json)
      export SHEPHERD_LEASE_ID=$(shepherd get lease --namespace official --last-lease --json | jq -r '.id')
      shepherd get lease --namespace official ''${SHEPHERD_LEASE_ID} --json | jq '.output' > ''${ENVIRONMENT_LOCK_METADATA}
      eval "$(smith bosh)"
    '';
    shepherd-delete-my-leases = ''
      shepherd list lease --namespace official --json \
        | jq -r --arg user $(whoami) 'map(select(.user | contains($user)))[0].identifier' \
        | xargs -L1 shepherd delete lease --namespace official
    '';
    nix-update =''
      darwin-rebuild switch --flake ~/.config/nixpkgs/
      source ~/.zshrc;
      tmux source-file ~/.config/tmux/tmux.conf;
      '';
  };
}
