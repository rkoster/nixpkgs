{ pkgs }:

{
  # 1Password packages
  home.packages = with pkgs; [
    _1password-cli
    _1password-gui
    polkit_gnome  # PolKit authentication agent for 1Password system authentication
  ];

  # PolKit authentication agent service for 1Password system authentication
  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    Unit = {
      Description = "polkit-gnome-authentication-agent-1";
      Wants = [ "graphical-session.target" ];
      WantedBy = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # SSH configuration for 1Password integration
  programs.ssh = {
    enable = true;
    # Disable default SSH config to avoid system-wide GSSAPI issues
    enableDefaultConfig = false;
    matchBlocks."*" = {
      compression = true;
      forwardAgent = false;
      addKeysToAgent = "yes";
      identityAgent = "~/.1password/agent.sock";
      serverAliveInterval = 60;
      serverAliveCountMax = 3;
    };
  };

  # Keep SSH agent service for compatibility
  services.ssh-agent = {
    enable = true;
  };
}