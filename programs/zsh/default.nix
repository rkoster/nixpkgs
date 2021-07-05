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
  plugins = [
      # {
      #   name = "enhancd";
      #   file = "init.sh";
      #   src = pkgs.fetchFromGitHub {
      #     owner = "b4b4r07";
      #     repo = "enhancd";
      #     rev = "v2.2.1";
      #     sha256 = "0iqa9j09fwm6nj5rpip87x3hnvbbz9w9ajgm6wkrd5fls8fn8i5g";
      #   };
      # }
  ];
  # prezto = {
  #   enable = true;
  #   pmodules = [
  #     "syntax-highlighting"      
  #     "prompt"
  #     "environment"
  #     "autosuggestions"
  #     "completion"
  #     "history"
  #   ];
  #   prompt.theme = null;
  # };
  initExtra =
    ''
    export XDG_CONFIG_HOME=${config.xdg.configHome}

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
    EMACS_SOCKET_NAME = "/private/tmp/emacs-$(tmux display-message -p '#S')-server";
    LC_ALL = "en_US.UTF-8";
  };

  shellAliases = {
    emacs = "emacsclient -a '' -nw";
    es = "lsof -w $(ls /private/tmp/emacs-*)";
    ek = "lsof -w \$EMACS_SOCKET_NAME | tail -n1 | awk '{print $2}' | xargs kill -9";
    e = "emacsclient --no-wait \${@}";
    brw = "br ~/workspace";
    be = "bundle exec ";
    ber = "bundle exec rspec ";
    nix-update = "sudo -H nix-channel --update; source ~/.zshrc; nix-channel --update; darwin-rebuild switch; source ~/.zshrc";
  };
}
