{
  enable = true;
  enableZshIntegration = true;
  settings = {
    add_newline = true;
    scan_timeout = 10;
    format = "$directory$git_branch$line_break$character";
    character = {
      success_symbol = "[❯](bold #d33682)";
      error_symbol = "[❯](bold #d33682)";
    };
    directory.style	 = "bold #268bd2";
    git_branch = {
      format = "[$branch*]($style) ";
      style = "#839496";
    };
  };
}
