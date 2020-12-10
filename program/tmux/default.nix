{ pkgs }:

{
  enable = true; 
  keyMode = "emacs";
  clock24 = true;
  historyLimit = 5000;
  terminal = "screen-256color";
  plugins = with pkgs; [
    tmuxPlugins.gruvbox
    tmuxPlugins.battery
    tmuxPlugins.net-speed
    tmuxPlugins.cpu
  ];
  extraConfig = ''
    # set -g status-right "#{cpu_bg_color} CPU: #{cpu_icon} #{cpu_percentage} | #(battery_percentage) | %a %h-%d %H:%M "
    set -g status-left "#[bg=colour241,fg=colour248] #S #[bg=colour237,fg=colour241,nobold,noitalics,nounderscore]"
    set -g status-right "#[bg=colour237,fg=colour239 nobold, nounderscore, noitalics]#[bg=colour239,fg=colour246] %Y-%m-%d  %H:%M #[bg=colour239,fg=colour248,nobold,noitalics,nounderscore]#[bg=colour248,fg=colour237]  #(ram_percentage) ﬙     "

    bind -N "bosh create and upload release" -T root M-R send-keys "bosh -n create-release --force && bosh -n upload-release\n"

#   set-hook -g session-created 'split -h ; split -v top'
  '';
}
