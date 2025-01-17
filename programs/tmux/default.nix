{ pkgs, ... }:

let
  gruvbox = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "gruvbox";
    rtpFilePath = "gruvbox-tpm.tmux";
    version = "unstable-2024-12-01";
    src = pkgs.fetchFromGitHub {
      owner = "egel";
      repo = "tmux-gruvbox";
      rev = "c7653229c7f7e5beb1f9f4ba298b3b1c39ffd8ce";
      sha256 = "sha256-ol8CKXzxpki8+AFgPZoAXIrShSCcM7T+YB33jJTMEig=";
    };
  };
in {
  enable = true;
  keyMode = "emacs";
  clock24 = true;
  historyLimit = 5000;
  terminal = "screen-256color";
  plugins = [ gruvbox ];
  newSession = true;
  shell = "${pkgs.zsh}/bin/zsh";
  extraConfig = ''
    set -g @tmux-gruvbox 'dark256'
    set -g @tmux-gruvbox-statusbar-alpha 'true'

    # source: https://github.com/egel/dotfiles/blob/main/configuration/.tmux.conf
    # set -g @tmux-gruvbox-statusbar-alpha 'true'
    # set -g @tmux-gruvbox-left-status-a '#S'
    # #set -g @tmux-gruvbox-right-status-x '#(TZ="Etc/UTC" date +%d.%m.%Y)'
    # set -g @tmux-gruvbox-right-status-x '#(date +%%d.%%m.%%Y)'
    # set -g @tmux-gruvbox-right-status-y '%H:%M'

    # set -g @tmux-gruvbox-right-status-z '#h #{tmux_mode_indicator}'

    set -g status-bg colour237

    set -g status-left "#[bg=colour241,fg=colour248] #S #[bg=colour237,fg=colour241,nobold,noitalics,nounderscore]"
    set -g status-right "#[bg=colour237,fg=colour239 nobold, nounderscore, noitalics]#[bg=colour239,fg=colour246] %Y-%m-%d #[bg=colour239,fg=colour248,nobold,noitalics,nounderscore]#[bg=colour248,fg=colour237] %H:%M "

    bind -N "bosh create and up2load release" -T root M-R send-keys "bosh -n create-release --force && bosh -n upload-release\n"
    bind -N "tail all bosh logs" -T root M-L send-keys "find /var/vcap/{sys/log,bosh/log,monit} -name *.log -or -name current | xargs tail -f\n"

    run '~/.tmux/plugins/tpm/tpm'
  '';
}
