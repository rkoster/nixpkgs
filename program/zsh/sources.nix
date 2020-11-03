{ config, lib, pkgs, ... }:
{
  xdg.configFile."zsh/p10k.zsh".source = ./p10k.zsh;
}
