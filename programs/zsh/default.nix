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
    '';

  sessionVariables = {
    LC_ALL = "en_US.UTF-8";
  };
}
