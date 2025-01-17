{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "vulnsvc";
  version = "v1.0.0-alpha.8";

  src = builtins.fetchGit {
    url = "git@github.gwd.broadcom.net:TNZ/tvt-cli.git";
    ref = "main";
    rev = "459470ec747d85f2d70bdc23713c815d47716d4a"; # v1.0.0-alpha.8
  };

  vendorHash = lib.fakeHash;

  doCheck = false;

  preBuild = ''
    for dir in tvt-jira tvt-cli vulnsvc-cli; do
      pushd $dir
      sed 's/go 1.23.*/go 1.22.0/g' go.mod > go.mod.tmp && mv go.mod{.tmp,}
      popd
    done
  '';

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
