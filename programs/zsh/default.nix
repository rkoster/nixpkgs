{ config, pkgs }:

{
  enable = true;
  enableAutosuggestions = true;
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
    export XDG_RUNTIME_DIR=${config.xdg.runtimeDir}
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
    colima-start = "colima start --cpu 8 --memory 16 --disk 200 --arch x86_64 --vm-type vz";
    smith-auth = ''
      export TOOLSMITHS_API_TOKEN=$(lpass show --notes "Shared-BOSH Core (Pivotal Only)/toolsmiths-api-token" | head -n1 | cut -d'"' -f2)
      '';
    nix-update =''
      sudo -H nix-channel --update;
      source ~/.zshrc;
      nix-channel --update;
      darwin-rebuild switch;
      source ~/.zshrc;
      tmux source-file ~/.config/tmux/tmux.conf;
      '';
  };
}
