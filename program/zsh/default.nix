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
    prompt.theme = "powerlevel10k";
  };
  initExtra =
    ''
    export XDG_CONFIG_HOME=${config.xdg.configHome}

    if [ -e "$HOME/.nix-defexpr/channels" ]; then
      export NIX_PATH="$HOME/.nix-defexpr/channels''${NIX_PATH:+:$NIX_PATH}"
    fi

    if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
      source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
    fi

    source ''${XDG_CONFIG_HOME}/zsh/p10k.zsh
    '';
}
