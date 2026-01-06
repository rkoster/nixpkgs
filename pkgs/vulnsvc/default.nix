{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText, pkgs }:

buildGoModule rec {
  pname = "vulnsvc";
  version = "v1.0.0-alpha.11";

  src = builtins.fetchGit {
    url = "git@github.gwd.broadcom.net:TNZ/tvt-cli.git";
    ref = "main";
    rev = "66f96f98bf409fda34c806d8da282013492bcc63"; # v1.0.0-alpha.11
  };

  vendorHash = lib.fakeHash;

  doCheck = false;

  preBuild = ''
    export HOME=$(mktemp -d)
    cat <<EOF > $HOME/.gitconfig
    [url "git@github.gwd.broadcom.net:"]
      insteadOf = "https://github.gwd.broadcom.net/"
    EOF
    export GOPRIVATE="github.gwd.broadcom.net"
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  '';

  impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
    "GIT_PROXY_COMMAND" "SOCKS_SERVER" "SSH_AUTH_SOCK"
  ];

  ldflags = [
    "-X github.gwd.broadcom.net/tnz/tvt-cli/tvt-cli/pkg/buildmeta.Version=${version}"
  ];

  subPackages = [ "cmd/tvt" ];
  modRoot = "tvt-cli";

  postBuild = ''
     cd "$GOPATH/bin"
     mv tvt vulnsvc
  '';

  meta = with lib; {
    description = "Tanzu Vuln Cli";
    homepage = "https://github.gwd.broadcom.net/TNZ/tvt-cli";
    maintainers = with maintainers; [ rkoster ];
  };
}
