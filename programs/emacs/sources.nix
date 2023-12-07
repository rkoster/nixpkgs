{ config, lib, pkgs, ... }:
{
  xdg.configFile."emacs/init.el".source = ./emacs.el;
}
