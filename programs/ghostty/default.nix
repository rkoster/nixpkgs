{ homeDir, pkgs }:

{
  enable = true;
  # ghostty nix package does not yet work on macos
  # https://github.com/ghostty-org/ghostty/blob/main/nix/package.nix#L207-L210
  package = pkgs.zsh;
  enableZshIntegration = true;
  clearDefaultKeybinds = true;
  settings = {
    font-family = "Hack";
    font-size = 13;
    theme = "gruvbox";
    working-directory = "${homeDir}/workspace";
    command = "${pkgs.tmux}/bin/tmux attach";
    macos-option-as-alt = "left";
    copy-on-select = "clipboard";
    confirm-close-surface = false;
    fullscreen = true;
    window-decoration = true; # Required for fullscreen
    app-notifications = "no-clipboard-copy";
    
    # Linux-style copy/paste keybindings
    keybind = [
      "ctrl+c=copy_to_clipboard"
      "ctrl+v=paste_from_clipboard"
      "super+c=copy_to_clipboard"
      "super+v=paste_from_clipboard"
      "cmd+c=copy_to_clipboard"
      "cmd+v=paste_from_clipboard"
      "super+q=quit"
      "cmd+q=quit"
    ];
  };
  themes = {
    # based on: https://github.com/wdomitrz/kitty_gruvbox_theme/blob/master/gruvbox_dark_hard.conf
    gruvbox = {
      background = "1d2021";
      cursor-color = "928374";
      foreground = "ebdbb2";
      palette = [
        "0=#282828"
        "1=#cc241d"
        "2=#98971a"
        "3=#d79921"
        "4=#458588"
        "5=#b16286"
        "6=#689d6a"
        "7=#a89984"
        "8=#928374"
        "9=#fb4934"
        "10=#b8bb26"
        "11=#fabd2f"
        "12=#83a598"
        "13=#d3869b"
        "14=#8ec07c"
        "15=#ebdbb2"
      ];
      selection-background = "ebdbb2";
      selection-foreground = "928374";
    };
  };
}
