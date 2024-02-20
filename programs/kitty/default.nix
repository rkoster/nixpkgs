{ pkgs }:

{
  enable = true;
  environment = {
    "TERM" = "xterm-256color";
  };
  darwinLaunchOptions = [
    "--single-instance"
    "--directory=~/workspace"
    "--listen-on=unix:/var/run/kitty-socket"
  ];
  font = {
    name = "Hack";
    package = pkgs.hack-font;
    size = 13;
  };
  settings = {
    macos_option_as_alt = "yes";
    enable_audio_bell = "no";
  };
  shellIntegration.enableZshIntegration = true;
  theme = "Gruvbox Material Dark Soft";
}
