{ config, pkgs, ... }:

{
  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "rubenkoster";
  home.homeDirectory = "/Users/rubenkoster";

  home.packages = with pkgs; [
  ];

  programs.git = {
    enable = true;
    userName  = "rkoster";
    userEmail = "rkoster@starkandwayne.com";
  };

  programs.emacs = {
    enable = true;
    package = pkgs.emacs26-nox;
  };

  programs.tmux = {
    enable = true; 
    keyMode = "emacs";
    clock24 = true;
    historyLimit = 5000;
    terminal = "screen-256color";
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "20.09";
}
