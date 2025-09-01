# Kinto - Mac-style keyboard shortcuts for Linux
{ config, pkgs, homeDir, ... }:

let
  kintoConfig = pkgs.writeText "kinto.py" ''
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
    define_keymap(lambda wm_class: wm_class not in ("Gnome-terminal", "konsole", "URxvt", "XTerm", "kitty", "Alacritty", "Terminator", "x-terminal-emulator", "ghostty", "") and wm_class, {
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
        
        # Emacs-style text editing keybindings
        K("C-a"): K("home"),            # Ctrl+A -> Beginning of line
        K("C-e"): K("end"),             # Ctrl+E -> End of line
        K("C-f"): K("right"),           # Ctrl+F -> Forward char
        K("C-b"): K("left"),            # Ctrl+B -> Backward char
        K("C-n"): K("down"),            # Ctrl+N -> Next line
        K("C-p"): K("up"),              # Ctrl+P -> Previous line
        K("C-d"): K("delete"),          # Ctrl+D -> Delete char
        K("C-h"): K("backspace"),       # Ctrl+H -> Backspace
        K("C-k"): [K("Shift-end"), K("C-x")], # Ctrl+K -> Kill line (select to end, cut)
        K("C-y"): K("C-v"),             # Ctrl+Y -> Yank (paste)
        K("C-w"): K("C-x"),             # Ctrl+W -> Kill region (cut)
        K("M-w"): K("C-c"),             # Alt+W -> Copy region
        K("M-f"): K("C-right"),         # Alt+F -> Forward word
        K("M-b"): K("C-left"),          # Alt+B -> Backward word
        K("M-d"): K("C-delete"),        # Alt+D -> Delete word forward
        K("C-M-h"): K("C-backspace"),   # Ctrl+Alt+H -> Delete word backward
        K("C-t"): [K("right"), K("Shift-left"), K("C-x"), K("left"), K("C-v")], # Transpose chars
        K("C-space"): K("Shift-right"), # Ctrl+Space -> Set mark (start selection)
        K("C-g"): K("esc"),             # Ctrl+G -> Cancel/escape
        K("C-s"): K("C-f"),             # Ctrl+S -> Search (find)
        K("C-r"): [K("C-f"), K("C-h")], # Ctrl+R -> Reverse search
        K("M-backspace"): K("C-backspace"), # Alt+Backspace -> Delete word backward
        K("C-o"): [K("end"), K("enter"), K("up"), K("end")], # Ctrl+O -> Open line
        K("C-j"): K("enter"),           # Ctrl+J -> New line
        K("C-m"): K("enter"),           # Ctrl+M -> Return (same as Enter)
        K("C-l"): K("C-f3"),            # Ctrl+L -> Recenter (F3 as placeholder)
        K("M-q"): K("C-j"),             # Alt+Q -> Fill paragraph (Ctrl+J as placeholder)
    }, "Mac-style Global Shortcuts with Emacs Keybindings")

    # Terminal applications - special handling for copy/paste
    define_keymap(re.compile("Gnome-terminal|konsole|URxvt|XTerm|kitty|Alacritty|Terminator|x-terminal-emulator|ghostty", re.IGNORECASE), {
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

in
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

  # Systemd service for Kinto
  systemd.user.services.kinto = {
    Unit = {
      Description = "Kinto - Mac-style shortcuts and Emacs keybindings for Linux";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
      Wants = [ "graphical-session.target" ];
    };

    Service = {
      Type = "exec";
      ExecStart = "${pkgs.kinto}/bin/kinto-xkeysnail ${kintoConfig}";
      Restart = "on-failure";
      RestartSec = "5";
      Environment = [
        "DISPLAY=:0"
      ];
      PrivateTmp = true;
      NoNewPrivileges = true;
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # Add kinto package to environment
  home.packages = with pkgs; [
    kinto
  ];

  # Unified Kinto post-installation script
  home.file.".local/bin/post-install-kinto" = {
    text = ''
      #!/bin/bash
      set -e
      
      echo "🚀 Kinto Post-Installation Setup"
      echo "================================="
      echo
      
      # Check if user is already in input group
      echo "📋 Step 1: Checking input group membership..."
      if groups | grep -q '\binput\b'; then
        echo "✅ User is already in the input group"
      else
        echo "➕ Adding user to input group..."
        usermod -a -G input $(whoami)
        echo "✅ User added to input group"
        NEED_LOGOUT=true
      fi
      echo
      
      # Setup udev rule for uinput access
      echo "🔧 Step 2: Setting up uinput permissions..."
      UDEV_RULE="/etc/udev/rules.d/99-uinput.rules"
      RULE_CONTENT='KERNEL=="uinput", GROUP="input", MODE="0660"'
      
      if [ -f "$UDEV_RULE" ] && grep -q "$RULE_CONTENT" "$UDEV_RULE"; then
        echo "✅ udev rule already exists and is correct"
      else
        echo "➕ Creating udev rule for uinput access..."
        echo "$RULE_CONTENT" | tee "$UDEV_RULE" > /dev/null
        echo "🔄 Reloading udev rules..."
        udevadm control --reload-rules
        udevadm trigger
        echo "✅ udev rule created and applied"
        NEED_REBOOT=true
      fi
      echo
      
      # Check current uinput permissions
      echo "🔍 Step 3: Verifying uinput device permissions..."
      if ls -la /dev/uinput | grep -q "input"; then
        echo "✅ /dev/uinput has correct group (input)"
      else
        echo "⚠️  /dev/uinput permissions may need to be updated"
        echo "   Current permissions:"
        ls -la /dev/uinput
        NEED_REBOOT=true
      fi
      echo
      
      # Check Kinto service status
      echo "🔍 Step 4: Checking Kinto service status..."
      if systemctl --user is-enabled kinto >/dev/null 2>&1; then
        if systemctl --user is-active kinto >/dev/null 2>&1; then
          echo "✅ Kinto service is enabled and running"
        else
          echo "🔄 Kinto service is enabled but not running. Starting..."
          systemctl --user start kinto
          if systemctl --user is-active kinto >/dev/null 2>&1; then
            echo "✅ Kinto service started successfully"
          else
            echo "❌ Failed to start Kinto service. Check logs with:"
            echo "   journalctl --user -u kinto -f"
          fi
        fi
      else
        echo "❌ Kinto service is not enabled. Run this after home-manager switch:"
        echo "   systemctl --user enable --now kinto"
      fi
      echo
      
      # Final summary
      echo "📋 Setup Summary"
      echo "================"
      
      if [ "$NEED_LOGOUT" = true ]; then
        echo "🔄 ACTION REQUIRED: Log out and log back in for group changes to take effect"
      fi
      
      if [ "$NEED_REBOOT" = true ]; then
        echo "🔄 RECOMMENDED: Reboot for udev changes to take full effect"
      fi
      
      echo
      echo "✅ Verification commands:"
      echo "   groups | grep input          # Should show 'input' in your groups"
      echo "   ls -la /dev/uinput          # Should show group 'input' with rw- permissions"
      echo "   systemctl --user status kinto  # Should show 'active (running)'"
      echo
      echo "🎹 Once setup is complete, you'll have:"
      echo "   • Mac-style shortcuts (Cmd+C/V → Ctrl+C/V) in non-terminal apps"
      echo "   • Emacs keybindings for text editing"
      echo "   • Terminal apps (including Ghostty) excluded from global bindings"
      echo
      
      if [ "$NEED_LOGOUT" = true ] || [ "$NEED_REBOOT" = true ]; then
        echo "⚠️  Setup requires logout/reboot to complete!"
        exit 1
      else
        echo "🎉 Kinto setup is complete!"
        exit 0
      fi
    '';
    executable = true;
  };
}