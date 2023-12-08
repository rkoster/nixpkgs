{ buildGoModule, fetchFromGitHub, stdenv, lib, writeText }:

buildGoModule rec {
  pname = "smith";
  version = "2.6.0";

  # use fetchGit since it supports using ssh private keys for auth
  src = builtins.fetchGit {
    url = "git@github.com:pivotal/smith.git";
    ref = "master";
    rev = "0c178e7c3a998b774814621e97deb257674e356f"; # v2.6.0
  };

  vendorHash = null;

  doCheck = false;

  preBuild = ''
    sed 's/development build/'"${version}-nix"'/' main.go > main.tmp && mv main{.tmp,.go}
  '';

  subPackages = [ "main.go" ];

  postBuild = ''
     cd "$GOPATH/bin"
     mv main smith
  ''; 

  meta = with lib; {
    description = "The community CLI for Toolsmiths";
    homepage = "https://environments.toolsmiths.cf-app.com";
    maintainers = with maintainers; [ rkoster ];
  };
}
