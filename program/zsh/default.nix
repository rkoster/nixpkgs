{ config }:

{
  enable = true;
  prezto = {
    enable = true;
    pmodules = [
      "prompt"
    ];
    prompt.theme = "powerlevel10k";
  };
  initExtra =
    ''
    if [ -e "$HOME/.nix-defexpr/channels" ]; then
      export NIX_PATH="$HOME/.nix-defexpr/channels''${NIX_PATH:+:$NIX_PATH}"
    fi

    # Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
    # Initialization code that may require console input (password prompts, [y/n]
    # confirmations, etc.) must go above this block; everything else may go below.
    if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
      source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
    fi

    # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
    source ${config.xdg.configHome}/zsh/p10k.zsh
    '';
}
