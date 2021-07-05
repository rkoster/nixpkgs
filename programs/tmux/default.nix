{ pkgs }:

{
  enable = true; 
  keyMode = "emacs";
  clock24 = true;
  historyLimit = 5000;
  terminal = "screen-256color";
  plugins = [ pkgs.tmuxPlugins.gruvbox ];
  extraConfig = ''
    set -g status-left "#[bg=colour241,fg=colour248] #S #[bg=colour237,fg=colour241,nobold,noitalics,nounderscore]"
    set -g status-right "#[bg=colour237,fg=colour239 nobold, nounderscore, noitalics]#[bg=colour239,fg=colour246] %Y-%m-%d #[bg=colour239,fg=colour248,nobold,noitalics,nounderscore]#[bg=colour248,fg=colour237] %H:%M "

    bind -N "bosh create and up2load release" -T root M-R send-keys "bosh -n create-release --force && bosh -n upload-release\n"
    bind -N "tail all bosh logs" -T root M-L send-keys "find /var/vcap/{sys/log,bosh/log,monit} -name *.log -or -name current | xargs tail -f"
  '';
}
