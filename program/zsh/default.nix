{ config }:

{
  enable = true;
  prezto = {
    enable = true;
    pmodules = [
      "syntax-highlighting"      
      "prompt"
      "fasd"      
      "autosuggestions"
      "completion"
      "history"
    ];
    prompt.theme = null;
  };
  initExtra =
    ''
    export XDG_CONFIG_HOME=${config.xdg.configHome}

    if [ -e "$HOME/.nix-defexpr/channels" ]; then
      export NIX_PATH="$HOME/.nix-defexpr/channels''${NIX_PATH:+:$NIX_PATH}"
    fi

    zstyle ':prezto:environment:language' all 'en_US.UTF-8'
    zstyle -s ':prezto: environment:language' all 'LC_ALL'
    '';
}
