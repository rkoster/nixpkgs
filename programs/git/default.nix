{ pkgs, homeDir }:

{
  # Git SSH known hosts file with public keys for major Git hosts
  home.file.".ssh/git_known_hosts" = {
    text = ''
      # GitHub
      github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
      github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
      github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=

      # GitLab
      gitlab.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAfuCHKVTjquxvt6CM6tdG4SLp1Btn/nOeHHE5UOzRdf
      gitlab.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFSMqzJeV9rUzU4kWitGjeR4PWSa29SPqJ1fVkhtj3Hw9xjLVXVYrU9QlYWrOLXBpQ6KWjbjTDTdDkoohFzgbEY=
      gitlab.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsj2bNKTBSpIYDEGk9KxsGh3mySTRgMtXL583qmBpzeQ+jqCMRgBqB98u3z++J1sKlXHWfM9dyhSevkMwSbhoR8XIq/U0tCNyokEi/ueaBMCvbcTHhO7FcwzY92WK4Yt0aGROY5qX2UKSeOvuP4D6TPqKF1onrSzH9bx9XUf2lEdWT/ia1NEKjunUqu1xOB/StKDHMoX4/OKyIzuS0q/T1zOATthvasJFoPrAjkohTyaDUz2LN5JoH839hViyEG82yB+MjcFV5MU3N1l1QL3cVUCh93xSaua1N85qivl+siMkPGbO5xR/En4iEY6K2XPASUEMaieWVNTRCtJ4S8H+9
      
      # Bitbucket
      bitbucket.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIazEu89wgQZ4bqs3d63QSMzYVa0MuJ2e2gKTKqu+UUO
      bitbucket.org ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPIQmuzMBuKdWeF4+a2sjSSpBK0iqitSQ+5BM9KhpexuGt20JpTVM7u5BDZngncgrqDMbWdxMWWOGtZ9Diabetes=
      bitbucket.org ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDQeJzhupRu0u0cdegZIa8e86EG2qOCsIsD1Xw0xSeiPDlCr7kq97NLmMbpKTX6Esc30NuoqEEHQw4O2MultT4lxrC7m+YBYrQKt8JWVl1PrV8nnYS5VbQXP6uIMn2+Hv6Nqw7zVFGVuAKZs2vJ3vI9kGqP6/GBeBPvl4O+MtOKQn5HHiKI7k2LrT+m6q+4XqD8mHvC5J+7RiDrL8D6QKw9PpGVQ0J6v8q4o4+E3V/e4uEqy7z3K4VH3lGLGvF8a2ZKD9fK+oYNRVi8Q5FJvk1H7Z7C/R7fP3I2FYE/Q/e7Xg==
    '';
  };

  # Git SSH wrapper script to bypass system SSH config issues
  home.file.".local/bin/git-ssh-wrapper" = {
    text = ''
      #!/bin/bash
      exec env SSH_AUTH_SOCK=${homeDir}/.1password/agent.sock ssh \
        -o UserKnownHostsFile=${homeDir}/.ssh/git_known_hosts \
        -o StrictHostKeyChecking=yes \
        -o GlobalKnownHostsFile=/dev/null \
        -F /dev/null \
        "$@"
    '';
    executable = true;
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "rkoster";
        email = "hi@rkoster.dev";
        signingkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFq2Q5tJbPHP1ignMYswvcqt16RVTiznVB6JFaz87fhc";
      };
      pull = { rebase = true; };
      init = { defaultBranch = "main"; };
      push = { autoSetupRemote = true; };
      gpg = { format = "ssh"; };
      "gpg \"ssh\"" = {
        program = "${pkgs.lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
      };
      commit = { gpgsign = true; };
      tag = { gpgsign = true; };
      safe = { directory = "*"; };
      credential = {
        helper = "store";
      };
      # Rewrite HTTPS remotes to use SSH
      "url \"ssh://git@github.com/\"" = {
        pushInsteadOf = "https://github.com/";
      };
      "url \"ssh://git@gitlab.com/\"" = {
        pushInsteadOf = "https://gitlab.com/";
      };
      "url \"ssh://git@bitbucket.org/\"" = {
        pushInsteadOf = "https://bitbucket.org/";
      };
      # Use custom SSH wrapper to bypass system config issues
      core = {
        sshCommand = "${homeDir}/.local/bin/git-ssh-wrapper";
      };
    };
    ignores = [
      "*~"
      ".aider*"
    ];
    lfs.enable = true;
  };
}