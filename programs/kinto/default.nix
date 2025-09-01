# Kinto - Mac-style keyboard shortcuts for Linux
{ config, pkgs, homeDir, ... }:

{
  # Disable GNOME Super key overlay (Activities Overview)
  dconf.settings = {
    "org/gnome/mutter" = {
      overlay-key = "";  # Disable Super key overlay
    };
    "org/gnome/shell/keybindings" = {
      toggle-overview = [];  # Disable Super key for overview
    };
  };

  # Kinto configuration for Mac-style keybindings  
  home.file.".config/kinto/kinto.py".text = ''
    # -*- coding: utf-8 -*-
    import re
    from xkeysnail.transform import *

    # Define timeout for multipurpose modmap
    define_timeout(1)

    # [Global modemap] Basic modifier setup
    define_modmap({
        Key.CAPSLOCK: Key.LEFT_CTRL,
    })

    # Global Mac-style shortcuts for all applications except terminals
    define_keymap(lambda wm_class: wm_class not in ("Gnome-terminal", "konsole", "URxvt", "XTerm", "kitty", "Alacritty", "Terminator", "x-terminal-emulator"), {
        # Copy, Cut, Paste, Undo, Redo
        K("Super-c"): K("C-c"),         # Cmd+C -> Ctrl+C  
        K("Super-x"): K("C-x"),         # Cmd+X -> Ctrl+X
        K("Super-v"): K("C-v"),         # Cmd+V -> Ctrl+V
        K("Super-z"): K("C-z"),         # Cmd+Z -> Ctrl+Z
        K("Super-Shift-z"): K("C-y"),   # Cmd+Shift+Z -> Ctrl+Y (redo)
        
        # Select All, Save, Open, New
        K("Super-a"): K("C-a"),         # Cmd+A -> Ctrl+A
        K("Super-s"): K("C-s"),         # Cmd+S -> Ctrl+S
        K("Super-o"): K("C-o"),         # Cmd+O -> Ctrl+O
        K("Super-n"): K("C-n"),         # Cmd+N -> Ctrl+N
        
        # Find, Replace
        K("Super-f"): K("C-f"),         # Cmd+F -> Ctrl+F
        K("Super-r"): K("C-r"),         # Cmd+R -> Ctrl+R (refresh)
        K("Super-h"): K("C-h"),         # Cmd+H -> Ctrl+H (replace)
        
        # Tab management
        K("Super-t"): K("C-t"),         # Cmd+T -> Ctrl+T (new tab)
        K("Super-w"): K("C-w"),         # Cmd+W -> Ctrl+W (close tab)
        K("Super-Shift-t"): K("C-Shift-t"), # Cmd+Shift+T -> Ctrl+Shift+T (reopen tab)
        
        # Window management
        K("Super-q"): K("M-F4"),        # Cmd+Q -> Alt+F4 (quit application)
        K("Super-m"): K("Super-down"),  # Cmd+M -> minimize window
        
        # Browser/Application shortcuts
        K("Super-l"): K("C-l"),         # Cmd+L -> Ctrl+L (location bar)
        K("Super-d"): K("C-d"),         # Cmd+D -> Ctrl+D (bookmark)
        
        # Text editing navigation
        K("Super-left"): K("home"),     # Cmd+Left -> Home
        K("Super-right"): K("end"),     # Cmd+Right -> End
        K("Super-up"): K("C-home"),     # Cmd+Up -> Ctrl+Home
        K("Super-down"): K("C-end"),    # Cmd+Down -> Ctrl+End
        K("Super-backspace"): K("C-backspace"), # Cmd+Backspace -> Ctrl+Backspace
        
        # Word navigation
        K("M-left"): K("C-left"),       # Alt+Left -> Ctrl+Left (word left)
        K("M-right"): K("C-right"),     # Alt+Right -> Ctrl+Right (word right)
        K("M-backspace"): K("C-backspace"), # Alt+Backspace -> Ctrl+Backspace
        K("M-delete"): K("C-delete"),   # Alt+Delete -> Ctrl+Delete
        
        # Tab navigation shortcuts
        K("Super-Shift-left_brace"): K("C-Shift-Tab"),   # Cmd+Shift+[ -> Ctrl+Shift+Tab (previous tab)
        K("Super-Shift-right_brace"): K("C-Tab"),        # Cmd+Shift+] -> Ctrl+Tab (next tab)
    }, "Mac-style Global Shortcuts")

    # Terminal applications - special handling for copy/paste
    define_keymap(re.compile("Gnome-terminal|konsole|URxvt|XTerm|kitty|Alacritty|Terminator|x-terminal-emulator", re.IGNORECASE), {
        # In terminals, use terminal-specific shortcuts
        K("Super-c"): K("C-Shift-c"),   # Terminal copy
        K("Super-v"): K("C-Shift-v"),   # Terminal paste
        
        # Tab management in terminal
        K("Super-t"): K("C-Shift-t"),   # New tab
        K("Super-w"): K("C-Shift-w"),   # Close tab
        K("Super-Shift-left_brace"): K("C-Page_Up"),     # Previous tab
        K("Super-Shift-right_brace"): K("C-Page_Down"),  # Next tab
    }, "Terminal Applications")
  '';

  # Enable xhost for root to allow kinto to run
  home.file.".xprofile".text = ''
    xhost +SI:localuser:root
  '';

  # Kinto systemd service  
  systemd.user.services.kinto = {
    Unit = {
      Description = "Kinto - Mac-style shortcuts for Linux";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
    Service = {
      Environment = [
        "DISPLAY=:0"
        "XAUTHORITY=${homeDir}/.Xauthority"
        "XDG_RUNTIME_DIR=/run/user/1000"
      ];
      ExecStart = "sudo ${pkgs.kinto}/bin/kinto-xkeysnail ${homeDir}/.config/kinto/kinto.py";
      Restart = "on-failure";
      RestartSec = "3";
    };
  };

  # Create sudoers rule for kinto/xkeysnail
  home.file.".config/kinto/10-kinto-xkeysnail".text = ''
    # Allow user to run xkeysnail with sudo without password prompt
    # This file should be copied to /etc/sudoers.d/10-kinto-xkeysnail
    # Command: sudo cp ~/.config/kinto/10-kinto-xkeysnail /etc/sudoers.d/
    ruben ALL=(root) NOPASSWD: ${pkgs.kinto}/bin/kinto-xkeysnail
  '';

  # Installation script for the sudoers rule
  home.file.".config/kinto/install-sudoers.sh" = {
    text = ''
      #!/bin/bash
      set -e
      
      SUDOERS_FILE="$HOME/.config/kinto/10-kinto-xkeysnail"
      TARGET_DIR="/etc/sudoers.d"
      TARGET_FILE="$TARGET_DIR/10-kinto-xkeysnail"
      
      echo "Installing kinto sudoers rule..."
      
      # Check if the source file exists
      if [ ! -f "$SUDOERS_FILE" ]; then
        echo "Error: Source file $SUDOERS_FILE not found"
        exit 1
      fi
      
      # Copy the file to sudoers.d
      sudo cp "$SUDOERS_FILE" "$TARGET_FILE"
      
      # Set proper permissions
      sudo chmod 440 "$TARGET_FILE"
      sudo chown root:root "$TARGET_FILE"
      
      # Validate the sudoers file
      if sudo visudo -c; then
        echo "Sudoers rule installed successfully!"
        echo "You can now run: sudo ${pkgs.kinto}/bin/kinto-xkeysnail without a password"
      else
        echo "Error: Invalid sudoers configuration detected"
        sudo rm -f "$TARGET_FILE"
        exit 1
      fi
    '';
    executable = true;
  };
}