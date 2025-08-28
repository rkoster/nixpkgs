{ config, lib, pkgs, ... }:

{
  programs.opencode = {
    enable = true;
    settings = {
      theme = "gruvbox";
      model = "github-copilot/claude-sonnet-4";
      small_model = "github-copilot/o4-mini";
    };
  };
}
