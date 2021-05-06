{ config, lib, pkgs, ... }:
{
  xdg.configFile."zsh/snippets".source = ./snippets;
}
