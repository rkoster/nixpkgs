{ pkgs }:

# apply: https://github.com/NixOS/nixpkgs/pull/352795
let
     unstablePkgs = import (builtins.fetchGit {
         # Descriptive name to make the store path easier to identify
         name = "my-old-revision";
         url = "https://github.com/NixOS/nixpkgs/";
         ref = "refs/heads/nixpkgs-unstable";
         rev = "62cfb3e8d8b15ed71217b68c526ea3ecefd6acc2";
     }) {};
in {
  enable = true;
  package = unstablePkgs.kitty;
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
  theme = "Gruvbox Material Dark Hard";
}
